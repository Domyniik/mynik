import type {
  AccountRow, BillRow, CarDeadlineRow, CategoryRow, CourseRow, DocumentRow, FuelEntryRow, GoalRow, HabitCheckRow, HabitRow,
  JobApplicationRow, MaintenanceRow, StoreOrderRow, TaskRow, TransactionRow, VehicleRow,
} from "../db/schema";
import { daysUntil, startOfDay } from "../format";
import { accountBalance, convert, toEur, UNCATEGORIZED } from "./finance";

// ---------- Tarefas (TaskBoard) ----------
export const taskStatus = { todo: "Por fazer", doing: "Em curso", done: "Feito" } as const;
export const taskPriority = ["Baixa", "Normal", "Alta"] as const;

/** Prioridade alta primeiro, depois o prazo mais próximo (sem prazo no fim), depois as mais antigas. */
export function sortTasks(tasks: TaskRow[]) {
  return [...tasks].sort((a, b) => {
    if (a.priority !== b.priority) return b.priority - a.priority;
    if (a.due_date && b.due_date && a.due_date !== b.due_date) return a.due_date.localeCompare(b.due_date);
    if (a.due_date && !b.due_date) return -1;
    if (!a.due_date && b.due_date) return 1;
    return a.created_at.localeCompare(b.created_at);
  });
}

export function taskColumns(tasks: TaskRow[]) {
  return {
    todo: sortTasks(tasks.filter((t) => t.status === "todo")),
    doing: sortTasks(tasks.filter((t) => t.status === "doing")),
    done: tasks.filter((t) => t.status === "done").sort((a, b) => (b.completed_at ?? "").localeCompare(a.completed_at ?? "")),
  };
}

/** Para o Hoje: em curso, ou por fazer com prazo até ao fim de hoje. */
export function tasksForToday(tasks: TaskRow[], now = new Date()) {
  const end = startOfDay(now);
  end.setDate(end.getDate() + 1);
  return sortTasks(tasks.filter((t) => t.status !== "done" && (t.status === "doing" || (t.due_date != null && new Date(t.due_date) < end))));
}

export const isOverdue = (t: TaskRow, now = new Date()) => t.status !== "done" && t.due_date != null && new Date(t.due_date) < startOfDay(now);

/** Mudança de estado com a data de conclusão (como `ProjectTask.status`). */
export const statusPatch = (status: string) => ({ status, completed_at: status === "done" ? new Date().toISOString() : null });

// ---------- Metas (GoalProgress) ----------
export const goalSources = {
  manual: { title: "Valor manual", explanation: "Registas tu cada valor que juntas." },
  account: { title: "Saldo de uma conta", explanation: "O progresso é o saldo atual da conta escolhida." },
  category: { title: "Movimentos de uma categoria", explanation: "Soma os movimentos da categoria desde o início da meta. Cada contribuição cria um movimento nas Finanças." },
} as const;

export function goalContributions(goal: GoalRow, transactions: TransactionRow[], categories: CategoryRow[]) {
  if (goal.source !== "category" || !goal.category_id) return [];
  const category = categories.find((c) => c.id === goal.category_id);
  if (!category) return [];
  const start = startOfDay(goal.start_date);
  return transactions
    .filter((t) => t.category_id === category.id && t.kind === category.kind && new Date(t.date) >= start)
    .sort((a, b) => b.date.localeCompare(a.date));
}

export function goalProgress(goal: GoalRow, ctx: { accounts: AccountRow[]; transactions: TransactionRow[]; categories: CategoryRow[]; rate: number }, now = new Date()) {
  let current = 0;
  if (goal.source === "manual") current = goal.manual_amount;
  else if (goal.source === "account") {
    const account = ctx.accounts.find((a) => a.id === goal.account_id);
    current = account ? convert(accountBalance(account, ctx.transactions), account.currency_code, goal.currency_code, ctx.rate) : 0;
  } else {
    current = goalContributions(goal, ctx.transactions, ctx.categories).reduce((s, t) => s + convert(t.amount, t.currency_code, goal.currency_code, ctx.rate), 0);
  }
  const target = goal.target_amount;
  let monthsLeft: number | null = null;
  let isPastDeadline = false;
  if (goal.deadline) {
    const today = startOfDay(now);
    const end = startOfDay(goal.deadline);
    if (end < today) isPastDeadline = true;
    else {
      // Meses inteiros e depois os dias que sobram (dateComponents([.month, .day]) no iPhone).
      let months = (end.getFullYear() - today.getFullYear()) * 12 + end.getMonth() - today.getMonth();
      const plus = (m: number) => new Date(today.getFullYear(), today.getMonth() + m, today.getDate());
      if (plus(months) > end) months -= 1;
      const days = daysUntil(end, plus(months));
      monthsLeft = Math.max(1, months + (days > 0 ? 1 : 0));
    }
  }
  const remaining = Math.max(0, target - current);
  const isReached = target > 0 && current >= target;
  return {
    current, target, remaining, isReached, isPastDeadline, monthsLeft,
    fraction: target > 0 ? Math.min(1, Math.max(0, current / target)) : 0,
    monthlyNeeded: monthsLeft != null && !isReached ? Math.round((remaining / monthsLeft) * 100) / 100 : null,
  };
}

// ---------- Hábitos (HabitProgress, semana a começar à segunda) ----------
const dayKey = (d: Date) => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;

export function habitProgress(habit: HabitRow, checks: HabitCheckRow[], now = new Date()) {
  const done = new Set(checks.filter((c) => c.habit_id === habit.id).map((c) => dayKey(new Date(c.day))));
  const today = startOfDay(now);
  const day = (offset: number) => {
    const d = new Date(today);
    d.setDate(d.getDate() + offset);
    return d;
  };
  const isDoneToday = done.has(dayKey(today));
  let streak = 0;
  for (let cursor = isDoneToday ? 0 : -1; done.has(dayKey(day(cursor))); cursor -= 1) streak += 1;
  const weekStart = day(-((today.getDay() + 6) % 7));
  let thisWeek = 0;
  for (let d = new Date(weekStart); d <= today; d.setDate(d.getDate() + 1)) if (done.has(dayKey(d))) thisWeek += 1;
  return {
    streak, thisWeek, isDoneToday, target: habit.target_per_week,
    lastSevenDays: [-6, -5, -4, -3, -2, -1, 0].map((o) => done.has(dayKey(day(o)))),
    isWeekGoalReached: thisWeek >= habit.target_per_week,
  };
}

export const checkFor = (habit: HabitRow, checks: HabitCheckRow[], date = new Date()) =>
  checks.find((c) => c.habit_id === habit.id && dayKey(new Date(c.day)) === dayKey(date));

// ---------- Carro ----------
export const fuelTypes: Record<string, { title: string; unit: string }> = {
  gasoline95: { title: "Gasolina 95", unit: "L" }, gasoline98: { title: "Gasolina 98", unit: "L" }, diesel: { title: "Gasóleo", unit: "L" },
  dieselPremium: { title: "Gasóleo Premium", unit: "L" }, lpg: { title: "GPL (autogás)", unit: "L" }, electric: { title: "Elétrico", unit: "kWh" },
};
export const maintenanceKinds: Record<string, string> = { service: "Revisão", oil: "Mudança de óleo", tyres: "Pneus", brakes: "Travões", battery: "Bateria", repair: "Reparação", other: "Outra" };
export const deadlineKinds: Record<string, string> = { inspection: "ITV (inspeção)", insurance: "Seguro", tax: "Imposto de circulação", other: "Outro" };

/** Consumo pelo método do depósito cheio (FuelEconomy). */
export function fuelEconomy(entries: FuelEntryRow[]) {
  const fills = [...entries].sort((a, b) => a.odometer - b.odometer || a.date.localeCompare(b.date));
  const segments: { endDate: string; distance: number; quantity: number; cost: number; per100km: number }[] = [];
  let start: FuelEntryRow | null = null;
  let quantity = 0;
  let cost = 0;
  for (const fill of fills) {
    if (!start) {
      if (fill.is_full_tank) start = fill;
      continue;
    }
    quantity += fill.quantity;
    cost += fill.total_cost;
    if (!fill.is_full_tank) continue;
    const distance = fill.odometer - start.odometer;
    if (distance > 0) segments.push({ endDate: fill.date, distance, quantity, cost, per100km: (quantity / distance) * 100 });
    start = fill;
    quantity = 0;
    cost = 0;
  }
  const totalDistance = segments.reduce((s, x) => s + x.distance, 0);
  return {
    segments,
    average: totalDistance > 0 ? (segments.reduce((s, x) => s + x.quantity, 0) / totalDistance) * 100 : null,
    last: segments.at(-1)?.per100km ?? null,
    costPerKm: totalDistance > 0 ? segments.reduce((s, x) => s + x.cost, 0) / totalDistance : null,
  };
}

export function currentOdometer(vehicle: VehicleRow, fuel: FuelEntryRow[], maintenance: MaintenanceRow[]) {
  return Math.max(vehicle.initial_odometer, ...fuel.filter((f) => f.vehicle_id === vehicle.id).map((f) => f.odometer), ...maintenance.filter((m) => m.vehicle_id === vehicle.id).map((m) => m.odometer));
}

// ---------- Documentos ----------
export const documentKinds: Record<string, string> = {
  idCard: "Cartão de cidadão / RG", passport: "Passaporte", residence: "Residência (TIE / NIE)", drivingLicense: "Carta de condução",
  healthCard: "Cartão de saúde", insurance: "Seguro", other: "Outro",
};
export type DocumentStatus = "expired" | "expiringSoon" | "valid" | "noExpiry";
export const documentStatusTitle: Record<DocumentStatus, string> = { expired: "Expirados", expiringSoon: "A expirar", valid: "Válidos", noExpiry: "Sem validade" };
export function documentStatus(expiry: string | null, remindDaysBefore: number, now = new Date()): DocumentStatus {
  if (!expiry) return "noExpiry";
  const days = daysUntil(expiry, now);
  if (days < 0) return "expired";
  return days <= remindDaysBefore ? "expiringSoon" : "valid";
}
export function describeExpiry(expiry: string | null, now = new Date()) {
  if (!expiry) return "Sem validade";
  const days = daysUntil(expiry, now);
  if (days < -1) return `Expirou há ${-days} dias`;
  if (days === -1) return "Expirou ontem";
  if (days === 0) return "Expira hoje";
  if (days === 1) return "Expira amanhã";
  if (days <= 90) return `Expira em ${days} dias`;
  return `Válido até ${new Intl.DateTimeFormat("pt-PT", { day: "numeric", month: "short", year: "numeric" }).format(new Date(expiry))}`;
}
export const maskNumber = (n: string) => (n.trim().length > 3 ? `•••• ${n.trim().slice(-3)}` : n.trim() ? "••••" : "");

// ---------- Carreira ----------
export const applicationStatus: Record<string, string> = { applied: "Enviada", interviewing: "Entrevistas", offer: "Proposta", accepted: "Aceite", rejected: "Recusada", noResponse: "Sem resposta" };
export const isActiveApplication = (s: string) => s === "applied" || s === "interviewing" || s === "offer";
export function careerStats(applications: JobApplicationRow[]) {
  const total = applications.length;
  const responded = applications.filter((a) => a.status !== "applied" && a.status !== "noResponse").length;
  return {
    total, responded,
    active: applications.filter((a) => isActiveApplication(a.status)).length,
    interviews: applications.filter((a) => a.status === "interviewing").length,
    offers: applications.filter((a) => a.status === "offer" || a.status === "accepted").length,
    responseRate: total > 0 ? responded / total : null,
  };
}
export const courseStatus: Record<string, string> = { planned: "Por começar", inProgress: "Em curso", completed: "Concluídos" };

// ---------- Agenda da vida (LifeAgenda) ----------
export interface AgendaItem {
  id: string;
  title: string;
  detail: string;
  date: string;
  source: "car" | "document" | "career";
  dueWord: string;
  horizonDays: number;
  remindDaysBefore: number[];
  href: string;
}

export function describeAgenda(item: AgendaItem, now = new Date()) {
  const days = daysUntil(item.date, now);
  if (days < -1) return `Atrasado ${-days} dias`;
  if (days === -1) return "Atrasado 1 dia";
  if (days === 0) return `${item.dueWord} hoje`;
  if (days === 1) return `${item.dueWord} amanhã`;
  return `${item.dueWord} em ${days} dias`;
}

export function lifeAgenda(d: {
  vehicles: VehicleRow[]; deadlines: CarDeadlineRow[]; maintenance: MaintenanceRow[]; fuel: FuelEntryRow[];
  documents: DocumentRow[]; applications: JobApplicationRow[]; courses: CourseRow[];
}, now = new Date()): AgendaItem[] {
  const items: AgendaItem[] = [];
  for (const v of d.vehicles) {
    const name = v.name.trim() || "Carro";
    for (const dl of d.deadlines.filter((x) => x.vehicle_id === v.id)) {
      items.push({ id: `car-deadline-${dl.id}`, title: dl.title.trim() || deadlineKinds[dl.kind] || "Prazo", detail: name, date: dl.due_date, source: "car", dueWord: "Vence", horizonDays: 30, remindDaysBefore: [30, 7, 0], href: `/carro/?veiculo=${v.id}` });
    }
    const latest = new Map<string, MaintenanceRow>();
    for (const m of d.maintenance.filter((x) => x.vehicle_id === v.id)) {
      const known = latest.get(m.kind);
      if (!known || known.date < m.date) latest.set(m.kind, m);
    }
    const odometer = currentOdometer(v, d.fuel, d.maintenance);
    for (const m of latest.values()) {
      const title = m.title.trim() || maintenanceKinds[m.kind] || "Manutenção";
      if (m.next_due_date) {
        items.push({ id: `car-maintenance-${m.id}`, title, detail: name, date: m.next_due_date, source: "car", dueWord: "Próxima", horizonDays: 14, remindDaysBefore: [7, 0], href: `/carro/?veiculo=${v.id}` });
      } else if (m.next_due_odometer > 0 && m.next_due_odometer - odometer <= 1000) {
        const remaining = m.next_due_odometer - odometer;
        const km = new Intl.NumberFormat("pt-PT").format(Math.abs(remaining));
        items.push({ id: `car-maintenance-${m.id}`, title, detail: remaining > 0 ? `${name} · faltam ${km} km` : `${name} · passou ${km} km`, date: now.toISOString(), source: "car", dueWord: "Próxima", horizonDays: 30, remindDaysBefore: [], href: `/carro/?veiculo=${v.id}` });
      }
    }
  }
  for (const doc of d.documents) {
    if (!doc.expiry_date) continue;
    items.push({ id: `document-${doc.id}`, title: doc.title.trim() || documentKinds[doc.kind] || "Documento", detail: documentKinds[doc.kind] ?? "", date: doc.expiry_date, source: "document", dueWord: "Expira", horizonDays: doc.remind_days_before, remindDaysBefore: [doc.remind_days_before, 7, 0], href: `/documentos/?id=${doc.id}` });
  }
  for (const a of d.applications) {
    if (!isActiveApplication(a.status) || !a.follow_up_date) continue;
    items.push({ id: `career-followup-${a.id}`, title: `Follow-up: ${a.company}`, detail: a.role, date: a.follow_up_date, source: "career", dueWord: "Contactar", horizonDays: 2, remindDaysBefore: [0], href: "/carreira/" });
  }
  for (const c of d.courses) {
    if (!c.expires_at) continue;
    items.push({ id: `career-certificate-${c.id}`, title: c.title, detail: c.provider ? `Certificado · ${c.provider}` : "Certificado", date: c.expires_at, source: "career", dueWord: "Expira", horizonDays: 60, remindDaysBefore: [60, 7, 0], href: "/carreira/?tab=cursos" });
  }
  return items;
}

export const upcomingAgenda = (items: AgendaItem[], now = new Date()) =>
  items.filter((i) => daysUntil(i.date, now) <= i.horizonDays).sort((a, b) => a.date.localeCompare(b.date));

// ---------- Revisão semanal (WeeklyReview, segunda a domingo) ----------
export function weeklyReview(d: {
  transactions: TransactionRow[]; categories: CategoryRow[]; bills: BillRow[]; tasks: TaskRow[];
  habits: HabitRow[]; checks: HabitCheckRow[]; orders: StoreOrderRow[]; rate: number;
}, now = new Date()) {
  const today = startOfDay(now);
  const start = new Date(today);
  start.setDate(start.getDate() - ((today.getDay() + 6) % 7));
  const end = new Date(start);
  end.setDate(end.getDate() + 7);
  const previousStart = new Date(start);
  previousStart.setDate(previousStart.getDate() - 7);
  const nextEnd = new Date(end);
  nextEnd.setDate(nextEnd.getDate() + 7);
  const inWeek = (iso: string) => {
    const x = new Date(iso);
    return x >= start && x < end;
  };
  const names = new Map(d.categories.map((c) => [c.id, c.name]));
  let expenses = 0;
  let previousExpenses = 0;
  let income = 0;
  const byCategory = new Map<string, number>();
  for (const t of d.transactions) {
    const amount = toEur(t.amount, t.currency_code, d.rate);
    const date = new Date(t.date);
    if (inWeek(t.date)) {
      if (t.kind === "expense") {
        expenses += amount;
        const name = names.get(t.category_id ?? "") ?? UNCATEGORIZED;
        byCategory.set(name, (byCategory.get(name) ?? 0) + amount);
      } else income += amount;
    } else if (t.kind === "expense" && date >= previousStart && date < start) previousExpenses += amount;
  }
  let billsPaid = 0;
  let billsNextWeek = 0;
  let billsNextWeekTotal = 0;
  for (const b of d.bills) {
    if (b.is_paid && b.paid_at && inWeek(b.paid_at)) billsPaid += 1;
    else if (!b.is_paid && new Date(b.due_date) >= end && new Date(b.due_date) < nextEnd) {
      billsNextWeek += 1;
      billsNextWeekTotal += toEur(b.amount, b.currency_code, d.rate);
    }
  }
  const habits = d.habits
    .filter((h) => !h.is_archived)
    .sort((a, b) => a.sort_order - b.sort_order)
    .map((h) => ({ name: h.name, done: d.checks.filter((c) => c.habit_id === h.id && inWeek(c.day)).length, target: h.target_per_week }));
  const orders = d.orders.filter((o) => !o.cancelled_at && inWeek(o.created_at));
  return {
    start, end, expenses, previousExpenses, income,
    expenseChange: previousExpenses > 0 ? (expenses - previousExpenses) / previousExpenses : null,
    topCategories: [...byCategory.entries()].map(([name, amount]) => ({ name, amount })).sort((a, b) => b.amount - a.amount || a.name.localeCompare(b.name)).slice(0, 3),
    billsPaid, billsNextWeek, billsNextWeekTotal,
    tasksCompleted: d.tasks.filter((t) => t.status === "done" && t.completed_at && inWeek(t.completed_at)).length,
    habits, habitsOnTrack: habits.filter((h) => h.done >= h.target).length,
    storeSales: orders.reduce((s, o) => s + o.total, 0), storeOrders: orders.length,
  };
}
