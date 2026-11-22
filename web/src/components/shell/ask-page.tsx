"use client";

import { Send, Sparkles } from "lucide-react";
import { type FormEvent, useEffect, useRef, useState } from "react";
import { Card, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { accountBalance, toEur } from "@/lib/calc/finance";
import { careerStats, describeAgenda, describeExpiry, documentKinds, fuelEconomy, goalProgress, lifeAgenda, upcomingAgenda } from "@/lib/calc/life";
import { searchKey } from "@/lib/calc/search";
import { getDb, useTables } from "@/lib/db/store";
import { due, money, percent, TIME_ZONE, toDateInput } from "@/lib/format";
import { useSettings } from "@/lib/settings";

const suggestions = ["Quanto gastei este mês?", "Quanto gastei em alimentação?", "Que contas tenho para pagar?", "Como está a loja esta semana?", "Como está o meu património?", "O que vence em breve?"];

type Data = ReturnType<typeof useTables<["transactions", "categories", "bills", "accounts", "goals", "vehicles", "fuel_entries", "maintenance_records", "car_deadlines", "documents", "job_applications", "courses", "investments"]>>["data"];

/** Para onde vai a pergunta (QuestionRouter do iPhone, por palavras). */
function route(question: string) {
  const q = searchKey(question);
  const monthsAgo = /mes passado|ultimo mes|mes anterior/.test(q) ? 1 : 0;
  if (/loja|venda|pedido|neloce|shopify|encomenda/.test(q)) return { kind: "store" as const, days: /hoje/.test(q) ? 1 : /mes|30/.test(q) ? 30 : 7 };
  if (/conta[s]? (a|para|por) pagar|vencer|faturas?|pagar/.test(q)) return { kind: "bills" as const };
  if (/carro|combustivel|gasolina|itv|seguro do carro/.test(q)) return { kind: "car" as const };
  if (/documento|passaporte|cartao de cidadao|tie|validade/.test(q)) return { kind: "documents" as const };
  if (/candidatura|emprego|entrevista|carreira|curso/.test(q)) return { kind: "career" as const };
  if (/meta|objetivo|poupar para/.test(q)) return { kind: "goals" as const };
  if (/patrimonio|investimento|investido|acoes|etf|cripto/.test(q)) return { kind: "wealth" as const };
  if (/vence|prazo|agenda|em breve/.test(q)) return { kind: "agenda" as const };
  const target = question.trim().match(/(?:em|no|na|com) ([\p{L}\d ]{3,30})\??$/iu)?.[1]?.trim().toLowerCase();
  if (target && /gast|quanto/.test(q) && !/este m[eê]s|m[eê]s passado/.test(target)) return { kind: "spending" as const, query: target, monthsAgo };
  return { kind: "finances" as const, monthsAgo };
}

async function answer(question: string, d: Data, rate: number): Promise<string> {
  const r = route(question);
  const db = getDb();
  const today = new Date();
  const monthDate = (ago: number) => new Date(today.getFullYear(), today.getMonth() - ago, 1);
  const monthName = (ago: number) => new Intl.DateTimeFormat("pt-PT", { month: "long" }).format(monthDate(ago));
  switch (r.kind) {
    case "finances": {
      const [s] = await db.rpc<{ income: number; expenses: number; balance: number }>("month_summary", { p_month: toDateInput(monthDate(r.monthsAgo)), p_tz: TIME_ZONE });
      const names = new Map(d.categories.map((c) => [c.id, c.name]));
      const by = new Map<string, number>();
      for (const t of d.transactions) {
        const td = new Date(t.date);
        if (t.kind !== "expense" || td.getMonth() !== monthDate(r.monthsAgo).getMonth() || td.getFullYear() !== monthDate(r.monthsAgo).getFullYear()) continue;
        const n = names.get(t.category_id ?? "") ?? "Sem categoria";
        by.set(n, (by.get(n) ?? 0) + toEur(t.amount, t.currency_code, rate));
      }
      const top = [...by.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3).map(([n, v]) => `${n} ${money(v)}`).join(", ");
      return `Em ${monthName(r.monthsAgo)}: receitas ${money(s?.income ?? 0)}, gastos ${money(s?.expenses ?? 0)}, saldo ${money(s?.balance ?? 0)}.${top ? ` Onde mais gastaste: ${top}.` : ""}`;
    }
    case "spending": {
      const key = searchKey(r.query);
      const m = monthDate(r.monthsAgo);
      const matches = d.transactions.filter((t) => {
        const td = new Date(t.date);
        const cat = d.categories.find((c) => c.id === t.category_id)?.name ?? "";
        return t.kind === "expense" && td.getMonth() === m.getMonth() && td.getFullYear() === m.getFullYear() && (searchKey(cat).includes(key) || searchKey(t.title).includes(key));
      });
      const total = matches.reduce((s, t) => s + toEur(t.amount, t.currency_code, rate), 0);
      return matches.length ? `Em ${monthName(r.monthsAgo)} gastaste ${money(total)} em "${r.query}" (${matches.length} movimentos).` : `Não encontrei gastos em "${r.query}" em ${monthName(r.monthsAgo)}.`;
    }
    case "bills": {
      const list = d.bills.filter((b) => !b.is_paid && (new Date(b.due_date).getTime() - Date.now()) / 86_400_000 <= 30).sort((a, b) => a.due_date.localeCompare(b.due_date));
      if (!list.length) return "Não tens contas a pagar nos próximos 30 dias.";
      return `Nos próximos 30 dias: ${list.map((b) => `${b.title} ${money(b.amount, b.currency_code)} (${due(b.due_date).toLowerCase()})`).join("; ")}. Total ${money(list.reduce((s, b) => s + toEur(b.amount, b.currency_code, rate), 0))}.`;
    }
    case "store": {
      const rows = await db.rpc<{ period: string; gross_sales: number; orders: number; profit: number }>("store_kpis", { p_days: r.days, p_tz: TIME_ZONE });
      const c = rows.find((x) => x.period === "current");
      const p = rows.find((x) => x.period === "previous");
      const label = r.days === 1 ? "Hoje" : `Nos últimos ${r.days} dias`;
      const delta = p && p.gross_sales ? ` (${percent((c!.gross_sales - p.gross_sales) / p.gross_sales)} face ao período anterior)` : "";
      return `${label}: vendas ${money(c?.gross_sales ?? 0)} em ${c?.orders ?? 0} pedidos${delta}; lucro real ${money(c?.profit ?? 0)}.`;
    }
    case "car": {
      const v = d.vehicles[0];
      if (!v) return "Ainda não tens nenhum carro registado.";
      const e = fuelEconomy(d.fuel_entries.filter((f) => f.vehicle_id === v.id));
      const next = d.car_deadlines.filter((x) => x.vehicle_id === v.id).sort((a, b) => a.due_date.localeCompare(b.due_date))[0];
      return `${v.name || "Carro"}: consumo médio ${e.average != null ? `${e.average.toFixed(1)} L/100 km` : "por calcular"}${e.costPerKm != null ? `, ${money(e.costPerKm)}/km` : ""}.${next ? ` Próximo prazo: ${next.title || next.kind} — ${due(next.due_date).toLowerCase()}.` : ""}`;
    }
    case "documents":
      return d.documents.length ? d.documents.map((x) => `${x.title || documentKinds[x.kind]}: ${describeExpiry(x.expiry_date).toLowerCase()}`).join("; ") + "." : "Não tens documentos registados.";
    case "career": {
      const s = careerStats(d.job_applications);
      return `${s.total} candidaturas: ${s.active} ativas, ${s.interviews} em entrevistas, ${s.offers} propostas. Taxa de resposta ${percent(s.responseRate)}.`;
    }
    case "goals": {
      const list = d.goals.filter((g) => !g.is_archived).map((g) => ({ g, p: goalProgress(g, { accounts: d.accounts, transactions: d.transactions, categories: d.categories, rate }) }));
      return list.length ? list.map(({ g, p }) => `${g.title}: ${money(p.current, g.currency_code)} de ${money(p.target, g.currency_code)} (${percent(p.fraction)})${p.monthlyNeeded ? `, juntar ${money(p.monthlyNeeded, g.currency_code)}/mês` : ""}`).join("; ") + "." : "Não tens metas ativas.";
    }
    case "wealth": {
      const cash = d.accounts.filter((a) => !a.is_archived).reduce((s, a) => s + toEur(accountBalance(a, d.transactions), a.currency_code, rate), 0);
      const inv = d.investments.filter((i) => !i.is_archived);
      const value = inv.reduce((s, i) => s + toEur(i.ticker && i.unit_price > 0 ? i.units * i.unit_price : i.manual_value, i.currency_code, rate), 0);
      const invested = inv.reduce((s, i) => s + toEur(i.invested_amount, i.currency_code, rate), 0);
      return `Património líquido ${money(cash + value)}: ${money(cash)} nas contas e ${money(value)} em investimentos (investido ${money(invested)}, ganho ${money(value - invested, "EUR", { signed: true })}).`;
    }
    case "agenda": {
      const items = upcomingAgenda(lifeAgenda({ vehicles: d.vehicles, deadlines: d.car_deadlines, maintenance: d.maintenance_records, fuel: d.fuel_entries, documents: d.documents, applications: d.job_applications, courses: d.courses }));
      return items.length ? items.slice(0, 6).map((i) => `${i.title}: ${describeAgenda(i).toLowerCase()}`).join("; ") + "." : "Nada a vencer em breve.";
    }
  }
}

/** IA local opcional: o Ollama neste computador (grátis); sem ele, os resumos. */
async function ollama(question: string, context: string): Promise<string | null> {
  try {
    const tags = await fetch("http://localhost:11434/api/tags", { signal: AbortSignal.timeout(800) }).then((r) => r.json());
    const model = tags.models?.[0]?.name;
    if (!model) return null;
    const res = await fetch("http://localhost:11434/api/generate", {
      method: "POST",
      body: JSON.stringify({ model, stream: false, prompt: `Responde em português de Portugal, curto, só com base nestes dados do utilizador:\n${context}\n\nPergunta: ${question}` }),
    }).then((r) => r.json());
    return res.response ?? null;
  } catch {
    return null;
  }
}

export default function AskPage() {
  const { data } = useTables("transactions", "categories", "bills", "accounts", "goals", "vehicles", "fuel_entries", "maintenance_records", "car_deadlines", "documents", "job_applications", "courses", "investments");
  const { settings } = useSettings();
  const [messages, setMessages] = useState<{ role: "user" | "assistant"; text: string }[]>([]);
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [local, setLocal] = useState(false);
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => { end.current?.scrollIntoView({ behavior: "smooth" }); }, [messages]);

  const ask = async (question: string) => {
    if (!question.trim()) return;
    setMessages((m) => [...m, { role: "user", text: question }]);
    setText("");
    setBusy(true);
    try {
      const summary = await answer(question, data as Data, settings.brlPerEUR);
      const ai = await ollama(question, summary);
      setLocal(ai != null);
      setMessages((m) => [...m, { role: "assistant", text: ai ?? summary }]);
    } catch (e) {
      setMessages((m) => [...m, { role: "assistant", text: `Não consegui responder: ${e instanceof Error ? e.message : e}` }]);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Pergunte ao Mynik" subtitle={local ? "IA local (Ollama) com os teus dados · nada sai deste computador" : "Resumos dos teus dados, sem enviar nada para fora"}
        actions={messages.length > 0 && <Button variant="outline" onClick={() => setMessages([])}>Nova conversa</Button>} />
      <Card>
        <div className="flex min-h-80 flex-col gap-3">
          {messages.length === 0 && (
            <div className="flex flex-col gap-3">
              <p className="m-0 flex items-center gap-2 text-muted-foreground"><Sparkles size={16} aria-hidden="true" /> Experimenta perguntar</p>
              <div className="flex flex-wrap gap-2">{suggestions.map((s) => <Button key={s} variant="outline" size="sm" onClick={() => void ask(s)}>{s}</Button>)}</div>
            </div>
          )}
          {messages.map((m, i) => (
            <div key={i} className={m.role === "user" ? "self-end rounded-2xl bg-primary px-4 py-2 text-white" : "max-w-[80%] self-start rounded-2xl bg-surface px-4 py-2"}>{m.text}</div>
          ))}
          {busy && <div className="self-start text-sm text-muted-foreground" role="status">A pensar…</div>}
          <div ref={end} />
        </div>
        <form onSubmit={(e: FormEvent) => { e.preventDefault(); void ask(text); }} className="flex gap-2">
          <Input value={text} onChange={(e) => setText(e.target.value)} placeholder="Pergunta sobre os teus dados…" aria-label="Pergunta" />
          <Button type="submit" disabled={busy || !text.trim()} aria-label="Enviar"><Send aria-hidden="true" /></Button>
        </form>
      </Card>
    </div>
  );
}
