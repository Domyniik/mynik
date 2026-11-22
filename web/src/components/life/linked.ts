"use client";

import { newID, now } from "@/lib/db/client";
import type { AccountRow, CategoryRow, TransactionRow } from "@/lib/db/schema";
import { mutate } from "@/lib/db/store";

interface Context {
  transactions: TransactionRow[];
  categories: CategoryRow[];
  accounts: AccountRow[];
}

/** Categoria de gasto com este nome (criada na primeira vez, como no iPhone). */
export async function expenseCategory(name: string, ctx: Context, symbol = "tag", color = "gray") {
  const found = ctx.categories.find((c) => c.kind === "expense" && c.name === name);
  if (found) return found.id;
  const inserted = await mutate.insert("categories", { id: newID(), name, kind: "expense", symbol_name: symbol, color_name: color, sort_order: ctx.categories.length, monthly_budget: 0 });
  return inserted.id;
}

/**
 * Movimento mantido por outro módulo (LinkedTransactionService): identificado
 * pelo `externalID`, editar a origem atualiza o mesmo movimento. Valor 0 apaga-o.
 */
export async function upsertLinkedExpense(
  e: { externalID: string; title: string; amount: number; currency: string; date: string; categoryName: string; notes?: string },
  ctx: Context,
) {
  const existing = ctx.transactions.find((t) => t.external_id === e.externalID);
  if (e.amount <= 0) {
    if (existing) await mutate.remove("transactions", [existing.id]);
    return null;
  }
  const categoryID = await expenseCategory(e.categoryName, ctx, e.categoryName === "Carro" ? "car" : "tag", e.categoryName === "Carro" ? "orange" : "gray");
  const row = { title: e.title, amount: e.amount, kind: "expense", currency_code: e.currency, date: e.date, notes: e.notes ?? "", category_id: categoryID };
  if (existing) {
    await mutate.update("transactions", existing.id, row);
    return existing.id;
  }
  const account = [...ctx.accounts].filter((a) => !a.is_archived).sort((a, b) => a.created_at.localeCompare(b.created_at))[0];
  await mutate.insert("transactions", { id: newID(), created_at: now(), external_id: e.externalID, account_id: account?.id ?? null, ...row });
  return e.externalID;
}

export async function removeLinked(externalID: string, ctx: Context) {
  const existing = ctx.transactions.find((t) => t.external_id === externalID);
  if (existing) await mutate.remove("transactions", [existing.id]);
}
