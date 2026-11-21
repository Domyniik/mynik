#!/usr/bin/env node
// Gera os dados de teste partilhados pelo iPhone e pelo SQL:
//   MynikTests/Fixtures/parity-fixture.json
// É uma cópia de segurança do Mynik (formato do iOS, datas em segundos desde
// 1/1/2001) com uma loja inventada que exercita todos os ramos do ranking,
// do lucro real e do orçamento. Determinística: correr de novo dá o mesmo ficheiro.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const output = join(root, "MynikTests", "Fixtures", "parity-fixture.json");

const NOW = Date.parse("2026-11-21T17:00:00Z"); // 18:00 em Madrid
const DAY = 86_400_000;
const ios = (ms) => ms / 1000 - 978307200;
/** Meio-dia em Madrid (11:00 UTC no inverno) de há `daysAgo` dias, mais `minutes`. */
const at = (daysAgo, minutes = 0) => ios(Date.parse("2026-11-21T11:00:00Z") - daysAgo * DAY + minutes * 60_000);
const gid = (kind, n) => `gid://shopify/${kind}/${n}`;

const products = [
  { n: 1, title: "Anel dourado", price: 24.9, cost: 6.2, age: 120, inventory: 40, ads: 30 },
  { n: 2, title: "Brincos pérola", price: 19.9, cost: 9.5, age: 90, inventory: 25, ads: 0 },
  { n: 3, title: "Colar novo", price: 34.9, cost: 11, age: 6, inventory: 15, ads: 0 },
  { n: 4, title: "Pulseira prata", price: 29.9, cost: 0, age: 80, inventory: 30, ads: 40 },
  { n: 5, title: "Gargantilha", price: 15.9, cost: 4, age: 200, inventory: 12, ads: 0 },
  { n: 6, title: "Tiara", price: 39.9, cost: 12, age: 150, inventory: 5, ads: 0, status: "DRAFT" },
  { n: 7, title: "Pin esmaltado", price: 9.9, cost: 2.1, age: 60, inventory: 3, ads: 0, tracks: true },
  { n: 8, title: "Ear cuff", price: 12.5, cost: 3.75, age: 25, inventory: 0, ads: 0, tracks: false },
].map((p) => ({
  shopifyID: gid("Product", p.n),
  title: p.title,
  handle: p.title.toLowerCase().replaceAll(" ", "-"),
  statusRaw: p.status ?? "ACTIVE",
  imageURLString: "",
  price: p.price,
  unitCost: p.cost,
  unitCostIsManual: false,
  inventory: p.inventory,
  tracksInventory: p.tracks ?? true,
  createdAt: at(p.age),
  adSpend30d: p.ads,
  decisionRaw: "",
  decisionNote: "",
  syncedAt: ios(NOW),
}));
const price = Object.fromEntries(products.map((p) => [p.shopifyID, p.price]));

// [dias atrás, minutos, [[produto, quantidade, mantidas]], opções]
const schedule = [];
for (let d = 0; d < 55; d += 1) {
  if (d % 2 === 0) schedule.push([d, 0, [[1, 1, 1]]]);
  if (d % 5 === 1 && d < 40) schedule.push([d, 90, [[2, 1, d === 6 ? 0 : 1]]]);
}
schedule.push(
  [0, -680, [[1, 1, 1]]], // 23:40 UTC de ontem = 00:40 de hoje em Madrid
  [1, 700, [[2, 2, 1]]], // 22:40 UTC = 23:40 de ontem em Madrid (reembolso parcial)
  [2, 30, [[3, 1, 1]]],
  [4, 30, [[3, 1, 1], [1, 1, 1]]],
  [20, 45, [[4, 1, 1]]],
  [45, 10, [[5, 2, 2]]],
  [3, 15, [[6, 1, 1]]],
  [8, 20, [[7, 3, 3]]],
  [12, 20, [[7, 2, 2]]],
  [15, 0, [[8, 1, 1]]],
  [5, 50, [[1, 2, 2]], { cancelled: true }],
  [9, 70, [[2, 1, 1], [9, 1, 1]]], // produto que já não existe na loja
);

const orders = schedule.map(([daysAgo, minutes, lines, options = {}], i) => {
  const orderLines = lines.map(([n, quantity, current]) => ({
    productID: gid("Product", n),
    title: products.find((p) => p.shopifyID === gid("Product", n))?.title ?? "Produto antigo",
    quantity,
    currentQuantity: current,
    unitPrice: price[gid("Product", n)] ?? 10,
  }));
  const subtotal = Math.round(orderLines.reduce((s, l) => s + l.unitPrice * l.currentQuantity, 0) * 100) / 100;
  const shipping = subtotal >= 40 ? 0 : 3.9;
  const total = Math.round((subtotal + shipping) * 100) / 100;
  const tax = Math.round((total - total / 1.21) * 100) / 100;
  const refunded = Math.round(orderLines.reduce((s, l) => s + l.unitPrice * (l.quantity - l.currentQuantity), 0) * 100) / 100;
  const createdAt = at(daysAgo, minutes);
  return {
    shopifyID: gid("Order", 5000 + i),
    name: `#${1001 + i}`,
    createdAt,
    ...(options.cancelled ? { cancelledAt: createdAt + 3600 } : {}),
    subtotal, shipping, tax, total, refunded,
    currencyCode: "EUR",
    financialStatusRaw: refunded > 0 ? "PARTIALLY_REFUNDED" : "PAID",
    fulfillmentStatusRaw: daysAgo < 3 ? "UNFULFILLED" : "FULFILLED",
    lines: orderLines,
    syncedAt: ios(NOW),
  };
});

const checkouts = [
  [1, [[1, 1], [2, 2]]],
  [3, [[2, 1]]],
  [7, [[2, 3], [4, 2]]],
  [12, [[1, 2]]],
  [40, [[2, 5]]], // fora da janela de 30 dias
].map(([daysAgo, lines], i) => ({
  shopifyID: gid("AbandonedCheckout", 700 + i),
  name: `#C${700 + i}`,
  createdAt: at(daysAgo, 200),
  total: 30,
  recoveryURLString: "",
  lines: lines.map(([n, quantity]) => ({ productID: gid("Product", n), title: "", quantity })),
  syncedAt: ios(NOW),
}));
checkouts.push({ ...checkouts[0], shopifyID: gid("AbandonedCheckout", 799), name: "#C799", lines: [{ productID: "", title: "Sem produto", quantity: 4 }] });

// Estatísticas dos últimos 40 dias (início do dia em Madrid).
const dailyStats = [];
for (let d = 0; d < 40; d += 1) {
  const midnight = Date.parse("2026-11-20T23:00:00Z") - d * DAY;
  const sessions = 60 + ((d * 37) % 50);
  dailyStats.push({
    date: ios(midnight),
    sales: 0, netRevenue: 0, orders: 0, units: 0, refunds: 0,
    sessions,
    cartSessions: Math.round(sessions * 0.05),
    checkoutSessions: Math.round(sessions * 0.025),
    completedSessions: Math.round(sessions * 0.012),
    hasTraffic: d < 35,
  });
}

const category = (uid, name, kind, budget, sortOrder) => ({
  uid, name, symbolName: "tag", colorName: "gray", kindRaw: kind, sortOrder, monthlyBudget: budget,
});
const categories = [
  category("CAT-FOOD", "Alimentação", "expense", 250, 0),
  category("CAT-HOME", "Casa", "expense", 0, 1),
  category("CAT-FUN", "Lazer", "expense", 80, 2),
  category("CAT-CAR", "Carro", "expense", 150, 3),
  category("CAT-SALARY", "Salário", "income", 0, 10),
];
let txCount = 0;
const tx = (iso, title, amount, kind, categoryUID, currencyCode = "EUR") => ({
  uid: `TX-${String(++txCount).padStart(3, "0")}`,
  title, amount, kindRaw: kind, currencyCode,
  date: ios(Date.parse(iso)), notes: "", createdAt: ios(Date.parse(iso)), externalID: "",
  ...(categoryUID ? { categoryUID } : {}),
});
const transactions = [
  tx("2026-11-02T09:00:00Z", "Mercadona", 54.37, "expense", "CAT-FOOD"),
  tx("2026-11-09T18:30:00Z", "Lidl", 41.2, "expense", "CAT-FOOD"),
  tx("2026-11-15T12:00:00Z", "Restaurante", 38.5, "expense", "CAT-FUN"),
  tx("2026-11-16T20:00:00Z", "Cinema", 45.9, "expense", "CAT-FUN"),
  tx("2026-11-05T08:00:00Z", "Renda", 750, "expense", "CAT-HOME"),
  tx("2026-11-12T10:00:00Z", "Presente (Brasil)", 310, "expense", "CAT-FUN", "BRL"),
  tx("2026-11-18T10:00:00Z", "Farmácia", 12.8, "expense", null),
  tx("2026-10-31T23:30:00Z", "Padaria (1 nov em Madrid)", 6.45, "expense", "CAT-FOOD"),
  tx("2026-11-30T23:30:00Z", "Já é dezembro em Madrid", 99, "expense", "CAT-FOOD"),
  tx("2026-10-20T10:00:00Z", "Mercado de outubro", 120, "expense", "CAT-FOOD"),
  tx("2026-11-01T09:00:00Z", "Salário", 1850, "income", "CAT-SALARY"),
  tx("2026-10-01T09:00:00Z", "Salário", 1850, "income", "CAT-SALARY"),
  tx("2026-11-10T09:00:00Z", "Venda no Brasil", 620, "income", null, "BRL"),
];

const fixture = {
  now: ios(NOW),
  timeZone: "Europe/Madrid",
  settings: {
    storeFeePercent: 2.9,
    storeFeeFixed: 0.3,
    storeShippingCost: 4.5,
    storeMonthlyAds: 60,
    googleAdsUnattributed30d: 15.5,
    brlPerEUR: 6.2,
  },
  archive: {
    format: 1,
    exportedAt: ios(NOW),
    appVersion: "parity",
    device: "fixture",
    categories, accounts: [], transactions, bills: [],
    storeProducts: products, storeOrders: orders, storeCheckouts: checkouts, dailyStats,
    projects: [], tasks: [], goals: [], notes: [], noteBlocks: [],
    vehicles: [], fuelEntries: [], maintenanceRecords: [], carDeadlines: [],
    documents: [], documentPhotos: [], jobApplications: [], courses: [],
    investments: [], wealthSnapshots: [], habits: [], habitChecks: [],
  },
};

mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, JSON.stringify(fixture, null, 2) + "\n");
console.log(`Gerado ${output}`);
