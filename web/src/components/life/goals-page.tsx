"use client";

import { Pencil, Plus, Target } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import { ColorPicker, Field, FormDialog, MoneyInput, Select, SymbolPicker } from "@/components/common/fields";
import { Bar, Card, Empty, Kpi, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { convert } from "@/lib/calc/finance";
import { goalContributions, goalProgress, goalSources } from "@/lib/calc/life";
import { newID, now } from "@/lib/db/client";
import type { GoalRow } from "@/lib/db/schema";
import { mutate, useTables } from "@/lib/db/store";
import { date, fromDateInput, money, percent, toDateInput } from "@/lib/format";
import { colorHex, goalSymbols, SymbolIcon } from "@/lib/icons";
import { useSettings } from "@/lib/settings";
import { cn } from "@/lib/utils";

function GoalForm({ goal, open, onOpenChange }: { goal: GoalRow | null; open: boolean; onOpenChange: (o: boolean) => void }) {
  const { data } = useTables("accounts", "categories");
  const [title, setTitle] = useState("");
  const [target, setTarget] = useState<number | null>(null);
  const [currency, setCurrency] = useState("EUR");
  const [hasDeadline, setHasDeadline] = useState(false);
  const [deadline, setDeadline] = useState("");
  const [symbol, setSymbol] = useState("target");
  const [color, setColor] = useState("green");
  const [source, setSource] = useState("manual");
  const [manual, setManual] = useState<number | null>(0);
  const [start, setStart] = useState(toDateInput(new Date()));
  const [accountID, setAccountID] = useState("");
  const [categoryID, setCategoryID] = useState("");
  const [archived, setArchived] = useState(false);
  useEffect(() => {
    if (!open) return;
    setTitle(goal?.title ?? "");
    setTarget(goal?.target_amount ?? null);
    setCurrency(goal?.currency_code ?? "EUR");
    setHasDeadline(Boolean(goal?.deadline));
    setDeadline(toDateInput(goal?.deadline ?? new Date(Date.now() + 180 * 86_400_000)));
    setSymbol(goal?.symbol_name ?? "target");
    setColor(goal?.color_name ?? "green");
    setSource(goal?.source ?? "manual");
    setManual(goal?.manual_amount ?? 0);
    setStart(toDateInput(goal?.start_date ?? new Date()));
    setAccountID(goal?.account_id ?? "");
    setCategoryID(goal?.category_id ?? "");
    setArchived(goal?.is_archived ?? false);
  }, [open, goal]);
  const valid = title.trim().length > 0 && (target ?? 0) > 0 && (source !== "account" || accountID) && (source !== "category" || categoryID);
  const save = async () => {
    const row = {
      title: title.trim(), target_amount: target ?? 0, currency_code: currency, deadline: hasDeadline ? fromDateInput(deadline) : null,
      symbol_name: symbol, color_name: color, source, manual_amount: manual ?? 0, start_date: fromDateInput(start, 0) ?? now(),
      account_id: source === "account" ? accountID : null, category_id: source === "category" ? categoryID : null, is_archived: archived,
    };
    if (goal) await mutate.update("goals", goal.id, row);
    else await mutate.insert("goals", { id: newID(), created_at: now(), ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={goal ? "Editar meta" : "Nova meta"} onSubmit={save} valid={Boolean(valid)}
      onDelete={goal ? () => mutate.remove("goals", [goal.id]) : undefined} deleteWhat="esta meta">
      <Field label="Nome da meta">{(id) => <Input id={id} autoFocus value={title} onChange={(e) => setTitle(e.target.value)} />}</Field>
      <div className="grid grid-cols-[1fr_110px] gap-3">
        <Field label="Valor-alvo">{(id) => <MoneyInput id={id} value={target} onChange={setTarget} />}</Field>
        <Field label="Moeda">{(id) => <Select id={id} value={currency} onChange={setCurrency}><option>EUR</option><option>BRL</option></Select>}</Field>
      </div>
      <div className="flex items-center gap-3">
        <Switch id="has-deadline" checked={hasDeadline} onCheckedChange={setHasDeadline} /><Label htmlFor="has-deadline">Tem prazo</Label>
        {hasDeadline && <Input type="date" aria-label="Prazo" value={deadline} onChange={(e) => setDeadline(e.target.value)} className="w-44" />}
      </div>
      <Field label="Progresso" hint={goalSources[source as keyof typeof goalSources]?.explanation}>
        {(id) => <Select id={id} value={source} onChange={setSource}>{Object.entries(goalSources).map(([v, s]) => <option key={v} value={v}>{s.title}</option>)}</Select>}
      </Field>
      {source === "manual" && <Field label="Já juntei">{(id) => <MoneyInput id={id} value={manual} onChange={setManual} />}</Field>}
      {source === "account" && (
        <Field label="Conta">{(id) => <Select id={id} value={accountID} onChange={setAccountID}><option value="">Escolher…</option>{data.accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</Select>}</Field>
      )}
      {source === "category" && (
        <div className="grid grid-cols-2 gap-3">
          <Field label="Categoria">{(id) => <Select id={id} value={categoryID} onChange={setCategoryID}><option value="">Escolher…</option>{data.categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</Select>}</Field>
          <Field label="Conta a partir de">{(id) => <Input id={id} type="date" value={start} onChange={(e) => setStart(e.target.value)} />}</Field>
        </div>
      )}
      <div className="flex flex-col gap-1.5"><Label>Ícone</Label><SymbolPicker symbols={goalSymbols} value={symbol} onChange={setSymbol} color={color} /></div>
      <div className="flex flex-col gap-1.5"><Label>Cor</Label><ColorPicker value={color} onChange={setColor} /></div>
      {goal && <div className="flex items-center gap-2"><Checkbox id="goal-archived" checked={archived} onCheckedChange={(v) => setArchived(v === true)} /><Label htmlFor="goal-archived">Arquivada</Label></div>}
    </FormDialog>
  );
}

/** "Juntar dinheiro" (GoalContributionService): soma ao manual ou cria o movimento da categoria. */
function ContributionDialog({ goal, open, onOpenChange }: { goal: GoalRow; open: boolean; onOpenChange: (o: boolean) => void }) {
  const { data } = useTables("accounts", "categories");
  const [amount, setAmount] = useState<number | null>(null);
  const [day, setDay] = useState(toDateInput(new Date()));
  const [accountID, setAccountID] = useState("");
  const category = data.categories.find((c) => c.id === goal.category_id);
  useEffect(() => {
    if (open) {
      setAmount(null);
      setAccountID(data.accounts[0]?.id ?? "");
    }
  }, [open, data.accounts]);
  const save = async () => {
    if (!amount || amount <= 0) return;
    if (goal.source === "manual") await mutate.update("goals", goal.id, { manual_amount: goal.manual_amount + amount });
    else if (goal.source === "category" && category) {
      await mutate.insert("transactions", {
        id: newID(), title: `Meta: ${goal.title}`, amount, kind: category.kind, currency_code: goal.currency_code,
        date: fromDateInput(day) ?? now(), notes: "", created_at: now(), external_id: "", category_id: category.id, account_id: accountID || null,
      });
    }
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={`Juntar para ${goal.title}`} onSubmit={save} valid={(amount ?? 0) > 0}
      description={goal.source === "category" && category ? `Cria um movimento em ${category.name} nas Finanças.` : undefined}>
      <Field label="Valor">{(id) => <MoneyInput id={id} value={amount} onChange={setAmount} autoFocus />}</Field>
      {goal.source === "category" && (
        <div className="grid grid-cols-2 gap-3">
          <Field label="Data">{(id) => <Input id={id} type="date" value={day} onChange={(e) => setDay(e.target.value)} />}</Field>
          <Field label="Conta">{(id) => <Select id={id} value={accountID} onChange={setAccountID}><option value="">Sem conta</option>{data.accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</Select>}</Field>
        </div>
      )}
    </FormDialog>
  );
}

function Goals() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const { data } = useTables("goals", "accounts", "transactions", "categories");
  const { settings } = useSettings();
  const [form, setForm] = useState<{ open: boolean; goal: GoalRow | null }>({ open: false, goal: null });
  const [contributing, setContributing] = useState(false);
  const goals = useMemo(() => {
    const ctx = { accounts: data.accounts, transactions: data.transactions, categories: data.categories, rate: settings.brlPerEUR };
    return data.goals.map((g) => ({ g, p: goalProgress(g, ctx) }));
  }, [data, settings.brlPerEUR]);
  const active = goals.filter(({ g }) => !g.is_archived);
  const archived = goals.filter(({ g }) => g.is_archived);
  const selected = goals.find(({ g }) => g.id === params.get("id")) ?? active[0] ?? null;
  const totalTarget = active.reduce((s, { g }) => s + convert(g.target_amount, g.currency_code, "EUR", settings.brlPerEUR), 0);
  const totalSaved = active.reduce((s, { g, p }) => s + convert(Math.min(p.current, p.target), g.currency_code, "EUR", settings.brlPerEUR), 0);

  useEffect(() => {
    if (params.get("novo")) {
      setForm({ open: true, goal: null });
      router.replace(pathname);
    }
  }, [params, router, pathname]);

  const list = (items: typeof goals) => items.map(({ g, p }) => (
    <button key={g.id} type="button" onClick={() => router.replace(`${pathname}?id=${g.id}`)} aria-current={selected?.g.id === g.id ? "true" : undefined}
      className={cn("flex flex-col gap-2 rounded-lg p-2 text-left", selected?.g.id === g.id ? "bg-sidebar-active" : "hover:bg-sidebar-active/60")}>
      <span className="flex items-center gap-2.5"><SymbolIcon name={g.symbol_name} color={g.color_name} size={28} /><span className="flex-1 truncate font-medium">{g.title}</span><span className="text-xs text-muted-foreground">{percent(p.fraction)}</span></span>
      <Bar value={p.fraction} color={colorHex(g.color_name)} />
    </button>
  ));

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Metas" subtitle="Valores-alvo ligados às Finanças" actions={<Button onClick={() => setForm({ open: true, goal: null })}><Plus aria-hidden="true" /> Nova meta</Button>} />
      <div className="grid grid-cols-2 gap-4">
        <Kpi label="Juntado" value={money(totalSaved)} note={`${active.length} metas ativas`} />
        <Kpi label="Alvo total" value={money(totalTarget)} note={totalTarget > 0 ? `${percent(totalSaved / totalTarget)} do total` : undefined} />
      </div>
      <div className="grid gap-4 lg:grid-cols-[320px_1fr]">
        <div className="flex flex-col gap-4">
          <Card title="Ativas">{active.length ? list(active) : <Empty icon={<Target aria-hidden="true" />} title="Sem metas" />}</Card>
          {archived.length > 0 && <Card title="Arquivadas">{list(archived)}</Card>}
        </div>
        {selected ? (
          <Card
            title={<span className="flex items-center gap-2"><SymbolIcon name={selected.g.symbol_name} color={selected.g.color_name} />{selected.g.title}</span>}
            action={<div className="flex gap-2">
              {selected.g.source !== "account" && <Button size="sm" onClick={() => setContributing(true)}>Juntar dinheiro</Button>}
              <Button size="sm" variant="ghost" aria-label="Editar meta" onClick={() => setForm({ open: true, goal: selected.g })}><Pencil aria-hidden="true" /></Button>
            </div>}
          >
            <div className="flex items-baseline gap-2"><span className="tabular text-3xl font-bold">{money(selected.p.current, selected.g.currency_code)}</span><span className="text-muted-foreground">de {money(selected.p.target, selected.g.currency_code)}</span></div>
            <Bar value={selected.p.fraction} height={10} color={colorHex(selected.g.color_name)} />
            <dl className="m-0 grid grid-cols-2 gap-2 text-sm">
              <dt className="text-muted-foreground">Progresso</dt><dd className="m-0 text-right">{percent(selected.p.fraction)}</dd>
              <dt className="text-muted-foreground">Falta</dt><dd className="m-0 text-right">{money(selected.p.remaining, selected.g.currency_code)}</dd>
              {selected.g.deadline && <><dt className="text-muted-foreground">Prazo</dt><dd className="m-0 text-right">{date(selected.g.deadline)}</dd></>}
              {selected.p.monthlyNeeded != null && <><dt className="text-muted-foreground">Juntar por mês</dt><dd className="m-0 text-right">{money(selected.p.monthlyNeeded, selected.g.currency_code)}</dd></>}
              <dt className="text-muted-foreground">Origem</dt><dd className="m-0 text-right">{goalSources[selected.g.source as keyof typeof goalSources]?.title}</dd>
            </dl>
            {selected.p.isReached && <p className="m-0 text-positive">Meta atingida 🎉</p>}
            {selected.p.isPastDeadline && !selected.p.isReached && <p className="m-0 text-warning">O prazo já passou.</p>}
            {selected.g.source === "category" && (
              <div className="flex flex-col gap-1.5">
                <span className="text-sm font-medium">Movimentos</span>
                {goalContributions(selected.g, data.transactions, data.categories).slice(0, 12).map((t) => (
                  <div key={t.id} className="flex justify-between text-[13px]"><span>{t.title} · {date(t.date, "short")}</span><span className="tabular">{money(t.amount, t.currency_code)}</span></div>
                ))}
              </div>
            )}
          </Card>
        ) : <Card><Empty title="Cria uma meta para começar" /></Card>}
      </div>
      <GoalForm goal={form.goal} open={form.open} onOpenChange={(o) => setForm((s) => ({ ...s, open: o }))} />
      {selected && <ContributionDialog goal={selected.g} open={contributing} onOpenChange={setContributing} />}
    </div>
  );
}

export default function GoalsPage() {
  return (
    <Suspense>
      <Goals />
    </Suspense>
  );
}
