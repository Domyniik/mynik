// Paridade iPhone ↔ servidor: as funções SQL de cálculo, com os dados de
// MynikTests/Fixtures/parity-fixture.json, têm de dar os valores de
// parity-expected.json — o mesmo ficheiro que MynikTests/ParityTests.swift
// confere contra o código Swift.
//
// Atualizar os valores esperados (só depois de confirmar que o Swift concorda):
//   UPDATE_PARITY=1 npm test
import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { asUser, freshDatabase, USER_A } from "./helpers.mjs";

const fixtures = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "MynikTests", "Fixtures");
const fixture = JSON.parse(readFileSync(join(fixtures, "parity-fixture.json"), "utf8"));
const expectedPath = join(fixtures, "parity-expected.json");

/** Chave dos registos diários no iOS: segundos desde 1970 com ".0" (String(Double)). */
const dayKey = (iosSeconds) => {
  const unix = iosSeconds + 978307200;
  return Number.isInteger(unix) ? `${unix}.0` : String(unix);
};

async function load(tx) {
  const rows = [];
  const add = (entity, list, key) =>
    list.forEach((payload) => rows.push({ entity, key: key(payload), payload, deleted: false, modified_at: "2026-11-21T00:00:00Z" }));
  const a = fixture.archive;
  add("category", a.categories, (r) => r.uid);
  add("transaction", a.transactions, (r) => r.uid);
  add("storeProduct", a.storeProducts, (r) => r.shopifyID);
  add("storeOrder", a.storeOrders, (r) => r.shopifyID);
  add("storeCheckout", a.storeCheckouts, (r) => r.shopifyID);
  add("dailyStat", a.dailyStats, (r) => dayKey(r.date));
  for (const [key, value] of Object.entries(fixture.settings)) {
    rows.push({ entity: "setting", key, payload: { key, value }, deleted: false, modified_at: "2026-11-21T00:00:00Z" });
  }
  await tx.query("select public.sync_push($1::jsonb)", [JSON.stringify(rows)]);
}

const now = new Date((fixture.now + 978307200) * 1000).toISOString();
const tz = fixture.timeZone;
const d6 = (column) => `round((${column})::numeric, 6)::text`;
const f9 = (column) => `round((${column})::numeric, 9)::float8`;

async function compute(tx) {
  const products = (await tx.query(
    `select product_id, score, classification, action, age_days, units::int, ordered_units::int, refunded_units::int,
            ${d6("revenue")} as revenue, days_since_last_sale, days_of_stock, abandoned_units::int,
            ${f9("margin_rate")} as margin_rate, ${f9("refund_rate")} as refund_rate, ${f9("roas")} as roas,
            ${f9("checkout_conversion")} as checkout_conversion,
            (select jsonb_agg(jsonb_build_object('kind', f ->> 'kind', 'points', round((f ->> 'points')::numeric, 9), 'hasData', (f ->> 'hasData')::boolean))
               from jsonb_array_elements(factors) f) as factors
     from public.store_product_scores($1, $2)`,
    [now, tz],
  )).rows.map((r) => ({
    productID: r.product_id, score: r.score, classification: r.classification, action: r.action,
    ageDays: r.age_days, units: r.units, orderedUnits: r.ordered_units, refundedUnits: r.refunded_units,
    revenue: r.revenue, daysSinceLastSale: r.days_since_last_sale, daysOfStock: r.days_of_stock,
    abandonedUnits: r.abandoned_units, marginRate: r.margin_rate, refundRate: r.refund_rate,
    roas: r.roas, checkoutConversion: r.checkout_conversion,
    factors: r.factors.map((f) => ({ kind: f.kind, points: Number(f.points), hasData: f.hasData })),
  }));

  const kpis = {};
  for (const days of [1, 7, 30]) {
    const rows = (await tx.query(
      `select period, orders::int, units::int, ${d6("gross_sales")} gross_sales, ${d6("vat")} vat,
              ${d6("product_costs")} product_costs, ${d6("shipping_costs")} shipping_costs,
              ${d6("payment_fees")} payment_fees, ${d6("ad_spend")} ad_spend, ${d6("profit")} profit,
              ${f9("margin")} margin, ${d6("average_order_value")} average_order_value,
              sessions::int, completed_sessions::int, has_traffic, ${f9("conversion_rate")} conversion_rate
       from public.store_kpis($1, $2, $3)`,
      [days, now, tz],
    )).rows;
    kpis[days] = Object.fromEntries(rows.map((r) => [r.period, {
      orders: r.orders, units: r.units, grossSales: r.gross_sales, vat: r.vat,
      productCosts: r.product_costs, shippingCosts: r.shipping_costs, paymentFees: r.payment_fees,
      adSpend: r.ad_spend, profit: r.profit, margin: r.margin, averageOrderValue: r.average_order_value,
      sessions: r.sessions, completedSessions: r.completed_sessions, hasTraffic: r.has_traffic,
      conversionRate: r.conversion_rate,
    }]));
  }

  const budget = (await tx.query(
    `select category_id, ${d6("budget")} budget, ${d6("spent")} spent, ${d6("remaining")} remaining,
            over_budget, ${f9("progress")} progress
     from public.budget_overview('2026-11-01', $1)`,
    [tz],
  )).rows.map((r) => ({
    categoryID: r.category_id, budget: r.budget, spent: r.spent, remaining: r.remaining,
    overBudget: r.over_budget, progress: r.progress,
  }));

  const months = {};
  for (const month of ["2026-10-01", "2026-11-01"]) {
    const [r] = (await tx.query(
      `select ${d6("income")} income, ${d6("expenses")} expenses, ${d6("balance")} balance from public.month_summary($1, $2)`,
      [month, tz],
    )).rows;
    months[month.slice(0, 7)] = r;
  }
  return { products, kpis, budget, months };
}

test("funções SQL dão os mesmos números que o iPhone (parity-expected.json)", async () => {
  const db = await freshDatabase();
  const actual = await asUser(db, USER_A, async (tx) => {
    await load(tx);
    return compute(tx);
  });
  if (process.env.UPDATE_PARITY) {
    writeFileSync(expectedPath, JSON.stringify(actual, null, 2) + "\n");
    return;
  }
  const expected = JSON.parse(readFileSync(expectedPath, "utf8"));
  assert.deepEqual(actual, expected);
});

test("o ranking cobre todos os ramos da classificação", async () => {
  const expected = JSON.parse(readFileSync(expectedPath, "utf8"));
  const classes = new Set(expected.products.map((p) => p.classification));
  for (const c of ["winner", "promising", "testing", "loser"]) assert.ok(classes.has(c), `falta ${c}`);
  assert.ok(!expected.products.some((p) => p.productID.endsWith("/6")), "produto inativo não entra");
});
