"use client";

import { Pencil, Plus, RefreshCw } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { Area, AreaChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { toast } from "sonner";
import { Field, FormDialog, MoneyInput, Select } from "@/components/common/fields";
import { Bar, Card, Empty, Kpi, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { accountBalance, monthSummary, toEur } from "@/lib/calc/finance";
import { newID, now } from "@/lib/db/client";
import type { InvestmentRow } from "@/lib/db/schema";
import { getDb, mutate, useTables } from "@/lib/db/store";
import { date, fromDateInput, money, percent, toDateInput } from "@/lib/format";
import { useSession } from "@/lib/session";
import { useSettings } from "@/lib/settings";
import { expenseCategory } from "./linked";

const kinds: Record<string, string> = { etf: "ETF", stock: "Ações", crypto: "Cripto", fund: "Fundo", deposit: "Depósito a prazo", pension: "Plano de pensões / PPR", other: "Outro" };
const usesQuotes = (i: InvestmentRow) => i.ticker.trim() !== "";
const currentValue = (i: InvestmentRow) => (usesQuotes(i) && i.unit_price > 0 ? i.units * i.unit_price : i.manual_value);
const QUOTE_MAX_AGE = 6 * 3_600_000;

type Quote = { quote: { price: number; name: string | null } | null };

function InvestmentForm({ investment, open, onOpenChange }: { investment: InvestmentRow | null; open: boolean; onOpenChange: (o: boolean) => void }) {
  const { status } = useSession();
  const [name, setName] = useState("");
  const [kind, setKind] = useState("etf");
  const [ticker, setTicker] = useState("");
  const [currency, setCurrency] = useState("EUR");
  const [units, setUnits] = useState<number | null>(0);
  const [invested, setInvested] = useState<number | null>(0);
  const [manual, setManual] = useState<number | null>(0);
  const [price, setPrice] = useState<number | null>(null);
  const [notes, setNotes] = useState("");
  const [archived, setArchived] = useState(false);
  useEffect(() => {
    if (!open) return;
    setName(investment?.name ?? "");
    setKind(investment?.kind ?? "etf");
    setTicker(investment?.ticker ?? "");
    setCurrency(investment?.currency_code ?? "EUR");
    setUnits(investment?.units ?? 0);
    setInvested(investment?.invested_amount ?? 0);
    setManual(investment?.manual_value ?? 0);
    setPrice(investment?.unit_price || null);
    setNotes(investment?.notes ?? "");
    setArchived(investment?.is_archived ?? false);
  }, [open, investment]);
  const verify = async () => {
    try {
      const { quote } = await getDb().invoke<Quote>("mynik-api", { action: "quote", symbol: ticker, currency });
      if (!quote) return toast.error(`Sem cotação para ${ticker}`);
      setPrice(quote.price);
      if (!name && quote.name) setName(quote.name);
      toast.success(`${ticker}: ${money(quote.price, currency)}`);
    } catch (e) {
      toast.error("Cotação indisponível", { description: String(e) });
    }
  };
  const save = async () => {
    const row = {
      name: name.trim(), kind, ticker: ticker.trim().toUpperCase(), currency_code: currency, units: units ?? 0,
      invested_amount: invested ?? 0, manual_value: manual ?? 0, notes, is_archived: archived,
      ...(price != null ? { unit_price: price, price_updated_at: now() } : {}),
    };
    if (investment) await mutate.update("investments", investment.id, row);
    else await mutate.insert("investments", { id: newID(), created_at: now(), ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={investment ? "Editar investimento" : "Novo investimento"} onSubmit={save} valid={name.trim().length > 0}
      onDelete={investment ? () => mutate.remove("investments", [investment.id]) : undefined} deleteWhat="este investimento">
      <Field label="Nome">{(id) => <Input id={id} autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex.: Vanguard All-World" />}</Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Tipo">{(id) => <Select id={id} value={kind} onChange={setKind}>{Object.entries(kinds).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
        <Field label="Moeda">{(id) => <Select id={id} value={currency} onChange={setCurrency}><option>EUR</option><option>BRL</option><option>USD</option></Select>}</Field>
      </div>
      <Field label="Ticker" hint={price != null ? `Cotação: ${money(price, currency)}` : "Ex.: VWCE.DE, BTC-EUR. Vazio = valor manual."}>
        {(id) => (
          <div className="flex gap-2">
            <Input id={id} value={ticker} onChange={(e) => setTicker(e.target.value)} />
            <Button type="button" variant="outline" disabled={!ticker.trim() || status !== "cloud"} onClick={() => void verify()}>Verificar</Button>
          </div>
        )}
      </Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Investido">{(id) => <MoneyInput id={id} value={invested} onChange={setInvested} />}</Field>
        {ticker.trim() ? (
          <Field label="Unidades">{(id) => <Input id={id} type="number" step="any" value={units ?? 0} onChange={(e) => setUnits(Number(e.target.value))} />}</Field>
        ) : (
          <Field label="Valor atual">{(id) => <MoneyInput id={id} value={manual} onChange={setManual} />}</Field>
        )}
      </div>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Corretora, conta…" />}</Field>
      {investment && <div className="flex items-center gap-2"><Checkbox id="inv-archived" checked={archived} onCheckedChange={(v) => setArchived(v === true)} /><Label htmlFor="inv-archived">Arquivado</Label></div>}
    </FormDialog>
  );
}

function ContributeDialog({ investment, open, onOpenChange }: { investment: InvestmentRow; open: boolean; onOpenChange: (o: boolean) => void }) {
  const { data } = useTables("accounts", "categories", "transactions");
  const [amount, setAmount] = useState<number | null>(null);
  const [units, setUnits] = useState(0);
  const [day, setDay] = useState(toDateInput(new Date()));
  const [post, setPost] = useState(true);
  const [accountID, setAccountID] = useState("");
  useEffect(() => {
    if (open) {
      setAmount(null);
      setUnits(0);
      setAccountID(data.accounts[0]?.id ?? "");
    }
  }, [open, data.accounts]);
  const save = async () => {
    if (!amount) return;
    // InvestmentService.contribute: soma ao investido e às unidades e, se pedido, lança a saída.
    await mutate.update("investments", investment.id, {
      invested_amount: investment.invested_amount + amount,
      units: investment.units + Math.max(0, units),
      ...(usesQuotes(investment) ? {} : { manual_value: investment.manual_value + amount }),
    });
    if (post) {
      const categoryID = await expenseCategory("Investimentos", data, "chart.line.uptrend.xyaxis", "indigo");
      await mutate.insert("transactions", {
        id: newID(), title: `Aporte · ${investment.name}`, amount, kind: "expense", currency_code: investment.currency_code,
        date: fromDateInput(day) ?? now(), notes: "", created_at: now(), external_id: `investment-contribution-${newID()}`,
        category_id: categoryID, account_id: accountID || null,
      });
    }
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={`Aportar · ${investment.name}`} onSubmit={save} valid={(amount ?? 0) > 0}>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Valor">{(id) => <MoneyInput id={id} value={amount} onChange={setAmount} autoFocus />}</Field>
        {usesQuotes(investment) && <Field label="Unidades compradas">{(id) => <Input id={id} type="number" step="any" value={units} onChange={(e) => setUnits(Number(e.target.value))} />}</Field>}
      </div>
      <Field label="Data">{(id) => <Input id={id} type="date" value={day} onChange={(e) => setDay(e.target.value)} />}</Field>
      <div className="flex items-center gap-2"><Switch id="post" checked={post} onCheckedChange={setPost} /><Label htmlFor="post">Sai de uma conta (lança nas Finanças, categoria Investimentos)</Label></div>
      {post && <Field label="Conta">{(id) => <Select id={id} value={accountID} onChange={setAccountID}><option value="">Sem conta</option>{data.accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</Select>}</Field>}
    </FormDialog>
  );
}

function Wealth() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const { status } = useSession();
  const { data } = useTables("investments", "accounts", "transactions", "categories", "wealth_snapshots");
  const { settings, set } = useSettings();
  const rate = settings.brlPerEUR;
  const [form, setForm] = useState<{ open: boolean; investment: InvestmentRow | null }>({ open: false, investment: null });
  const [contributing, setContributing] = useState<InvestmentRow | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [failed, setFailed] = useState<string[]>([]);
  const [targetOpen, setTargetOpen] = useState(false);
  const [target, setTarget] = useState<number | null>(null);
  const snapshotted = useRef(false);

  const active = data.investments.filter((i) => !i.is_archived);
  const summary = useMemo(() => {
    const cash = data.accounts.filter((a) => !a.is_archived).reduce((s, a) => s + toEur(accountBalance(a, data.transactions), a.currency_code, rate), 0);
    const invested = active.reduce((s, i) => s + toEur(i.invested_amount, i.currency_code, rate), 0);
    const value = active.reduce((s, i) => s + toEur(currentValue(i), i.currency_code, rate), 0);
    return { cash, invested, value, gain: value - invested, netWorth: cash + value };
  }, [data, active, rate]);

  // Poupança do mês (SavingsProgress): receitas − gastos + aportes.
  const month = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
  const m = monthSummary(month, data.transactions, rate);
  const investCategory = data.categories.find((c) => c.name === "Investimentos" && c.kind === "expense");
  const contributions = data.transactions
    .filter((t) => t.kind === "expense" && t.category_id === investCategory?.id && new Date(t.date) >= month)
    .reduce((s, t) => s + toEur(t.amount, t.currency_code, rate), 0);
  const saved = m.income - m.expenses + contributions;

  useEffect(() => {
    if (params.get("novo")) {
      setForm({ open: true, investment: null });
      router.replace(pathname);
    }
  }, [params, router, pathname]);

  // Fotografia de hoje do património (uma por dia, chave igual à do iPhone).
  useEffect(() => {
    if (snapshotted.current || data.accounts.length + data.investments.length === 0) return;
    snapshotted.current = true;
    const day = new Date();
    day.setHours(0, 0, 0, 0);
    const key = `${day.getTime() / 1000}.0`;
    const row = { day: day.toISOString(), cash: Math.round(summary.cash * 100) / 100, invested: Math.round(summary.invested * 100) / 100, investments_value: Math.round(summary.value * 100) / 100 };
    const existing = data.wealth_snapshots.find((w) => w.id === key);
    void (existing ? mutate.update("wealth_snapshots", key, row) : mutate.insert("wealth_snapshots", { id: key, ...row }));
  }, [data, summary]);

  async function refreshQuotes(onlyStale = false) {
    if (status !== "cloud") return;
    const targets = active.filter((i) => usesQuotes(i) && (!onlyStale || !i.price_updated_at || Date.now() - Date.parse(i.price_updated_at) > QUOTE_MAX_AGE));
    if (targets.length === 0) return;
    setRefreshing(true);
    const bad: string[] = [];
    for (const i of targets) {
      try {
        const { quote } = await getDb().invoke<Quote>("mynik-api", { action: "quote", symbol: i.ticker, currency: i.currency_code });
        if (quote) await mutate.update("investments", i.id, { unit_price: quote.price, price_updated_at: now() });
        else bad.push(i.ticker);
      } catch {
        bad.push(i.ticker);
      }
    }
    setFailed(bad);
    setRefreshing(false);
  }
  useEffect(() => {
    void refreshQuotes(true);
  }, [status, data.investments.length]); // eslint-disable-line react-hooks/exhaustive-deps

  const history = [...data.wealth_snapshots].sort((a, b) => a.day.localeCompare(b.day)).map((w) => ({ label: date(w.day, "short"), value: w.cash + w.investments_value }));

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Património"
        subtitle="Dinheiro nas contas, investimentos e poupança"
        actions={
          <>
            {status === "cloud" && <Button variant="outline" disabled={refreshing} onClick={() => void refreshQuotes()}><RefreshCw aria-hidden="true" className={refreshing ? "animate-spin" : ""} /> Atualizar cotações</Button>}
            <Button onClick={() => setForm({ open: true, investment: null })}><Plus aria-hidden="true" /> Novo investimento</Button>
          </>
        }
      />
      <section className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <Kpi label="Património líquido" value={money(summary.netWorth)} />
        <Kpi label="Dinheiro nas contas" value={money(summary.cash)} />
        <Kpi label="Investimentos" value={money(summary.value)} note={`Investido ${money(summary.invested)}`} />
        <Kpi label="Ganho" value={money(summary.gain, "EUR", { signed: true })} note={summary.invested > 0 ? percent(summary.gain / summary.invested, 1) : undefined} tone={summary.gain >= 0 ? "positive" : "danger"} />
      </section>
      {failed.length > 0 && <p className="m-0 text-sm text-warning">Sem cotação para {failed.join(", ")}.</p>}
      {status === "demo" && <p className="m-0 text-xs text-muted-foreground">As cotações atualizam-se com a conta (Yahoo Finance e BCE, grátis).</p>}

      <div className="grid gap-4 lg:grid-cols-[2fr_1fr]">
        <Card title="Investimentos">
          {active.length === 0 ? <Empty title="Sem investimentos" /> : active.map((i) => {
            const value = currentValue(i);
            const gain = value - i.invested_amount;
            return (
              <div key={i.id} className="flex items-center gap-3">
                <button type="button" onClick={() => setForm({ open: true, investment: i })} className="flex min-w-0 flex-1 flex-col text-left">
                  <span className="truncate font-medium">{i.name}</span>
                  <span className="text-xs text-muted-foreground">{kinds[i.kind]}{i.ticker && ` · ${i.ticker}`}{i.price_updated_at && ` · ${date(i.price_updated_at, "short")} ${date(i.price_updated_at, "time")}`}</span>
                </button>
                <span className="flex flex-col items-end">
                  <span className="tabular font-semibold">{money(value, i.currency_code)}</span>
                  <span className={`text-xs ${gain >= 0 ? "text-positive" : "text-danger"}`}>{money(gain, i.currency_code, { signed: true })}{i.invested_amount > 0 && ` (${percent(gain / i.invested_amount, 1)})`}</span>
                </span>
                <Button size="sm" variant="outline" onClick={() => setContributing(i)}>Aportar</Button>
              </div>
            );
          })}
          {data.investments.some((i) => i.is_archived) && (
            <details><summary className="cursor-pointer text-sm text-muted-foreground">Arquivados</summary>
              {data.investments.filter((i) => i.is_archived).map((i) => <button key={i.id} type="button" className="block py-1 text-left text-sm" onClick={() => setForm({ open: true, investment: i })}>{i.name}</button>)}
            </details>
          )}
        </Card>
        <Card title="Meta de poupança" action={<Button variant="ghost" size="icon" aria-label="Editar meta de poupança" onClick={() => { setTarget(settings.savingsMonthlyTarget || null); setTargetOpen(true); }}><Pencil aria-hidden="true" /></Button>}>
          <dl className="m-0 grid grid-cols-2 gap-2 text-sm">
            <dt className="text-muted-foreground">Poupado este mês</dt><dd className="m-0 text-right tabular">{money(saved)}</dd>
            <dt className="text-muted-foreground">Taxa de poupança</dt><dd className="m-0 text-right">{m.income > 0 ? percent(saved / m.income) : "—"}</dd>
            {settings.savingsMonthlyTarget > 0 && <><dt className="text-muted-foreground">Meta</dt><dd className="m-0 text-right">{money(settings.savingsMonthlyTarget)}</dd></>}
          </dl>
          {settings.savingsMonthlyTarget > 0 && <Bar value={Math.max(0, saved) / settings.savingsMonthlyTarget} color="var(--positive)" />}
          <p className="m-0 text-xs text-muted-foreground">Receitas − gastos, contando os aportes a investimentos como poupança.</p>
        </Card>
      </div>

      <Card title="Evolução do património">
        {history.length < 2 ? <Empty title="A evolução aparece ao fim de alguns dias" /> : (
          <div className="h-64" role="img" aria-label="Evolução do património">
            <ResponsiveContainer>
              <AreaChart data={history}>
                <XAxis dataKey="label" stroke="var(--muted-foreground)" tickLine={false} axisLine={false} />
                <YAxis stroke="var(--muted-foreground)" tickLine={false} axisLine={false} width={70} tickFormatter={(v) => money(Number(v), "EUR", { compact: true })} />
                <Tooltip formatter={(v) => money(Number(v))} contentStyle={{ background: "var(--card)", border: "1px solid var(--border)", borderRadius: 10 }} />
                <Area dataKey="value" stroke="var(--primary)" fill="var(--primary)" fillOpacity={0.2} strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>

      <InvestmentForm investment={form.investment} open={form.open} onOpenChange={(o) => setForm((s) => ({ ...s, open: o }))} />
      {contributing && <ContributeDialog investment={contributing} open onOpenChange={(o) => !o && setContributing(null)} />}
      <FormDialog open={targetOpen} onOpenChange={setTargetOpen} title="Meta de poupança" description="Põe 0 para não ter meta." onSubmit={() => set("savingsMonthlyTarget", target ?? 0)}>
        <Field label="Por mês">{(id) => <MoneyInput id={id} value={target} onChange={setTarget} autoFocus />}</Field>
      </FormDialog>
    </div>
  );
}

export default function WealthPage() {
  return (
    <Suspense>
      <Wealth />
    </Suspense>
  );
}
