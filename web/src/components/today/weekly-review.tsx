"use client";

import { useMemo } from "react";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { weeklyReview } from "@/lib/calc/life";
import { useTables } from "@/lib/db/store";
import { change, date, money } from "@/lib/format";
import { useSettings } from "@/lib/settings";

/** Revisão da semana (segunda a domingo): dinheiro, contas, tarefas, hábitos e loja. */
export function WeeklyReview({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { data } = useTables("transactions", "categories", "bills", "tasks", "habits", "habit_checks", "store_orders");
  const { settings } = useSettings();
  const r = useMemo(
    () => weeklyReview({
      transactions: data.transactions, categories: data.categories, bills: data.bills, tasks: data.tasks,
      habits: data.habits, checks: data.habit_checks, orders: data.store_orders, rate: settings.brlPerEUR,
    }),
    [data, settings.brlPerEUR],
  );
  const last = new Date(r.end);
  last.setDate(last.getDate() - 1);
  const row = (label: string, value: string) => (
    <div key={label} className="flex justify-between gap-3 text-sm"><span className="text-muted-foreground">{label}</span><span className="tabular font-medium">{value}</span></div>
  );
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Revisão da semana</DialogTitle>
          <DialogDescription>{date(r.start, "short")} – {date(last, "short")}</DialogDescription>
        </DialogHeader>
        <section className="flex flex-col gap-2">
          <h3 className="m-0 text-sm font-semibold">Dinheiro</h3>
          {row("Gastos", money(r.expenses))}
          {row("Receitas", money(r.income))}
          {row("Face à semana anterior", change(r.expenseChange))}
          {r.topCategories.map((c) => row(`· ${c.name}`, money(c.amount)))}
        </section>
        <section className="flex flex-col gap-2">
          <h3 className="m-0 text-sm font-semibold">Contas</h3>
          {row("Pagas esta semana", String(r.billsPaid))}
          {row("Para a próxima semana", r.billsNextWeek ? `${r.billsNextWeek} · ${money(r.billsNextWeekTotal)}` : "Nenhuma")}
        </section>
        <section className="flex flex-col gap-2">
          <h3 className="m-0 text-sm font-semibold">Produtividade</h3>
          {row("Tarefas concluídas", String(r.tasksCompleted))}
          {row("Hábitos no objetivo", `${r.habitsOnTrack} de ${r.habits.length}`)}
          {r.habits.map((h) => row(`· ${h.name}`, `${h.done}/${h.target}`))}
        </section>
        <section className="flex flex-col gap-2">
          <h3 className="m-0 text-sm font-semibold">Loja</h3>
          {row("Vendas", money(r.storeSales))}
          {row("Pedidos", String(r.storeOrders))}
        </section>
      </DialogContent>
    </Dialog>
  );
}
