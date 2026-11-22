import type { AccountRow, BillRow, CategoryRow, TransactionRow } from "../db/schema";

/** Contas de Finanças feitas no browser (as de orçamento e resumo do mês vêm do SQL). */

export const DEFAULT_BRL_PER_EUR = 6.0;

/** Valor em EUR (CurrencyConverter do iPhone). */
export function toEur(amount: number, currency: string, brlPerEur: number) {
  if (currency === "BRL") return amount / (brlPerEur > 0 ? brlPerEur : DEFAULT_BRL_PER_EUR);
  return amount;
}

export function convert(amount: number, from: string, to: string, brlPerEur: number) {
  if (from === to) return amount;
  if (from === "EUR" && to === "BRL") return amount * (brlPerEur > 0 ? brlPerEur : DEFAULT_BRL_PER_EUR);
  if (from === "BRL" && to === "EUR") return toEur(amount, from, brlPerEur);
  return amount;
}

export const signed = (t: Pick<TransactionRow, "kind" | "amount">) => (t.kind === "expense" ? -t.amount : t.amount);

/** Saldo = saldo inicial + movimentos da conta (na moeda da conta, como no iPhone). */
export function accountBalance(account: AccountRow, transactions: TransactionRow[]) {
  return transactions.filter((t) => t.account_id === account.id).reduce((sum, t) => sum + signed(t), account.initial_balance);
}

export const sameMonth = (a: Date, b: Date) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();

export function monthSummary(month: Date, transactions: TransactionRow[], rate: number) {
  let income = 0;
  let expenses = 0;
  for (const t of transactions) {
    if (!sameMonth(new Date(t.date), month)) continue;
    const value = toEur(t.amount, t.currency_code, rate);
    if (t.kind === "income") income += value;
    else expenses += value;
  }
  return { income, expenses, balance: income - expenses };
}

export const UNCATEGORIZED = "Sem categoria";

/** Gastos do mês por categoria, do maior para o menor. */
export function expensesByCategory(month: Date, transactions: TransactionRow[], categories: CategoryRow[], rate: number) {
  const byID = new Map(categories.map((c) => [c.id, c]));
  const totals = new Map<string, { name: string; category: CategoryRow | null; amount: number }>();
  for (const t of transactions) {
    if (t.kind !== "expense" || !sameMonth(new Date(t.date), month)) continue;
    const category = t.category_id ? byID.get(t.category_id) ?? null : null;
    const name = category?.name ?? UNCATEGORIZED;
    const entry = totals.get(name) ?? { name, category, amount: 0 };
    entry.amount += toEur(t.amount, t.currency_code, rate);
    totals.set(name, entry);
  }
  return [...totals.values()].sort((a, b) => b.amount - a.amount || a.name.localeCompare(b.name));
}

/** Receitas e gastos dos últimos `count` meses, do mais antigo para `month`. */
export function monthlyTotals(month: Date, transactions: TransactionRow[], rate: number, count = 6) {
  return Array.from({ length: count }, (_, i) => {
    const start = new Date(month.getFullYear(), month.getMonth() - (count - 1 - i), 1);
    return { month: start, ...monthSummary(start, transactions, rate) };
  });
}

/** Gastos acumulados de cada dia do mês até hoje (mini-gráfico do Hoje). */
export function cumulativeExpenses(now: Date, transactions: TransactionRow[], rate: number) {
  const perDay = Array<number>(now.getDate()).fill(0);
  for (const t of transactions) {
    const d = new Date(t.date);
    if (t.kind !== "expense" || !sameMonth(d, now) || d.getDate() > now.getDate()) continue;
    perDay[d.getDate() - 1] += toEur(t.amount, t.currency_code, rate);
  }
  let total = 0;
  return perDay.map((v) => (total += v));
}

export const recurrenceTitle: Record<string, string> = { none: "Única", weekly: "Semanal", monthly: "Mensal", yearly: "Anual" };

/** Custo mensal equivalente de uma conta recorrente (EUR). */
export function monthlyCost(bill: Pick<BillRow, "amount" | "currency_code" | "recurrence">, rate: number) {
  const amount = toEur(bill.amount, bill.currency_code, rate);
  switch (bill.recurrence) {
    case "weekly":
      return (amount * 52) / 12;
    case "monthly":
      return amount;
    case "yearly":
      return amount / 12;
    default:
      return 0;
  }
}

/** Próximo vencimento depois de pago (como `BillRecurrence.nextDate`). */
export function nextDueDate(due: string, recurrence: string): string | null {
  const d = new Date(due);
  if (recurrence === "weekly") d.setDate(d.getDate() + 7);
  else if (recurrence === "monthly") d.setMonth(d.getMonth() + 1);
  else if (recurrence === "yearly") d.setFullYear(d.getFullYear() + 1);
  else return null;
  return d.toISOString();
}

export const accountTypes: Record<string, string> = { checking: "Conta à ordem", savings: "Poupança", card: "Cartão", cash: "Dinheiro" };
