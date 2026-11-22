// Loja Shopify no servidor (tradução de ShopifyClient, ShopifyStoreDataSource,
// StoreCacheWriter e StoreProfitPoster do iPhone). Os segredos só existem aqui,
// nas variáveis de ambiente da Edge Function.
import type { SupabaseClient as Client } from "npm:@supabase/supabase-js@2.119.0";

// deno-lint-ignore no-explicit-any
type SupabaseClient = Client<any, any, any>;
import { addDays, dailyKey, localDayKey, localMidnight } from "./time.ts";

const API_VERSION = "2026-10";
const SYNC_WINDOW_DAYS = 60;
const RETENTION_DAYS = 120;

export class ShopifyError extends Error {}

interface Credentials {
  domain: string;
  clientID?: string;
  clientSecret?: string;
  token?: string;
}

export function credentials(): Credentials | null {
  const raw = Deno.env.get("SHOPIFY_SHOP_DOMAIN")?.trim() ?? "";
  const domain = raw.replace(/^https?:\/\//, "").replace(/\/.*$/, "");
  if (!domain) return null;
  const clientID = Deno.env.get("SHOPIFY_CLIENT_ID")?.trim();
  const clientSecret = Deno.env.get("SHOPIFY_CLIENT_SECRET")?.trim();
  const token = Deno.env.get("SHOPIFY_ADMIN_TOKEN")?.trim();
  if (!(clientID && clientSecret) && !token) return null;
  return { domain: domain.includes(".") ? domain : `${domain}.myshopify.com`, clientID, clientSecret, token };
}

let cachedToken: { value: string; expiresAt: number } | null = null;

async function accessToken(c: Credentials, refresh = false) {
  if (c.token && !(c.clientID && c.clientSecret)) return c.token;
  if (!refresh && cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;
  // Client credentials grant: token de 24 h do app do Dev Dashboard.
  const response = await fetch(`https://${c.domain}/admin/oauth/access_token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams({ grant_type: "client_credentials", client_id: c.clientID!, client_secret: c.clientSecret! }),
  });
  if (response.status === 404) throw new ShopifyError("Loja não encontrada: confirma o domínio .myshopify.com.");
  if (!response.ok) throw new ShopifyError("A Shopify recusou o Client ID ou o Client secret.");
  const json = await response.json();
  cachedToken = { value: json.access_token, expiresAt: Date.now() + (json.expires_in ?? 86_400) * 1000 };
  return cachedToken.value;
}

/** Query GraphQL com espera em THROTTLED / 429 (o "balde" de pontos da Shopify). */
async function query<T>(c: Credentials, document: string, variables: Record<string, unknown> = {}): Promise<T> {
  let refreshed = false;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const token = await accessToken(c);
    const response = await fetch(`https://${c.domain}/admin/api/${API_VERSION}/graphql.json`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Shopify-Access-Token": token },
      body: JSON.stringify({ query: document, variables }),
    });
    if (response.status === 401 && !refreshed && c.clientID) {
      refreshed = true;
      await accessToken(c, true);
      continue;
    }
    if (response.status === 401) throw new ShopifyError("Sem autorização: o token foi revogado ou expirou.");
    if (response.status === 402) throw new ShopifyError("A loja está suspensa ou sem plano ativo.");
    if (response.status === 403) throw new ShopifyError("Faltam permissões ao app (scopes de leitura).");
    if (response.status === 429 || response.status >= 500) {
      await new Promise((r) => setTimeout(r, (attempt + 1) * 2000));
      continue;
    }
    const json = await response.json();
    const errors: { message: string; extensions?: { code?: string } }[] = json.errors ?? [];
    if (errors.some((e) => e.extensions?.code === "THROTTLED")) {
      await new Promise((r) => setTimeout(r, (attempt + 1) * 2000));
      continue;
    }
    if (errors.some((e) => e.extensions?.code === "ACCESS_DENIED")) throw new ShopifyError("Faltam permissões ao app: " + errors[0].message);
    if (!json.data) throw new ShopifyError(errors.map((e) => e.message).join("; ") || "Resposta inválida da Shopify");
    // Espera se o balde de pontos está quase vazio.
    const status = json.extensions?.cost?.throttleStatus;
    if (status && status.currentlyAvailable < 200) {
      await new Promise((r) => setTimeout(r, Math.ceil((200 - status.currentlyAvailable) / status.restoreRate) * 1000));
    }
    return json.data as T;
  }
  throw new ShopifyError("A Shopify está a limitar os pedidos. Tenta daqui a um minuto.");
}

export async function shopInfo(c: Credentials) {
  const data = await query<{ shop: { name: string; myshopifyDomain: string; currencyCode: string } }>(c, "{ shop { name myshopifyDomain currencyCode } }");
  return data.shop;
}

const money = (set?: { shopMoney?: { amount?: string } } | null) => Number(set?.shopMoney?.amount ?? 0);

const PRODUCTS = `query Products($cursor: String) {
  products(first: 50, after: $cursor, sortKey: CREATED_AT) {
    pageInfo { hasNextPage endCursor }
    nodes { id title handle status createdAt totalInventory tracksInventory
      featuredMedia { preview { image { url } } }
      priceRangeV2 { minVariantPrice { amount } }
      variants(first: 1) { nodes { inventoryItem { unitCost { amount } } } } }
  }
}`;

const ORDERS = `query Orders($cursor: String, $search: String!) {
  orders(first: 15, after: $cursor, query: $search, sortKey: CREATED_AT, reverse: true) {
    pageInfo { hasNextPage endCursor }
    nodes { id name createdAt cancelledAt test currencyCode displayFinancialStatus displayFulfillmentStatus
      currentSubtotalPriceSet { shopMoney { amount } } currentShippingPriceSet { shopMoney { amount } }
      currentTotalTaxSet { shopMoney { amount } } currentTotalPriceSet { shopMoney { amount } }
      totalRefundedSet { shopMoney { amount } }
      lineItems(first: 10) { nodes { title quantity currentQuantity product { id } originalUnitPriceSet { shopMoney { amount } } } } }
  }
}`;

const CHECKOUTS = `query Checkouts($cursor: String, $search: String!) {
  abandonedCheckouts(first: 25, after: $cursor, query: $search, sortKey: CREATED_AT, reverse: true) {
    pageInfo { hasNextPage endCursor }
    nodes { id name createdAt abandonedCheckoutUrl totalPriceSet { shopMoney { amount } }
      lineItems(first: 10) { nodes { title quantity product { id } } } }
  }
}`;

const TRAFFIC = `query Traffic($shopifyql: String!) { shopifyqlQuery(query: $shopifyql) { parseErrors tableData { rows } } }`;

async function paginate<N>(c: Credentials, document: string, key: string, variables: Record<string, unknown>, maxPages: number) {
  const nodes: N[] = [];
  let cursor: string | null = null;
  for (let page = 0; page < maxPages; page += 1) {
    const data: Record<string, { pageInfo: { hasNextPage: boolean; endCursor: string }; nodes: N[] }> = await query(c, document, { ...variables, cursor });
    nodes.push(...data[key].nodes);
    if (!data[key].pageInfo.hasNextPage) break;
    cursor = data[key].pageInfo.endCursor;
  }
  return nodes;
}

export interface SyncResult {
  shopName: string;
  products: number;
  orders: number;
  newOrders: { name: string; total: number; items: string[] }[];
  trafficError?: string;
}

/** Lê a loja e escreve a cache nas tabelas do utilizador (as mesmas do iPhone). */
export async function syncStore(c: Credentials, db: SupabaseClient): Promise<SyncResult> {
  const now = new Date();
  const today = localDayKey(now);
  const sinceDay = addDays(today, -(SYNC_WINDOW_DAYS - 1));
  const since = localMidnight(sinceDay);
  const search = `created_at:>=${sinceDay}`;
  const stamp = now.toISOString();

  const shop = await shopInfo(c);
  // deno-lint-ignore no-explicit-any
  const products = await paginate<any>(c, PRODUCTS, "products", {}, 20);
  // deno-lint-ignore no-explicit-any
  const orders = (await paginate<any>(c, ORDERS, "orders", { search }, 40)).filter((o) => !o.test);
  // deno-lint-ignore no-explicit-any
  const checkouts = await paginate<any>(c, CHECKOUTS, "abandonedCheckouts", { search: `${search} recovery_state:not_recovered` }, 10);
  let traffic: { day: string; sessions: number; cart: number; checkout: number; completed: number }[] = [];
  let trafficError: string | undefined;
  try {
    const ql = `FROM sessions SHOW sessions, sessions_with_cart_additions, sessions_that_reached_checkout, sessions_that_completed_checkout TIMESERIES day SINCE -${SYNC_WINDOW_DAYS}d UNTIL today`;
    const data = await query<{ shopifyqlQuery: { parseErrors: string[]; tableData?: { rows: Record<string, unknown>[] } } }>(c, TRAFFIC, { shopifyql: ql });
    if (data.shopifyqlQuery.parseErrors?.length) throw new Error(data.shopifyqlQuery.parseErrors.join("; "));
    traffic = (data.shopifyqlQuery.tableData?.rows ?? []).map((r) => ({
      day: String(r.day).slice(0, 10),
      sessions: Number(r.sessions ?? 0),
      cart: Number(r.sessions_with_cart_additions ?? 0),
      checkout: Number(r.sessions_that_reached_checkout ?? 0),
      completed: Number(r.sessions_that_completed_checkout ?? 0),
    }));
  } catch (error) {
    trafficError = `Sem dados de tráfego (scope read_reports?): ${error instanceof Error ? error.message : error}`;
  }

  // Produtos: os campos manuais (custo manual, anúncios, decisão) ficam como estão.
  const { data: existingProducts } = await db.from("store_products").select("id, unit_cost_is_manual, deleted");
  const known = new Map((existingProducts ?? []).map((p) => [p.id, p]));
  for (const p of products) {
    const cost = p.variants?.nodes?.[0]?.inventoryItem?.unitCost?.amount;
    const row: Record<string, unknown> = {
      id: p.id, title: p.title, handle: p.handle, status: p.status,
      image_url: p.featuredMedia?.preview?.image?.url ?? "", price: Number(p.priceRangeV2?.minVariantPrice?.amount ?? 0),
      inventory: p.totalInventory ?? 0, tracks_inventory: p.tracksInventory ?? true, created_at: p.createdAt,
      synced_at: stamp, modified_at: stamp, deleted: false,
    };
    const current = known.get(p.id);
    if (cost != null && !current?.unit_cost_is_manual) row.unit_cost = Number(cost);
    if (current) await db.from("store_products").update(row).eq("id", p.id);
    else await db.from("store_products").insert(row);
  }
  const incomingProducts = new Set(products.map((p) => p.id));
  const goneProducts = [...known.keys()].filter((id) => !incomingProducts.has(id) && !known.get(id)!.deleted);
  if (goneProducts.length) await db.from("store_products").update({ deleted: true, modified_at: stamp }).in("id", goneProducts);

  // Pedidos: dentro da janela a Shopify manda; fora dela, só a retenção de 120 dias.
  const { data: existingOrders } = await db.from("store_orders").select("id, created_at, deleted");
  const knownOrders = new Map((existingOrders ?? []).map((o) => [o.id, o]));
  const firstSync = (existingOrders ?? []).filter((o) => !o.deleted).length === 0;
  const newOrders: SyncResult["newOrders"] = [];
  for (const o of orders) {
    const lines = o.lineItems.nodes.map((l: { title: string; quantity: number; currentQuantity: number; product?: { id: string }; originalUnitPriceSet: unknown }) => ({
      productID: l.product?.id ?? "", title: l.title, quantity: l.quantity, currentQuantity: l.currentQuantity,
      // deno-lint-ignore no-explicit-any
      unitPrice: money(l.originalUnitPriceSet as any),
    }));
    const row = {
      id: o.id, name: o.name, created_at: o.createdAt, cancelled_at: o.cancelledAt,
      subtotal: money(o.currentSubtotalPriceSet), shipping: money(o.currentShippingPriceSet), tax: money(o.currentTotalTaxSet),
      total: money(o.currentTotalPriceSet), refunded: money(o.totalRefundedSet), currency_code: o.currencyCode,
      financial_status: o.displayFinancialStatus ?? "", fulfillment_status: o.displayFulfillmentStatus ?? "", lines,
      synced_at: stamp, modified_at: stamp, deleted: false,
    };
    const current = knownOrders.get(o.id);
    if (current) await db.from("store_orders").update(row).eq("id", o.id);
    else {
      await db.from("store_orders").insert(row);
      if (!firstSync && !o.cancelledAt) newOrders.push({ name: o.name, total: row.total, items: lines.map((l: { title: string }) => l.title) });
    }
  }
  const incomingOrders = new Set(orders.map((o) => o.id));
  const cutoff = localMidnight(addDays(today, -RETENTION_DAYS));
  const goneOrders = [...knownOrders.values()]
    .filter((o) => !o.deleted && !incomingOrders.has(o.id) && (new Date(o.created_at) >= since || new Date(o.created_at) < cutoff))
    .map((o) => o.id);
  if (goneOrders.length) await db.from("store_orders").update({ deleted: true, modified_at: stamp }).in("id", goneOrders);

  // Checkouts abandonados: a lista da Shopify substitui a cache.
  const { data: existingCheckouts } = await db.from("store_checkouts").select("id, deleted");
  const knownCheckouts = new Set((existingCheckouts ?? []).map((x) => x.id));
  for (const x of checkouts) {
    const row = {
      id: x.id, name: x.name, created_at: x.createdAt, total: money(x.totalPriceSet), recovery_url: x.abandonedCheckoutUrl ?? "",
      lines: x.lineItems.nodes.map((l: { title: string; quantity: number; product?: { id: string } }) => ({ productID: l.product?.id ?? "", title: l.title, quantity: l.quantity })),
      synced_at: stamp, modified_at: stamp, deleted: false,
    };
    if (knownCheckouts.has(x.id)) await db.from("store_checkouts").update(row).eq("id", x.id);
    else await db.from("store_checkouts").insert(row);
  }
  const incomingCheckouts = new Set(checkouts.map((x) => x.id));
  const goneCheckouts = (existingCheckouts ?? []).filter((x) => !x.deleted && !incomingCheckouts.has(x.id)).map((x) => x.id);
  if (goneCheckouts.length) await db.from("store_checkouts").update({ deleted: true, modified_at: stamp }).in("id", goneCheckouts);

  // Estatísticas diárias da janela (chave igual à do iPhone).
  const days = new Map<string, Record<string, number | boolean>>();
  for (let d = sinceDay; d <= today; d = addDays(d, 1)) {
    days.set(d, { sales: 0, net_revenue: 0, orders: 0, units: 0, refunds: 0, sessions: 0, cart_sessions: 0, checkout_sessions: 0, completed_sessions: 0, has_traffic: false });
  }
  for (const o of orders) {
    if (o.cancelledAt) continue;
    const s = days.get(localDayKey(new Date(o.createdAt)));
    if (!s) continue;
    const total = money(o.currentTotalPriceSet);
    s.sales = (s.sales as number) + total;
    s.net_revenue = (s.net_revenue as number) + total - money(o.currentTotalTaxSet);
    s.orders = (s.orders as number) + 1;
    s.units = (s.units as number) + o.lineItems.nodes.reduce((n: number, l: { currentQuantity: number }) => n + l.currentQuantity, 0);
    s.refunds = (s.refunds as number) + money(o.totalRefundedSet);
  }
  for (const t of traffic) {
    const s = days.get(t.day);
    if (!s) continue;
    Object.assign(s, { sessions: t.sessions, cart_sessions: t.cart, checkout_sessions: t.checkout, completed_sessions: t.completed, has_traffic: true });
  }
  const statRows = [...days.entries()].map(([day, values]) => ({
    id: dailyKey(day), date: localMidnight(day).toISOString(), ...values, modified_at: stamp, deleted: false,
  }));
  await db.from("daily_stats").upsert(statRows, { onConflict: "user_id,id" });

  await postProfit(db, since, now);
  return { shopName: shop.name, products: products.length, orders: orders.length, newOrders, trafficError };
}

/** Lucro de cada mês nas Finanças (um movimento por mês, externalID store-profit-AAAA-MM). */
async function postProfit(db: SupabaseClient, since: Date, now: Date) {
  const { data: setting } = await db.from("user_settings").select("value").eq("id", "storeProfitToFinance").eq("deleted", false).maybeSingle();
  if (setting?.value === false) return;
  const todayKey = localDayKey(now);
  const currentMonth = `${todayKey.slice(0, 7)}-01`;
  const [cy, cm] = currentMonth.split("-").map(Number);
  const previousMonth = new Date(Date.UTC(cy, cm - 2, 1)).toISOString().slice(0, 10);
  const { data: category } = await db.from("categories").select("id").eq("name", "Loja").eq("kind", "income").eq("deleted", false).limit(1).maybeSingle();
  const { data: account } = await db.from("accounts").select("id").eq("deleted", false).order("created_at").limit(1).maybeSingle();
  for (const month of [previousMonth, currentMonth]) {
    const start = localMidnight(month);
    if (start < localMidnight(localDayKey(since))) continue; // mês incompleto na cache
    const [y, m] = month.split("-").map(Number);
    const nextMonth = new Date(Date.UTC(y, m, 1)).toISOString().slice(0, 10);
    const end = new Date(Math.min(localMidnight(nextMonth).getTime(), localMidnight(addDays(todayKey, 1)).getTime()));
    const days = Math.max(1, Math.round((end.getTime() - start.getTime()) / 86_400_000));
    const { data: rows } = await db.rpc("store_profit", { p_from: start.toISOString(), p_to: end.toISOString(), p_days: days });
    const b = rows?.[0];
    const externalID = `store-profit-${month.slice(0, 7)}`;
    const { data: existing } = await db.from("transactions").select("id").eq("external_id", externalID).eq("deleted", false).limit(1).maybeSingle();
    if (!existing && (!b || Number(b.orders) === 0)) continue;
    const profit = Math.round(Number(b?.profit ?? 0) * 100) / 100;
    const monthName = new Intl.DateTimeFormat("pt-PT", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(Date.UTC(y, m - 1, 1)));
    const row = {
      title: profit >= 0 ? `Lucro da loja · ${monthName}` : `Prejuízo da loja · ${monthName}`,
      amount: Math.abs(profit), kind: profit >= 0 ? "income" : "expense", currency_code: "EUR",
      date: new Date(Math.min(now.getTime(), localMidnight(nextMonth).getTime() - 1000)).toISOString(),
      category_id: profit >= 0 ? category?.id ?? null : null,
      notes: `Lançado automaticamente pela loja (atualiza a cada sincronização). Vendas ${Number(b?.gross_sales ?? 0).toFixed(2)} € · ${b?.orders ?? 0} pedidos.`,
      modified_at: new Date().toISOString(),
    };
    if (existing) await db.from("transactions").update(row).eq("id", existing.id);
    else await db.from("transactions").insert({ ...row, id: crypto.randomUUID().toUpperCase(), external_id: externalID, account_id: account?.id ?? null, created_at: now.toISOString() });
  }
}
