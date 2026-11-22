"use client";

import { ChevronLeft, ChevronRight, RefreshCw, Search } from "lucide-react";
import { useMemo, useState } from "react";
import { Empty, Kpi } from "@/components/shell/page-header";
import { SortableTable } from "@/components/common/sortable-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { sameMonth, signed, toEur } from "@/lib/calc/finance";
import { searchKey } from "@/lib/calc/search";
import type { TransactionRow } from "@/lib/db/schema";
import { useRpc, useTable } from "@/lib/db/store";
import { date, money, TIME_ZONE, toDateInput } from "@/lib/format";
import { SymbolIcon } from "@/lib/icons";
import { useFinanceBasics } from "./use-finance";

export function MonthStepper({ month, onChange }: { month: Date; onChange: (month: Date) => void }) {
  const shift = (delta: number) => onChange(new Date(month.getFullYear(), month.getMonth() + delta, 1));
  const text = new Intl.DateTimeFormat("pt-PT", { month: "long", year: "numeric" }).format(month);
  const label = text[0].toUpperCase() + text.slice(1);
  return (
    <div className="flex items-center gap-1">
      <Button variant="ghost" size="icon" aria-label="Mês anterior" onClick={() => shift(-1)}><ChevronLeft /></Button>
      <span className="min-w-36 text-center font-medium">{label}</span>
      <Button variant="ghost" size="icon" aria-label="Mês seguinte" onClick={() => shift(1)}><ChevronRight /></Button>
    </div>
  );
}

/** Receitas, gastos e saldo de um mês, pela função SQL (o mesmo número do iPhone). */
export function useMonthSummary(month: Date) {
  const { data } = useRpc<{ income: number; expenses: number; balance: number }>(
    "month_summary",
    { p_month: toDateInput(new Date(month.getFullYear(), month.getMonth(), 1)), p_tz: TIME_ZONE },
    ["transactions", "user_settings"],
  );
  return data[0] ?? { income: 0, expenses: 0, balance: 0 };
}

export function TransactionsView({ onEdit }: { onEdit: (t: TransactionRow) => void }) {
  const { rows, loading } = useTable("transactions");
  const { categories, allAccounts, rate } = useFinanceBasics();
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [query, setQuery] = useState("");
  const summary = useMonthSummary(month);
  const categoryByID = useMemo(() => new Map(categories.map((c) => [c.id, c])), [categories]);
  const accountByID = useMemo(() => new Map(allAccounts.map((a) => [a.id, a])), [allAccounts]);

  const visible = useMemo(() => {
    const key = searchKey(query);
    return rows.filter((t) => {
      if (key) return searchKey(`${t.title} ${t.notes} ${categoryByID.get(t.category_id ?? "")?.name ?? ""}`).includes(key);
      return sameMonth(new Date(t.date), month);
    });
  }, [rows, month, query, categoryByID]);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <MonthStepper month={month} onChange={setMonth} />
        <label className="flex h-9 min-w-64 items-center gap-2 rounded-md border border-input bg-input/30 px-3 text-muted-foreground">
          <Search size={16} aria-hidden="true" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Procurar em todos os meses…"
            aria-label="Procurar movimentos"
            className="flex-1 bg-transparent text-foreground outline-none"
          />
        </label>
      </div>
      {!query && (
        <section aria-label="Resumo do mês" className="grid grid-cols-3 gap-4">
          <Kpi label="Receitas" value={money(summary.income)} />
          <Kpi label="Gastos" value={money(summary.expenses)} />
          <Kpi label="Saldo do mês" value={money(summary.balance)} tone={summary.balance >= 0 ? "positive" : "danger"} note={summary.balance >= 0 ? "Poupaste este mês" : "Gastaste mais do que recebeste"} />
        </section>
      )}
      <div className="rounded-[14px] border border-border bg-card p-2">
        <SortableTable
          rows={visible}
          rowKey={(t) => t.id}
          onRowClick={onEdit}
          initialSort={{ key: "date", dir: "desc" }}
          empty={<Empty title={loading ? "A carregar…" : query ? "Sem resultados" : "Sem movimentos neste mês"}>Adiciona com ⌘N ou arrasta o CSV do banco para esta janela.</Empty>}
          columns={[
            { key: "date", header: "Data", sort: (t) => t.date, cell: (t) => <span className="text-muted-foreground">{date(t.date, "short")}</span>, className: "w-20" },
            {
              key: "title", header: "Descrição", sort: (t) => t.title,
              cell: (t) => {
                const c = categoryByID.get(t.category_id ?? "");
                return (
                  <span className="flex items-center gap-2.5">
                    <SymbolIcon name={c?.symbol_name ?? "questionmark"} color={c?.color_name} size={28} />
                    <span className="flex min-w-0 flex-col">
                      <span className="truncate font-medium">{t.title}</span>
                      {t.external_id && <span className="flex items-center gap-1 text-xs text-muted-foreground"><RefreshCw size={11} aria-hidden="true" /> Atualizado automaticamente</span>}
                    </span>
                  </span>
                );
              },
            },
            { key: "category", header: "Categoria", sort: (t) => categoryByID.get(t.category_id ?? "")?.name ?? "", cell: (t) => <span className="text-muted-foreground">{categoryByID.get(t.category_id ?? "")?.name ?? "Sem categoria"}</span> },
            { key: "account", header: "Conta", sort: (t) => accountByID.get(t.account_id ?? "")?.name ?? "", cell: (t) => <span className="text-muted-foreground">{accountByID.get(t.account_id ?? "")?.name ?? "—"}</span> },
            {
              key: "amount", header: "Valor", align: "right", sort: (t) => toEur(signed(t), t.currency_code, rate),
              cell: (t) => (
                <span className="flex flex-col items-end">
                  <span className={t.kind === "income" ? "font-semibold text-positive" : "font-semibold"}>{money(signed(t), t.currency_code, { signed: true })}</span>
                  {t.currency_code !== "EUR" && <span className="text-xs text-muted-foreground">≈ {money(toEur(signed(t), t.currency_code, rate))}</span>}
                </span>
              ),
            },
          ]}
        />
      </div>
    </div>
  );
}
