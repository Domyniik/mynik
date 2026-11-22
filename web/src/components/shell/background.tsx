"use client";

import { useEffect } from "react";
import { useStoreSync } from "@/components/store/store-page";
import { lifeAgenda, upcomingAgenda } from "@/lib/calc/life";
import { useRpc, useTables } from "@/lib/db/store";
import { setTraySales } from "@/lib/desktop";
import { daysUntil, money, TIME_ZONE } from "@/lib/format";
import { notify } from "@/lib/notify";
import { useSettings } from "@/lib/settings";

const SYNC_EVERY = 15 * 60_000;
const SENT_KEY = "mynik.remindersSent";

/** Cada aviso só uma vez por dia (o iPhone agenda; aqui verifica-se com a app aberta). */
function once(key: string, send: () => void) {
  const today = new Date().toLocaleDateString("sv-SE", { timeZone: TIME_ZONE });
  let sent: Record<string, string> = {};
  try {
    sent = JSON.parse(localStorage.getItem(SENT_KEY) ?? "{}");
  } catch { /* começa vazio */ }
  if (sent[key] === today) return;
  send();
  sent[key] = today;
  for (const [k, day] of Object.entries(sent)) if (day !== today) delete sent[k];
  try {
    localStorage.setItem(SENT_KEY, JSON.stringify(sent));
  } catch { /* sem armazenamento */ }
}

/**
 * Trabalho em segundo plano enquanto o Mynik está aberto (também escondido no
 * tray): sincroniza a loja de 15 em 15 min e avisa de vendas, contas a pagar,
 * prazos, dias sem venda e da revisão semanal; mantém as vendas de hoje no tray.
 */
export function Background() {
  const store = useStoreSync();
  const { settings } = useSettings();
  const { data } = useTables("bills", "vehicles", "car_deadlines", "maintenance_records", "fuel_entries", "documents", "job_applications", "courses", "store_orders");
  const { data: kpis } = useRpc<{ period: string; gross_sales: number; orders: number }>("store_kpis", { p_days: 1, p_tz: TIME_ZONE }, ["store_orders"]);

  const { sync, demo } = store;
  useEffect(() => {
    if (demo) return;
    const timer = window.setInterval(() => void sync(), SYNC_EVERY);
    return () => window.clearInterval(timer);
  }, [sync, demo]);

  const today = kpis.find((k) => k.period === "current");
  useEffect(() => {
    if (!today) return;
    const orders = today.orders === 1 ? "1 pedido" : `${today.orders} pedidos`;
    void setTraySales(`Vendas hoje: ${money(today.gross_sales)} · ${orders}`, today.gross_sales > 0 ? money(today.gross_sales) : "");
  }, [today]);

  useEffect(() => {
    if (settings.billRemindersEnabled) {
      const soon = data.bills.filter((b) => !b.is_paid && daysUntil(b.due_date) <= settings.billReminderDaysBefore);
      for (const b of soon) {
        const days = daysUntil(b.due_date);
        const when = days < 0 ? `atrasada ${-days} ${-days === 1 ? "dia" : "dias"}` : days === 0 ? "vence hoje" : days === 1 ? "vence amanhã" : `vence em ${days} dias`;
        once(`bill:${b.id}`, () => notify(`Conta a pagar: ${b.title}`, `${money(b.amount, b.currency_code)} · ${when}`));
      }
    }
    if (settings.agendaRemindersEnabled) {
      const items = upcomingAgenda(lifeAgenda({
        vehicles: data.vehicles, deadlines: data.car_deadlines, maintenance: data.maintenance_records, fuel: data.fuel_entries,
        documents: data.documents, applications: data.job_applications, courses: data.courses,
      })).filter((i) => daysUntil(i.date) <= 7);
      for (const i of items) once(`agenda:${i.id}`, () => notify(i.title, i.detail));
    }
    const now = new Date();
    if (settings.weeklyReviewReminder && now.getDay() === 0 && now.getHours() >= 19) {
      once("weekly-review", () => notify("Revisão semanal", "Vê como correu a semana: gastos, tarefas, metas e a loja."));
    }
    if (!demo && settings.storeNoSaleDays > 0 && data.store_orders.length > 0) {
      const last = data.store_orders.reduce((max, o) => (o.created_at > max ? o.created_at : max), "");
      const days = -daysUntil(last);
      if (days >= settings.storeNoSaleDays) once("no-sale", () => notify("Loja sem vendas", `Há ${days} dias sem nenhuma venda na Neloce.`));
    }
  }, [data, settings, demo]);

  return null;
}
