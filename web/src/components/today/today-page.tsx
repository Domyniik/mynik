"use client";

import { CalendarCheck, Plus, Search } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import { Bar, Card, Empty, Kpi } from "@/components/shell/page-header";
import { openCommandMenu } from "@/components/shell/app-shell";
import { BillLine } from "@/components/finance/bills";
import { budgetColor, useBudget } from "@/components/finance/budget-reports";
import { TransactionForm } from "@/components/finance/transaction-form";
import { useMonthSummary } from "@/components/finance/transactions-view";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { cumulativeExpenses } from "@/lib/calc/finance";
import {
  checkFor, describeAgenda, goalProgress, habitProgress, isOverdue, lifeAgenda, statusPatch, tasksForToday, upcomingAgenda,
} from "@/lib/calc/life";
import { ordersToShip } from "@/lib/calc/store";
import { newID, now } from "@/lib/db/client";
import { mutate, useRpc, useTables } from "@/lib/db/store";
import { change, date, daysUntil, money, TIME_ZONE } from "@/lib/format";
import { colorHex, SymbolIcon } from "@/lib/icons";
import { useSession } from "@/lib/session";
import { useSettings } from "@/lib/settings";
import { cn } from "@/lib/utils";
import { CalendarCard } from "./calendar-card";
import { WeeklyReview } from "./weekly-review";

function greeting(hour: number) {
  return hour < 6 ? "Boa noite" : hour < 13 ? "Bom dia" : hour < 20 ? "Boa tarde" : "Boa noite";
}

/** Linha de gastos acumulados do mês (mini-gráfico). */
function Sparkline({ values }: { values: number[] }) {
  if (values.length < 2) return null;
  const max = Math.max(...values, 1);
  const points = values.map((v, i) => `${(i / (values.length - 1)) * 100},${30 - (v / max) * 28}`).join(" ");
  return (
    <svg viewBox="0 0 100 32" preserveAspectRatio="none" className="h-8 w-full" aria-hidden="true">
      <polyline points={points} fill="none" stroke="var(--primary)" strokeWidth="2" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

export default function TodayPage() {
  const { email } = useSession();
  const { settings } = useSettings();
  const [expenseOpen, setExpenseOpen] = useState(false);
  const [reviewOpen, setReviewOpen] = useState(false);
  const { data } = useTables(
    "transactions", "bills", "categories", "accounts", "tasks", "projects", "goals", "habits", "habit_checks",
    "store_orders", "vehicles", "car_deadlines", "maintenance_records", "fuel_entries", "documents", "job_applications", "courses",
  );
  const today = new Date();
  const month = new Date(today.getFullYear(), today.getMonth(), 1);
  const summary = useMonthSummary(month);
  const previous = useMonthSummary(new Date(today.getFullYear(), today.getMonth() - 1, 1));
  const { data: budget } = useBudget(month);
  const { data: store } = useRpc<{ period: string; gross_sales: number; orders: number }>("store_kpis", { p_days: 1, p_tz: TIME_ZONE }, ["store_orders", "store_products"]);
  const { data: week } = useRpc<{ period: string; gross_sales: number }>("store_kpis", { p_days: 7, p_tz: TIME_ZONE }, ["store_orders", "store_products"]);
  const { data: points } = useRpc<{ day: string; sales: number }>("store_daily_points", { p_days: 7, p_tz: TIME_ZONE }, ["store_orders"]);
  const rate = settings.brlPerEUR;

  const dueBills = data.bills.filter((b) => !b.is_paid && daysUntil(b.due_date) <= 7).sort((a, b) => a.due_date.localeCompare(b.due_date));
  const dueTotal = dueBills.reduce((s, b) => s + (b.currency_code === "BRL" ? b.amount / rate : b.amount), 0);
  const totalBudget = budget.filter((l) => l.has_budget).reduce((s, l) => s + l.budget, 0);
  const trend = useMemo(() => cumulativeExpenses(today, data.transactions, rate), [data.transactions, rate]); // eslint-disable-line react-hooks/exhaustive-deps
  const toShip = ordersToShip(data.store_orders).length;
  const storeToday = store.find((k) => k.period === "current");
  const weekNow = week.find((k) => k.period === "current")?.gross_sales ?? 0;
  const weekBefore = week.find((k) => k.period === "previous")?.gross_sales ?? 0;
  const maxDay = Math.max(1, ...points.map((p) => p.sales));
  const tasks = tasksForToday(data.tasks);
  const projectName = new Map(data.projects.map((p) => [p.id, p.name]));
  const goals = data.goals
    .filter((g) => !g.is_archived)
    .map((g) => ({ g, p: goalProgress(g, { accounts: data.accounts, transactions: data.transactions, categories: data.categories, rate }) }))
    .filter(({ p }) => !p.isReached)
    .slice(0, 3);
  const projects = data.projects
    .filter((p) => p.status === "active")
    .map((p) => {
      const all = data.tasks.filter((t) => t.project_id === p.id);
      return { p, done: all.filter((t) => t.status === "done").length, total: all.length };
    })
    .filter((x) => x.total > 0)
    .slice(0, 3);
  const habits = data.habits.filter((h) => !h.is_archived).sort((a, b) => a.sort_order - b.sort_order);
  const agenda = upcomingAgenda(lifeAgenda({
    vehicles: data.vehicles, deadlines: data.car_deadlines, maintenance: data.maintenance_records, fuel: data.fuel_entries,
    documents: data.documents, applications: data.job_applications, courses: data.courses,
  }));
  const isSunday = today.getDay() === 0;
  const name = email ? email.split("@")[0] : "Domynik";
  const longDate = new Intl.DateTimeFormat("pt-PT", { weekday: "long", day: "numeric", month: "long", timeZone: TIME_ZONE }).format(today);

  async function toggleHabit(habitID: string) {
    const habit = data.habits.find((h) => h.id === habitID)!;
    const existing = checkFor(habit, data.habit_checks);
    if (existing) await mutate.remove("habit_checks", [existing.id]);
    else {
      const day = new Date();
      day.setHours(0, 0, 0, 0);
      await mutate.insert("habit_checks", { id: newID(), day: day.toISOString(), created_at: now(), habit_id: habitID });
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-col gap-1">
          <h1 className="m-0 text-[26px] font-bold tracking-tight">{greeting(today.getHours())}, <span className="capitalize">{name}</span></h1>
          <p className="m-0 text-muted-foreground">{longDate[0].toUpperCase() + longDate.slice(1)}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2.5">
          <button type="button" onClick={openCommandMenu} className="flex h-10 min-w-[260px] items-center gap-2 rounded-[10px] border border-input bg-card px-3 text-muted-foreground">
            <Search size={16} aria-hidden="true" />
            <span className="flex-1 text-left">Procurar ou executar ação…</span>
            <kbd className="rounded-md border border-input px-1.5 text-xs">⌘K</kbd>
          </button>
          <Button variant="outline" className="h-10" onClick={() => setReviewOpen(true)}><CalendarCheck aria-hidden="true" /> Revisão</Button>
          <Button className="h-10" onClick={() => setExpenseOpen(true)}><Plus aria-hidden="true" /> Novo gasto</Button>
        </div>
      </header>

      {isSunday && (
        <button type="button" onClick={() => setReviewOpen(true)} className="rounded-[14px] border border-primary/40 bg-primary/10 p-4 text-left">
          <strong>É domingo:</strong> vê como correu a semana e prepara a próxima.
        </button>
      )}

      <section aria-label="Resumo" className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <Kpi
          label="Saldo do mês"
          value={money(summary.balance)}
          note={previous.balance !== 0 ? `${money(summary.balance - previous.balance, "EUR", { signed: true })} vs mês anterior` : "Receitas − gastos"}
          tone={summary.balance >= previous.balance ? "positive" : "warning"}
        />
        <div className="flex min-w-0 flex-col gap-2 rounded-[14px] border border-border bg-card p-[18px]">
          <span className="text-[13px] text-muted-foreground">Gastos do mês</span>
          <span className="tabular text-[22px] font-bold tracking-tight xl:text-[28px]">{money(summary.expenses)}</span>
          <Sparkline values={trend} />
          <span className="text-xs text-muted-foreground">{totalBudget > 0 ? `${Math.round((summary.expenses / totalBudget) * 100)} % do orçamento` : "Sem orçamento definido"}</span>
        </div>
        <Kpi label="Vendas da loja hoje" value={money(storeToday?.gross_sales ?? 0)} note={`${storeToday?.orders ?? 0} pedidos · ${toShip} por enviar`} tone={toShip > 0 ? "warning" : "muted"} />
        <Kpi label="A pagar em 7 dias" value={money(dueTotal)} note={`${dueBills.length} contas`} />
      </section>

      <section className="grid gap-4 xl:grid-cols-3">
        <Card title="Contas a vencer" action={<Link href="/financas/?tab=contas" className="text-[13px]">Ver todas</Link>}>
          {dueBills.length === 0 ? <Empty title="Nada a pagar nos próximos 7 dias" /> : dueBills.map((b) => <BillLine key={b.id} bill={b} />)}
        </Card>
        <Card title="Gastos por categoria" action={<span className="text-xs capitalize text-muted-foreground">{new Intl.DateTimeFormat("pt-PT", { month: "long" }).format(today)}</span>}>
          {budget.filter((l) => l.spent > 0 || l.has_budget).sort((a, b) => b.spent - a.spent).slice(0, 5).map((l) => (
            <div key={l.category_id} className="flex flex-col gap-1.5">
              <div className="flex justify-between text-[13px]"><span>{l.name}</span><span className="text-muted-foreground">{money(l.spent)}{l.has_budget && ` / ${money(l.budget)}`}</span></div>
              <Bar value={l.has_budget ? l.progress : 0} color={budgetColor(l.progress)} />
            </div>
          ))}
          {budget.every((l) => l.spent === 0 && !l.has_budget) && <Empty title="Sem gastos este mês" />}
        </Card>
        <Card title="Vendas da loja · 7 dias" action={<Link href="/loja/" className="text-[13px]">Abrir loja</Link>}>
          <div className="flex h-[150px] items-end gap-2.5 pt-2">
            {points.map((p) => (
              <div key={p.day} className="flex h-full flex-1 flex-col items-center justify-end gap-1.5">
                <div className="w-full rounded-t-md rounded-b-sm bg-primary" style={{ height: `${Math.max(2, (p.sales / maxDay) * 100)}%` }} title={money(p.sales)} />
                <span className="text-[11px] uppercase text-muted-foreground">{date(`${p.day}T12:00:00`, "weekday")}</span>
              </div>
            ))}
          </div>
          <div className="flex justify-between text-[13px] text-muted-foreground">
            <span>Total <strong className="text-foreground">{money(weekNow)}</strong></span>
            {weekBefore > 0 && <span className={weekNow >= weekBefore ? "text-positive" : "text-warning"}>{change((weekNow - weekBefore) / weekBefore)} vs semana anterior</span>}
          </div>
        </Card>
      </section>

      <section className="grid gap-4 lg:grid-cols-2">
        <Card title="Tarefas de hoje" action={<Link href="/projetos/" className="text-[13px]">Projetos</Link>}>
          {tasks.length === 0 ? <Empty title="Nada para hoje" /> : tasks.slice(0, 6).map((t) => (
            <label key={t.id} className="flex min-h-9 cursor-pointer items-center gap-3">
              <Checkbox checked={false} onCheckedChange={() => void mutate.update("tasks", t.id, statusPatch("done"))} aria-label={`Concluir ${t.title}`} />
              <span className={cn("min-w-0 flex-1 truncate", isOverdue(t) && "text-warning")}>{t.title}</span>
              <span className="rounded-md bg-surface px-2 py-0.5 text-xs text-muted-foreground">{t.project_id ? projectName.get(t.project_id) ?? "Projeto" : "Avulsa"}</span>
            </label>
          ))}
          {tasks.length > 6 && <Link href="/projetos/" className="text-[13px]">+ {tasks.length - 6} tarefas em Projetos</Link>}
        </Card>
        <Card title="Metas e projetos">
          {goals.map(({ g, p }) => (
            <Link key={g.id} href={`/metas/?id=${g.id}`} className="flex flex-col gap-1.5 text-foreground no-underline">
              <div className="flex justify-between text-[13px]"><span className="font-medium">{g.title}</span><span className="text-muted-foreground">{money(p.current, g.currency_code)} de {money(p.target, g.currency_code)}</span></div>
              <Bar value={p.fraction} color={colorHex(g.color_name)} />
            </Link>
          ))}
          {projects.map(({ p, done, total }) => (
            <Link key={p.id} href={`/projetos/?projeto=${p.id}`} className="flex flex-col gap-1.5 text-foreground no-underline">
              <div className="flex justify-between text-[13px]"><span className="font-medium">{p.name}</span><span className="text-muted-foreground">{done} de {total}</span></div>
              <Bar value={done / total} color={colorHex(p.color_name)} />
            </Link>
          ))}
          {goals.length + projects.length === 0 && <Empty title="Sem metas nem projetos ativos" />}
        </Card>
      </section>

      <section className="grid gap-4 xl:grid-cols-3">
        <Card title="Hábitos" action={<Link href="/habitos/" className="text-[13px]">Todos</Link>}>
          {habits.length === 0 ? <Empty title="Sem hábitos" /> : habits.map((h) => {
            const p = habitProgress(h, data.habit_checks);
            return (
              <label key={h.id} className="flex cursor-pointer items-center gap-3">
                <Checkbox checked={p.isDoneToday} onCheckedChange={() => void toggleHabit(h.id)} aria-label={`Marcar ${h.name} hoje`} />
                <SymbolIcon name={h.symbol_name} color={h.color_name} size={24} />
                <span className="flex-1">{h.name}</span>
                <span className="text-xs text-muted-foreground">{p.streak > 0 ? `🔥 ${p.streak}` : ""} {p.thisWeek}/{p.target}</span>
              </label>
            );
          })}
        </Card>
        <Card title="A vencer">
          {agenda.length === 0 ? <Empty title="Sem prazos à vista" /> : agenda.slice(0, 6).map((a) => (
            <Link key={a.id} href={a.href} className="flex justify-between gap-3 text-[13px] text-foreground no-underline">
              <span className="flex min-w-0 flex-col"><span className="truncate font-medium">{a.title}</span><span className="truncate text-xs text-muted-foreground">{a.detail}</span></span>
              <span className={cn("shrink-0 text-xs", daysUntil(a.date) <= 7 ? "text-warning" : "text-muted-foreground")}>{describeAgenda(a)}</span>
            </Link>
          ))}
        </Card>
        <CalendarCard />
      </section>

      <TransactionForm open={expenseOpen} onOpenChange={setExpenseOpen} initialKind="expense" />
      <WeeklyReview open={reviewOpen} onOpenChange={setReviewOpen} />
    </div>
  );
}
