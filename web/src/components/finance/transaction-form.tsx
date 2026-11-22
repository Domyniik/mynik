"use client";

import { ScanLine, Sparkles } from "lucide-react";
import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { Field, FormDialog, MoneyInput, Segmented, Select } from "@/components/common/fields";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { MerchantRules, sourceLabel, type SuggestionSource } from "@/lib/calc/categorize";
import { toEur } from "@/lib/calc/finance";
import { parseReceipt } from "@/lib/calc/receipt";
import { newID, now } from "@/lib/db/client";
import type { TransactionRow } from "@/lib/db/schema";
import { mutate, useTable } from "@/lib/db/store";
import { fromDateInput, money, toDateInput } from "@/lib/format";
import { useSettings } from "@/lib/settings";
import { useFinanceBasics } from "./use-finance";

export type TransactionKind = "expense" | "income";

/** Lê o texto de uma fatura no próprio computador (tesseract.js) e extrai os campos. */
async function scanReceipt(file: File) {
  const { createWorker } = await import("tesseract.js");
  const worker = await createWorker(["spa", "por", "eng"]);
  try {
    const { data } = await worker.recognize(file);
    return parseReceipt(data.text.split("\n"));
  } finally {
    await worker.terminate();
  }
}

export function TransactionForm({
  open, onOpenChange, transaction, initialKind = "expense",
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  transaction?: TransactionRow | null;
  initialKind?: TransactionKind;
}) {
  const { categories, accounts, rate } = useFinanceBasics();
  const { settings } = useSettings();
  const { rows: transactions } = useTable("transactions");
  const { rows: notes } = useTable("notes");
  const [kind, setKind] = useState<TransactionKind>(initialKind);
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState<number | null>(null);
  const [currency, setCurrency] = useState("EUR");
  const [day, setDay] = useState(toDateInput(new Date()));
  const [categoryID, setCategoryID] = useState("");
  const [accountID, setAccountID] = useState("");
  const [notesText, setNotesText] = useState("");
  const [suggested, setSuggested] = useState<SuggestionSource | null>(null);
  const [scanning, setScanning] = useState(false);
  const categoryTouched = useRef(false);
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!open) return;
    const t = transaction;
    setKind((t?.kind as TransactionKind) ?? initialKind);
    setTitle(t?.title ?? "");
    setAmount(t?.amount ?? null);
    setCurrency(t?.currency_code ?? "EUR");
    setDay(toDateInput(t?.date ?? new Date()));
    setCategoryID(t?.category_id ?? "");
    setAccountID(t?.account_id ?? accounts[0]?.id ?? "");
    setNotesText(t?.notes ?? "");
    setSuggested(null);
    categoryTouched.current = Boolean(t?.category_id);
    // Só ao abrir.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, transaction]);

  // As contas podem chegar depois de o formulário abrir.
  useEffect(() => {
    if (open && !transaction && !accountID && accounts[0]) setAccountID(accounts[0].id);
  }, [open, transaction, accountID, accounts]);

  const kindCategories = categories.filter((c) => c.kind === kind);

  // Sugestão de categoria (histórico, depois comerciante): a mesma lógica do iPhone sem IA.
  const rules = useMemo(() => {
    const byID = new Map(categories.map((c) => [c.id, c.name]));
    const history = transactions
      .filter((t) => t.kind === kind && t.category_id && byID.has(t.category_id))
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, 500)
      .map((t) => ({ title: t.title, categoryName: byID.get(t.category_id!)!, date: t.date }));
    return new MerchantRules(history);
  }, [transactions, categories, kind]);

  useEffect(() => {
    if (!open || categoryTouched.current || !settings.autoCategorize) return;
    const timer = setTimeout(() => {
      const suggestion = rules.suggest(title, kindCategories.map((c) => c.name));
      const match = suggestion && kindCategories.find((c) => c.name === suggestion.categoryName);
      if (match) {
        setCategoryID(match.id);
        setSuggested(suggestion.source);
      }
    }, 250);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [title, kind, open, rules, settings.autoCategorize]);

  const linkedNotes = transaction ? notes.filter((n) => n.linked_transaction_ids.includes(transaction.id)) : [];
  const valid = title.trim().length > 0 && amount != null && amount > 0;

  async function onScan(file: File) {
    setScanning(true);
    try {
      const result = await scanReceipt(file);
      if (!result.amount && !result.merchant) {
        toast.error("Não consegui ler a fatura", { description: "Tenta uma foto mais nítida e direita." });
        return;
      }
      setKind("expense");
      if (result.merchant) setTitle(result.merchant);
      if (result.amount) setAmount(result.amount);
      if (result.date) setDay(toDateInput(result.date));
      setCurrency(result.currencyCode);
      toast.success("Fatura lida", { description: "Confere os valores antes de guardar." });
    } catch (error) {
      toast.error("Não foi possível ler a fatura", { description: String(error) });
    } finally {
      setScanning(false);
    }
  }

  async function save() {
    const row = {
      title: title.trim(),
      amount: amount ?? 0,
      kind,
      currency_code: currency,
      date: fromDateInput(day) ?? now(),
      notes: notesText,
      category_id: categoryID || null,
      account_id: accountID || null,
    };
    if (transaction) await mutate.update("transactions", transaction.id, row);
    else await mutate.insert("transactions", { id: newID(), created_at: now(), external_id: "", ...row });
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={transaction ? "Editar movimento" : kind === "expense" ? "Novo gasto" : "Nova receita"}
      onSubmit={save}
      valid={valid}
      onDelete={transaction ? () => mutate.remove("transactions", [transaction.id]) : undefined}
      deleteWhat="este movimento"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <Segmented
          label="Tipo"
          value={kind}
          onChange={(k) => {
            setKind(k);
            if (!categoryTouched.current) setCategoryID("");
          }}
          options={[{ value: "expense", label: "Gasto" }, { value: "income", label: "Receita" }]}
        />
        <input ref={fileInput} type="file" accept="image/*" className="hidden" onChange={(e) => e.target.files?.[0] && void onScan(e.target.files[0])} />
        <Button type="button" variant="outline" size="sm" disabled={scanning} onClick={() => fileInput.current?.click()}>
          <ScanLine aria-hidden="true" /> {scanning ? "A ler a fatura…" : "Digitalizar fatura"}
        </Button>
      </div>
      {transaction?.external_id && (
        <p className="m-0 rounded-lg bg-surface px-3 py-2 text-xs text-muted-foreground">
          Atualizado automaticamente (loja, carro ou investimentos): as alterações podem ser substituídas.
        </p>
      )}
      <Field label="Descrição">{(id) => <Input id={id} value={title} onChange={(e) => setTitle(e.target.value)} autoFocus placeholder="Ex.: Mercadona" />}</Field>
      <div className="grid grid-cols-[1fr_110px] gap-3">
        <Field
          label="Valor"
          hint={currency === "BRL" && amount ? `≈ ${money(toEur(amount, "BRL", rate))}` : undefined}
        >
          {(id) => <MoneyInput id={id} value={amount} onChange={setAmount} />}
        </Field>
        <Field label="Moeda">
          {(id) => (
            <Select id={id} value={currency} onChange={setCurrency}>
              <option value="EUR">EUR</option>
              <option value="BRL">BRL</option>
            </Select>
          )}
        </Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Data">{(id) => <Input id={id} type="date" value={day} onChange={(e) => setDay(e.target.value)} />}</Field>
        <Field label="Conta">
          {(id) => (
            <Select id={id} value={accountID} onChange={setAccountID}>
              <option value="">Sem conta</option>
              {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
            </Select>
          )}
        </Field>
      </div>
      <Field
        label="Categoria"
        hint={suggested && (
          <span className="inline-flex items-center gap-1"><Sparkles size={12} aria-hidden="true" /> {sourceLabel[suggested]}</span>
        )}
      >
        {(id) => (
          <Select
            id={id}
            value={categoryID}
            onChange={(v) => {
              categoryTouched.current = true;
              setSuggested(null);
              setCategoryID(v);
            }}
          >
            <option value="">Sem categoria</option>
            {kindCategories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </Select>
        )}
      </Field>
      <Field label="Notas">{(id) => <Textarea id={id} value={notesText} onChange={(e) => setNotesText(e.target.value)} rows={2} />}</Field>
      {linkedNotes.length > 0 && (
        <div className="flex flex-col gap-1">
          <span className="text-sm font-medium">Páginas ligadas</span>
          {linkedNotes.map((n) => (
            <Link key={n.id} href={`/notas/?id=${n.id}`} className="text-sm">{n.icon} {n.title || "Sem título"}</Link>
          ))}
          <span className="text-xs text-muted-foreground">As ligações gerem-se no editor de notas.</span>
        </div>
      )}
    </FormDialog>
  );
}
