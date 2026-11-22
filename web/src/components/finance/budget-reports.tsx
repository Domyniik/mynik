"use client";

import { useMemo, useState } from "react";
import { Bar as RBar, BarChart, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Bar, Card, Empty, Kpi } from "@/components/shell/page-header";
import { Field, FormDialog, MoneyInput } from "@/components/common/fields";
import { expensesByCategory, monthlyTotals } from "@/lib/calc/finance";
import { mutate, useRpc, useTable } from "@/lib/db/store";
import { money, percent, TIME_ZONE, toDateInput } from "@/lib/format";
import { colorHex, SymbolIcon } from "@/lib/icons";
import { MonthStepper } from "./transactions-view";
import { useFinanceBasics } from "./use-finance";

export interface BudgetLine {
  category_id: string;
  name: string;
  symbol_name: string;
  color_name: string;
  budget: number;
  spent: number;
  remaining: number;
  has_budget: boolean;
  over_budget: boolean;
  progress: number;
}

/** Orçamento por categoria no mês (função SQL `budget_overview`, a mesma conta do iPhone). */
export function useBudget(month: Date) {
  return useRpc<BudgetLine>(
    "budget_overview",
    { p_month: toDateInput(new Date(month.getFullYear(), month.getMonth(), 1)), p_tz: TIME_ZONE },
    ["transactions", "categories", "user_settings"],
  );
}

export const budgetColor = (progress: number) => (progress >= 1 ? "var(--alert)" : progress >= 0.9 ? "var(--warning)" : "var(--primary)");

export function BudgetView() {
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const { data } = useBudget(month);
  const [editing, setEditing] = useState<BudgetLine | null>(null);
  const [value, setValue] = useState<number | null>(null);
  const budgeted = data.filter((l) => l.has_budget).sort((a, b) => b.progress - a.progress);
  const unbudgeted = data.filter((l) => !l.has_budget).sort((a, b) => b.spent - a.spent);
  const totalBudget = budgeted.reduce((s, l) => s + l.budget, 0);
  const totalSpent = budgeted.reduce((s, l) => s + l.spent, 0);
  const open = (line: BudgetLine) => {
    setEditing(line);
    setValue(line.budget || null);
  };

  const row = (l: BudgetLine) => (
    <button key={l.category_id} type="button" onClick={() => open(l)} className="flex w-full flex-col gap-1.5 text-left">
      <span className="flex items-center justify-between gap-3 text-[13px]">
        <span className="flex items-center gap-2"><SymbolIcon name={l.symbol_name} color={l.color_name} size={24} />{l.name}</span>
        <span className={l.over_budget ? "text-alert" : "text-muted-foreground"}>
          {money(l.spent)}{l.has_budget && ` / ${money(l.budget)}`}
        </span>
      </span>
      {l.has_budget && <Bar value={l.progress} color={budgetColor(l.progress)} />}
    </button>
  );

  return (
    <div className="flex flex-col gap-4">
      <MonthStepper month={month} onChange={setMonth} />
      <div className="grid grid-cols-3 gap-4">
        <Kpi label="Orçamento do mês" value={money(totalBudget)} />
        <Kpi label="Gasto nas categorias com orçamento" value={money(totalSpent)} note={totalBudget > 0 ? `${percent(totalSpent / totalBudget)} do orçamento` : undefined} />
        <Kpi label="Disponível" value={money(totalBudget - totalSpent)} tone={totalBudget - totalSpent >= 0 ? "positive" : "danger"} />
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Card title="Com orçamento">{budgeted.length ? budgeted.map(row) : <Empty title="Sem orçamentos">Clica numa categoria para definir quanto queres gastar por mês.</Empty>}</Card>
        <Card title="Sem orçamento">{unbudgeted.length ? unbudgeted.map(row) : <Empty title="Todas as categorias têm orçamento" />}</Card>
      </div>
      <FormDialog
        open={editing != null}
        onOpenChange={(o) => !o && setEditing(null)}
        title={`Orçamento · ${editing?.name ?? ""}`}
        description="Limite mensal em euros. Deixa a 0 para não ter orçamento."
        onSubmit={async () => {
          if (editing) await mutate.update("categories", editing.category_id, { monthly_budget: value ?? 0 });
        }}
      >
        <Field label="Orçamento">{(id) => <MoneyInput id={id} value={value} onChange={setValue} autoFocus />}</Field>
      </FormDialog>
    </div>
  );
}

const tooltipStyle = { background: "var(--card)", border: "1px solid var(--border)", borderRadius: 10, color: "var(--foreground)" };

export function ReportsView() {
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const { rows } = useTable("transactions");
  const { categories, rate } = useFinanceBasics();
  const slices = useMemo(() => expensesByCategory(month, rows, categories, rate), [month, rows, categories, rate]);
  const totals = useMemo(() => monthlyTotals(month, rows, rate), [month, rows, rate]);
  const total = slices.reduce((s, x) => s + x.amount, 0);

  return (
    <div className="flex flex-col gap-4">
      <MonthStepper month={month} onChange={setMonth} />
      <div className="grid gap-4 lg:grid-cols-2">
        <Card title="Gastos por categoria">
          {slices.length === 0 ? (
            <Empty title="Sem gastos neste mês" />
          ) : (
            <div className="flex flex-col gap-4">
              <div className="relative h-56" role="img" aria-label={`Gastos por categoria: total ${money(total)}`}>
                <ResponsiveContainer>
                  <PieChart>
                    <Pie data={slices} dataKey="amount" nameKey="name" innerRadius="62%" outerRadius="92%" stroke="var(--card)" strokeWidth={2}>
                      {slices.map((s) => <Cell key={s.name} fill={colorHex(s.category?.color_name)} />)}
                    </Pie>
                    <Tooltip formatter={(v) => money(Number(v))} contentStyle={tooltipStyle} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-xs text-muted-foreground">Total</span>
                  <span className="tabular text-lg font-bold">{money(total)}</span>
                </div>
              </div>
              <ul className="m-0 flex list-none flex-col gap-2 p-0">
                {slices.map((s) => (
                  <li key={s.name} className="flex items-center justify-between gap-3 text-[13px]">
                    <span className="flex items-center gap-2"><span className="size-2.5 rounded-full" style={{ background: colorHex(s.category?.color_name) }} />{s.name}</span>
                    <span className="tabular text-muted-foreground">{money(s.amount)} · {percent(s.amount / total)}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Card>
        <Card title="Receitas e gastos · 6 meses">
          <div className="h-72" role="img" aria-label="Receitas e gastos dos últimos 6 meses">
            <ResponsiveContainer>
              <BarChart data={totals.map((t) => ({ ...t, label: new Intl.DateTimeFormat("pt-PT", { month: "short" }).format(t.month) }))}>
                <XAxis dataKey="label" stroke="var(--muted-foreground)" tickLine={false} axisLine={false} />
                <YAxis stroke="var(--muted-foreground)" tickLine={false} axisLine={false} tickFormatter={(v) => money(Number(v), "EUR", { compact: true })} width={70} />
                <Tooltip formatter={(v) => money(Number(v))} contentStyle={tooltipStyle} cursor={{ fill: "var(--surface)" }} />
                <Legend formatter={(v) => (v === "income" ? "Receitas" : "Gastos")} />
                <RBar dataKey="income" fill="var(--positive)" radius={[6, 6, 2, 2]} />
                <RBar dataKey="expenses" fill="var(--primary)" radius={[6, 6, 2, 2]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>
    </div>
  );
}
