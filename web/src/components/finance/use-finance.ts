"use client";

import { useMemo } from "react";
import { useTable } from "@/lib/db/store";
import { useSettings } from "@/lib/settings";

/** Categorias (pela ordem do iPhone), contas e taxa BRL/EUR. */
export function useFinanceBasics() {
  const categories = useTable("categories");
  const accounts = useTable("accounts");
  const { settings } = useSettings();
  const sorted = useMemo(
    () => [...categories.rows].sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name, "pt")),
    [categories.rows],
  );
  return {
    categories: sorted,
    expenseCategories: sorted.filter((c) => c.kind === "expense"),
    incomeCategories: sorted.filter((c) => c.kind === "income"),
    accounts: accounts.rows.filter((a) => !a.is_archived).sort((a, b) => a.created_at.localeCompare(b.created_at)),
    allAccounts: accounts.rows,
    rate: settings.brlPerEUR,
    loading: categories.loading || accounts.loading,
  };
}
