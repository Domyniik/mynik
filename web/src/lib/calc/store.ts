import type { DailyStatRow, StoreCheckoutRow, StoreOrderRow } from "../db/schema";
import { daysUntil } from "../format";

/** Linha de `store_product_scores` (o ranking calculado no SQL, igual ao iPhone). */
export interface ProductScore {
  product_id: string;
  title: string;
  price: number;
  unit_cost: number;
  age_days: number;
  units: number;
  ordered_units: number;
  refunded_units: number;
  revenue: number;
  days_since_last_sale: number | null;
  ad_spend: number;
  inventory: number;
  tracks_inventory: boolean;
  abandoned_units: number | null;
  margin_rate: number | null;
  refund_rate: number;
  roas: number | null;
  checkout_conversion: number | null;
  days_of_stock: number | null;
  score: number;
  classification: ProductClass;
  action: string;
  factors: { kind: FactorKind; points: number; max: number; hasData: boolean }[];
}

export type ProductClass = "winner" | "promising" | "testing" | "loser";
export type FactorKind = "sales" | "revenue" | "margin" | "funnel" | "refunds" | "recency" | "roas";

export const classMeta: Record<ProductClass, { title: string; plural: string; fg: string; bg: string; emoji: string }> = {
  winner: { title: "Vencedor", plural: "Vencedores", fg: "var(--winner-fg)", bg: "var(--winner-bg)", emoji: "🟢" },
  promising: { title: "Promissor", plural: "Promissores", fg: "var(--promising-fg)", bg: "var(--promising-bg)", emoji: "🟡" },
  testing: { title: "Em teste", plural: "Em teste", fg: "var(--testing-fg)", bg: "var(--testing-bg)", emoji: "🟠" },
  loser: { title: "Perdedor", plural: "Perdedores", fg: "var(--loser-fg)", bg: "var(--loser-bg)", emoji: "🔴" },
};

export const factorNames: Record<FactorKind, string> = {
  sales: "Vendas", revenue: "Receita", margin: "Margem", funnel: "Funil", refunds: "Reembolsos", recency: "Recência", roas: "ROAS",
};

export const TEST_PERIOD_DAYS = 14;

// ---------- Ciclo de vida (ProductLifecycle) ----------
export type Decision = "scale" | "keep" | "discontinue";
export const decisionMeta: Record<Decision, { title: string; state: string }> = {
  scale: { title: "Escalar", state: "A escalar" },
  keep: { title: "Manter", state: "Mantido" },
  discontinue: { title: "Descontinuar", state: "Descontinuado" },
};

export type Phase =
  | { kind: "testing"; daysLeft: number }
  | { kind: "awaiting"; suggested: Decision | null }
  | { kind: "decided"; decision: Decision };

export function phase(ageDays: number, decision: string, classification: ProductClass): Phase {
  if (decision in decisionMeta) return { kind: "decided", decision: decision as Decision };
  if (ageDays < TEST_PERIOD_DAYS) return { kind: "testing", daysLeft: TEST_PERIOD_DAYS - ageDays };
  return { kind: "awaiting", suggested: suggestedDecision(classification) };
}

export const phaseTitle = (p: Phase) => (p.kind === "testing" ? "Em teste" : p.kind === "awaiting" ? "Decisão pendente" : decisionMeta[p.decision].state);
export const phaseOrder = (p: Phase) =>
  p.kind === "awaiting" ? 0 : p.kind === "testing" ? 1 : p.decision === "scale" ? 2 : p.decision === "keep" ? 3 : 4;

export function suggestedDecision(c: ProductClass): Decision | null {
  return c === "winner" ? "scale" : c === "promising" ? "keep" : c === "loser" ? "discontinue" : null;
}

export function reviewWarning(decision: string, c: ProductClass, isActiveInShop: boolean): string | null {
  if (decision === "scale" && c === "loser") return "Está a escalar mas agora é perdedor: rever os anúncios.";
  if (decision === "keep" && c === "loser") return "Desceu para perdedor desde a decisão: considera descontinuar.";
  if (decision === "discontinue" && c === "winner") return "Foi descontinuado mas continua a vender bem: rever a decisão.";
  if (decision === "discontinue" && isActiveInShop) return "Descontinuado no Mynik mas ainda ativo na Shopify: arquiva-o na loja.";
  return null;
}

// ---------- Funil (FunnelDiagnosis) ----------
export type FunnelProblem = "pagePrice" | "checkoutShipping" | "traffic" | "healthy" | "notEnoughData" | "noTrafficData";

export const problemMeta: Record<FunnelProblem, { title: string; explanation: string; suggestions: string[] }> = {
  pagePrice: {
    title: "Página ou preço",
    explanation: "Quem visita a loja não adiciona ao carrinho: o produto, as fotos ou o preço não convencem.",
    suggestions: ["Melhorar as fotos e o vídeo do produto", "Testar o preço ou uma oferta (2 por X)", "Mostrar avaliações e prova social", "Rever o título e a descrição"],
  },
  checkoutShipping: {
    title: "Checkout ou frete",
    explanation: "Os clientes querem comprar mas desistem entre o carrinho e o pagamento, muitas vezes por portes ou custos inesperados.",
    suggestions: ["Mostrar os portes logo na página do produto", "Oferecer envio grátis a partir de um valor", "Ativar mais métodos de pagamento (MB WAY, Apple Pay)", "Recuperar carrinhos abandonados por e-mail"],
  },
  traffic: {
    title: "Tráfego",
    explanation: "Quem entra compra bem. O que limita as vendas é o número de visitas.",
    suggestions: ["Aumentar o orçamento dos anúncios que funcionam", "Publicar mais nas redes sociais", "Trabalhar o SEO das páginas de produto"],
  },
  healthy: { title: "Funil saudável", explanation: "Todas as etapas estão dentro dos valores de referência.", suggestions: [] },
  notEnoughData: { title: "Poucos dados", explanation: "São precisas pelo menos 100 visitas no período para um diagnóstico fiável.", suggestions: [] },
  noTrafficData: { title: "Sem dados de tráfego", explanation: "Sem sessões da Shopify não é possível ver o funil. Confirma o scope read_reports do app.", suggestions: [] },
};

export interface FunnelStage {
  name: string;
  count: number;
  rate: number | null;
  good: number | null;
  weak: number | null;
}

export const stageStatus = (s: FunnelStage) =>
  s.rate == null || s.good == null || s.weak == null ? "none" : s.rate >= s.good ? "good" : s.rate < s.weak ? "weak" : "ok";

export function diagnoseFunnel(stats: DailyStatRow[], days: number, now = new Date()) {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - (days - 1));
  const totals = { sessions: 0, cart: 0, checkout: 0, completed: 0, hasTraffic: false };
  for (const s of stats) {
    if (new Date(s.date) < start || !s.has_traffic) continue;
    totals.hasTraffic = true;
    totals.sessions += s.sessions;
    totals.cart += s.cart_sessions;
    totals.checkout += s.checkout_sessions;
    totals.completed += s.completed_sessions;
  }
  const rate = (part: number, whole: number) => (whole > 0 ? part / whole : null);
  const stages: FunnelStage[] = [
    { name: "Visitas", count: totals.sessions, rate: null, good: null, weak: null },
    { name: "Carrinho", count: totals.cart, rate: rate(totals.cart, totals.sessions), good: 0.06, weak: 0.04 },
    { name: "Checkout", count: totals.checkout, rate: rate(totals.checkout, totals.cart), good: 0.5, weak: 0.35 },
    { name: "Compra", count: totals.completed, rate: rate(totals.completed, totals.checkout), good: 0.5, weak: 0.35 },
  ];
  const perDay = totals.sessions / Math.max(1, days);
  let problem: FunnelProblem;
  const weak = stages.filter((s) => stageStatus(s) === "weak").sort((a, b) => a.rate! / a.weak! - b.rate! / b.weak!)[0];
  if (!totals.hasTraffic) problem = "noTrafficData";
  else if (totals.sessions < 100) problem = "notEnoughData";
  else if (weak) problem = weak.name === "Carrinho" ? "pagePrice" : "checkoutShipping";
  else if (perDay < 50) problem = "traffic";
  else problem = "healthy";
  return { stages, sessionsPerDay: perDay, conversionRate: rate(totals.completed, totals.sessions), problem };
}

// ---------- Operações (StoreOperations) ----------
export const LATE_AFTER_DAYS = 3;
const pendingStatuses = new Set(["UNFULFILLED", "PARTIALLY_FULFILLED", "IN_PROGRESS", "OPEN", "PENDING_FULFILLMENT", "ON_HOLD", "REQUEST_DECLINED"]);
export const unitCount = (o: StoreOrderRow) => (o.lines as { currentQuantity: number }[]).reduce((n, l) => n + l.currentQuantity, 0);

export function ordersToShip(orders: StoreOrderRow[], now = new Date()) {
  return orders
    .filter((o) => !o.cancelled_at && unitCount(o) > 0 && pendingStatuses.has(o.fulfillment_status) && o.financial_status !== "REFUNDED")
    .sort((a, b) => a.created_at.localeCompare(b.created_at))
    .map((order) => {
      const daysWaiting = Math.max(0, -daysUntil(order.created_at, now));
      return { order, daysWaiting, isLate: daysWaiting > LATE_AFTER_DAYS };
    });
}

export function recentCheckouts(checkouts: StoreCheckoutRow[], days = 30, now = new Date()) {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - (days - 1));
  return checkouts.filter((c) => new Date(c.created_at) >= start).sort((a, b) => b.created_at.localeCompare(a.created_at));
}

// ---------- Alertas (StoreAlerts) ----------
export interface StoreAlert {
  id: string;
  title: string;
  message: string;
  critical: boolean;
  productID?: string;
}

export function daysWithoutSales(orders: StoreOrderRow[], now = new Date()) {
  const last = orders.filter((o) => !o.cancelled_at).map((o) => o.created_at).sort().at(-1);
  return last ? -daysUntil(last, now) : null;
}

export function storeAlerts(orders: StoreOrderRow[], scores: ProductScore[], noSaleDays: number, now = new Date()): StoreAlert[] {
  const alerts: StoreAlert[] = [];
  const days = daysWithoutSales(orders, now);
  if (days != null && days >= noSaleDays) {
    alerts.push({ id: "noSales", title: `${days} dias sem venda`, message: `A última venda foi há ${days} dias. Vale a pena ver os anúncios e o funil.`, critical: days >= noSaleDays * 2 });
  }
  const late = ordersToShip(orders, now).filter((p) => p.isLate);
  if (late.length) {
    alerts.push({
      id: "lateOrders", critical: true,
      title: late.length === 1 ? "1 pedido atrasado" : `${late.length} pedidos atrasados`,
      message: `À espera de envio há mais de ${LATE_AFTER_DAYS} dias (o mais antigo: ${late[0].order.name}).`,
    });
  }
  for (const p of scores) {
    if (p.age_days < 14) continue;
    const stale = p.days_since_last_sale ?? p.age_days;
    if (stale < 14) continue;
    alerts.push({
      id: `stale-${p.product_id}`, productID: p.product_id, critical: false,
      title: `${p.title}: ${stale} dias sem venda`,
      message: p.days_since_last_sale == null ? "Ainda não vendeu desde que entrou na loja." : "Considera rever a oferta ou tirar de destaque.",
    });
  }
  for (const p of scores) {
    if (p.days_of_stock == null || p.days_of_stock >= 7) continue;
    alerts.push({
      id: `stock-${p.product_id}`, productID: p.product_id, critical: p.days_of_stock < 3,
      title: `${p.title}: stock para ${p.days_of_stock} dias`,
      message: `Restam ${p.inventory} unidades ao ritmo de ${p.units} por mês.`,
    });
  }
  return alerts.sort((a, b) => Number(b.critical) - Number(a.critical));
}
