"use client";

import { Check, Plus, Repeat } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Card, Empty, Kpi } from "@/components/shell/page-header";
import { Field, FormDialog, MoneyInput, Select } from "@/components/common/fields";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { monthlyCost, nextDueDate, recurrenceTitle } from "@/lib/calc/finance";
import { newID, now } from "@/lib/db/client";
import type { BillRow } from "@/lib/db/schema";
import { mutate, useTable } from "@/lib/db/store";
import { daysUntil, date, due, fromDateInput, money, toDateInput } from "@/lib/format";
import { SymbolIcon } from "@/lib/icons";
import { useFinanceBasics } from "./use-finance";

/** "Paguei": cria o gasto e, se a conta se repete, avança o vencimento (BillPaymentService). */
export async function markBillPaid(bill: BillRow) {
  const paidAt = now();
  await mutate.insert("transactions", {
    id: newID(),
    title: bill.title,
    amount: bill.amount,
    kind: "expense",
    currency_code: bill.currency_code,
    date: paidAt,
    notes: "",
    created_at: paidAt,
    external_id: "",
    category_id: bill.category_id,
    account_id: bill.account_id,
  });
  const next = nextDueDate(bill.due_date, bill.recurrence);
  await mutate.update("bills", bill.id, next ? { paid_at: paidAt, due_date: next, is_paid: false } : { paid_at: paidAt, is_paid: true });
}

export function BillForm({ open, onOpenChange, bill, subscription = false }: { open: boolean; onOpenChange: (open: boolean) => void; bill?: BillRow | null; subscription?: boolean }) {
  const { expenseCategories, accounts } = useFinanceBasics();
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState<number | null>(null);
  const [currency, setCurrency] = useState("EUR");
  const [day, setDay] = useState(toDateInput(new Date()));
  const [recurrence, setRecurrence] = useState("monthly");
  const [isSubscription, setIsSubscription] = useState(false);
  const [categoryID, setCategoryID] = useState("");
  const [accountID, setAccountID] = useState("");
  const [notes, setNotes] = useState("");

  useEffect(() => {
    if (!open) return;
    setTitle(bill?.title ?? "");
    setAmount(bill?.amount ?? null);
    setCurrency(bill?.currency_code ?? "EUR");
    setDay(toDateInput(bill?.due_date ?? new Date()));
    setRecurrence(bill?.recurrence ?? "monthly");
    setIsSubscription(bill?.is_subscription ?? subscription);
    setCategoryID(bill?.category_id ?? "");
    setAccountID(bill?.account_id ?? accounts[0]?.id ?? "");
    setNotes(bill?.notes ?? "");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, bill]);

  async function save() {
    const row = {
      title: title.trim(), amount: amount ?? 0, currency_code: currency, due_date: fromDateInput(day, 9) ?? now(),
      recurrence, is_subscription: isSubscription, category_id: categoryID || null, account_id: accountID || null, notes,
    };
    if (bill) await mutate.update("bills", bill.id, row);
    else await mutate.insert("bills", { id: newID(), is_paid: false, created_at: now(), ...row });
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={bill ? "Editar conta" : isSubscription ? "Nova assinatura" : "Nova conta a pagar"}
      onSubmit={save}
      valid={title.trim().length > 0 && (amount ?? 0) > 0}
      onDelete={bill ? () => mutate.remove("bills", [bill.id]) : undefined}
      deleteWhat="esta conta"
    >
      <Field label="Descrição">{(id) => <Input id={id} autoFocus value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Ex.: Renda" />}</Field>
      <div className="grid grid-cols-[1fr_110px] gap-3">
        <Field label="Valor">{(id) => <MoneyInput id={id} value={amount} onChange={setAmount} />}</Field>
        <Field label="Moeda">{(id) => <Select id={id} value={currency} onChange={setCurrency}><option>EUR</option><option>BRL</option></Select>}</Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Vencimento">{(id) => <Input id={id} type="date" value={day} onChange={(e) => setDay(e.target.value)} />}</Field>
        <Field label="Repete">
          {(id) => (
            <Select id={id} value={recurrence} onChange={setRecurrence}>
              {Object.entries(recurrenceTitle).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </Select>
          )}
        </Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Categoria">
          {(id) => (
            <Select id={id} value={categoryID} onChange={setCategoryID}>
              <option value="">Sem categoria</option>
              {expenseCategories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </Select>
          )}
        </Field>
        <Field label="Conta">
          {(id) => (
            <Select id={id} value={accountID} onChange={setAccountID}>
              <option value="">Sem conta</option>
              {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
            </Select>
          )}
        </Field>
      </div>
      <div className="flex items-center gap-2">
        <Checkbox id="is-subscription" checked={isSubscription} onCheckedChange={(v) => setIsSubscription(v === true)} />
        <Label htmlFor="is-subscription">É uma assinatura</Label>
      </div>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} />}</Field>
    </FormDialog>
  );
}

/** Uma conta a pagar: ícone da categoria, vencimento (laranja se perto) e "Paguei". */
export function BillLine({ bill, onEdit }: { bill: BillRow; onEdit?: (bill: BillRow) => void }) {
  const { categories } = useFinanceBasics();
  const category = categories.find((c) => c.id === bill.category_id);
  const days = daysUntil(bill.due_date);
  const urgent = !bill.is_paid && days <= 1;
  return (
    <div className="flex items-center gap-3">
      <SymbolIcon name={category?.symbol_name ?? "calendar"} color={category?.color_name} size={36} />
      <button type="button" className="flex min-w-0 flex-1 flex-col text-left" onClick={() => onEdit?.(bill)}>
        <span className="truncate font-medium">{bill.title}</span>
        <span className={`text-xs ${urgent ? "text-warning" : "text-muted-foreground"}`}>
          {bill.is_paid ? `Paga a ${date(bill.paid_at, "short")}` : due(bill.due_date)}
          {bill.recurrence !== "none" && ` · ${recurrenceTitle[bill.recurrence]}`}
        </span>
      </button>
      <span className="tabular font-semibold">{money(bill.amount, bill.currency_code)}</span>
      {!bill.is_paid && (
        <Button variant="outline" size="icon" aria-label={`Paguei ${bill.title}`} title="Paguei" onClick={() => void markBillPaid(bill)}>
          <Check aria-hidden="true" />
        </Button>
      )}
    </div>
  );
}

export function BillsView({ openNew }: { openNew: boolean }) {
  const { rows } = useTable("bills");
  const [editing, setEditing] = useState<BillRow | null>(null);
  const [formOpen, setFormOpen] = useState(openNew);
  useEffect(() => setFormOpen(openNew), [openNew]);
  const unpaid = rows.filter((b) => !b.is_paid).sort((a, b) => a.due_date.localeCompare(b.due_date));
  const paid = rows.filter((b) => b.is_paid).sort((a, b) => (b.paid_at ?? "").localeCompare(a.paid_at ?? ""));
  const edit = (b: BillRow) => {
    setEditing(b);
    setFormOpen(true);
  };
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <Card
        title="Por pagar"
        action={<Button size="sm" onClick={() => { setEditing(null); setFormOpen(true); }}><Plus aria-hidden="true" /> Conta</Button>}
      >
        {unpaid.length === 0 ? <Empty title="Tudo pago" /> : unpaid.map((b) => <BillLine key={b.id} bill={b} onEdit={edit} />)}
      </Card>
      <Card title="Pagas">
        {paid.length === 0 ? <Empty title="Nenhuma conta paga ainda" /> : paid.map((b) => <BillLine key={b.id} bill={b} onEdit={edit} />)}
      </Card>
      <BillForm open={formOpen} onOpenChange={setFormOpen} bill={editing} />
    </div>
  );
}

export function SubscriptionsView() {
  const { rows } = useTable("bills");
  const { rate } = useFinanceBasics();
  const [editing, setEditing] = useState<BillRow | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const subscriptions = useMemo(
    () => rows.filter((b) => b.is_subscription).sort((a, b) => monthlyCost(b, rate) - monthlyCost(a, rate)),
    [rows, rate],
  );
  const monthly = subscriptions.reduce((sum, b) => sum + monthlyCost(b, rate), 0);
  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4">
        <Kpi label="Por mês" value={money(monthly)} note={`${subscriptions.length} assinaturas`} />
        <Kpi label="Por ano" value={money(monthly * 12)} />
      </div>
      <Card title="Assinaturas" action={<Button size="sm" onClick={() => { setEditing(null); setFormOpen(true); }}><Plus aria-hidden="true" /> Assinatura</Button>}>
        {subscriptions.length === 0 ? (
          <Empty icon={<Repeat aria-hidden="true" />} title="Sem assinaturas">Regista Spotify, ginásio, iCloud… e vê quanto gastas por ano.</Empty>
        ) : (
          subscriptions.map((b) => (
            <div key={b.id} className="flex items-center gap-3">
              <button type="button" className="flex min-w-0 flex-1 flex-col text-left" onClick={() => { setEditing(b); setFormOpen(true); }}>
                <span className="truncate font-medium">{b.title}</span>
                <span className="text-xs text-muted-foreground">{money(b.amount, b.currency_code)} · {recurrenceTitle[b.recurrence]}</span>
              </button>
              <span className="tabular font-semibold">{money(monthlyCost(b, rate))}/mês</span>
            </div>
          ))
        )}
      </Card>
      <BillForm open={formOpen} onOpenChange={setFormOpen} bill={editing} subscription />
    </div>
  );
}
