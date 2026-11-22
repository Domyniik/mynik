"use client";

import { FileSpreadsheet, Plus, Upload } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { Card, Empty } from "@/components/shell/page-header";
import { ColorPicker, Field, FormDialog, MoneyInput, Select, SymbolPicker } from "@/components/common/fields";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { MerchantRules, normalizeTitle } from "@/lib/calc/categorize";
import { type BankRow, decodeBankFile, duplicateKey, parseBankCSV } from "@/lib/calc/csv";
import { accountBalance, accountTypes } from "@/lib/calc/finance";
import { searchKey } from "@/lib/calc/search";
import { newID, now } from "@/lib/db/client";
import type { AccountRow, CategoryRow } from "@/lib/db/schema";
import { mutate, useTable } from "@/lib/db/store";
import { date, money } from "@/lib/format";
import { categorySymbols, SymbolIcon } from "@/lib/icons";
import { useSettings } from "@/lib/settings";
import { cn } from "@/lib/utils";
import { useFinanceBasics } from "./use-finance";

interface Preview {
  fileName: string;
  rows: (BankRow & { duplicate: boolean; categoryID: string | null })[];
  skipped: number;
}

/** Importar o extrato do banco: escolher ou arrastar o CSV (pt, es ou en), sem duplicados. */
export function ImportView({ droppedFile }: { droppedFile: File | null }) {
  const { categories, accounts } = useFinanceBasics();
  const { rows: transactions } = useTable("transactions");
  const { settings } = useSettings();
  const [file, setFile] = useState<File | null>(null);
  const [accountID, setAccountID] = useState("");
  const [currency, setCurrency] = useState("EUR");
  const [preview, setPreview] = useState<Preview | null>(null);
  const [dragging, setDragging] = useState(false);
  const [busy, setBusy] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (droppedFile) setFile(droppedFile);
  }, [droppedFile]);
  useEffect(() => {
    if (!accountID && accounts[0]) setAccountID(accounts[0].id);
  }, [accounts, accountID]);

  useEffect(() => {
    if (!file) return;
    let active = true;
    void file.arrayBuffer().then((bytes) => {
      if (!active) return;
      try {
        const result = parseBankCSV(decodeBankFile(bytes));
        const existing = new Set(transactions.map((t) => duplicateKey(t.date, t.kind === "expense" ? -t.amount : t.amount, t.title)));
        // Categoria: a mesma descrição no histórico (CategoryGuesser), depois as regras.
        const byTitle = new Map<string, CategoryRow>();
        const byID = new Map(categories.map((c) => [c.id, c]));
        for (const t of [...transactions].sort((a, b) => a.date.localeCompare(b.date))) {
          const c = t.category_id ? byID.get(t.category_id) : undefined;
          if (c) byTitle.set(searchKey(t.title), c);
        }
        const rules = new MerchantRules(
          transactions.filter((t) => t.category_id && byID.has(t.category_id)).map((t) => ({ title: t.title, categoryName: byID.get(t.category_id!)!.name, date: t.date })),
        );
        setPreview({
          fileName: file.name,
          skipped: result.skippedLines,
          rows: result.rows.map((row) => {
            const kind = row.signedAmount < 0 ? "expense" : "income";
            let category = byTitle.get(searchKey(row.title));
            if (category && category.kind !== kind) category = undefined;
            if (!category && settings.autoCategorize) {
              const names = categories.filter((c) => c.kind === kind).map((c) => c.name);
              const s = rules.suggest(normalizeTitle(row.title), names);
              category = s ? categories.find((c) => c.kind === kind && c.name === s.categoryName) : undefined;
            }
            return { ...row, duplicate: existing.has(duplicateKey(row.date, row.signedAmount, row.title)), categoryID: category?.id ?? null };
          }),
        });
      } catch (error) {
        setPreview(null);
        toast.error("Não foi possível ler o ficheiro", { description: error instanceof Error ? error.message : String(error) });
      }
    });
    return () => {
      active = false;
    };
  }, [file, transactions, categories, settings.autoCategorize]);

  const fresh = preview?.rows.filter((r) => !r.duplicate) ?? [];

  async function importRows() {
    if (!preview) return;
    setBusy(true);
    try {
      for (const row of fresh) {
        await mutate.insert("transactions", {
          id: newID(), title: row.title, amount: Math.abs(row.signedAmount), kind: row.signedAmount < 0 ? "expense" : "income",
          currency_code: currency, date: new Date(row.date.getFullYear(), row.date.getMonth(), row.date.getDate(), 12).toISOString(),
          notes: "", created_at: now(), external_id: "", category_id: row.categoryID, account_id: accountID || null,
        });
      }
      toast.success(`${fresh.length} movimentos importados`);
      setPreview(null);
      setFile(null);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div
        onDragOver={(e) => {
          e.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragging(false);
          const dropped = e.dataTransfer.files[0];
          if (dropped) setFile(dropped);
        }}
        className={cn(
          "flex flex-col items-center gap-3 rounded-[14px] border-2 border-dashed p-8 text-center",
          dragging ? "border-primary bg-primary/10" : "border-input",
        )}
      >
        <FileSpreadsheet size={32} className="text-muted-foreground" aria-hidden="true" />
        <p className="m-0 font-medium">Arrasta o CSV do banco para aqui</p>
        <p className="m-0 text-sm text-muted-foreground">Extratos em português, espanhol ou inglês. Os movimentos repetidos ficam de fora.</p>
        <input ref={input} type="file" accept=".csv,text/csv,text/plain" className="hidden" onChange={(e) => e.target.files?.[0] && setFile(e.target.files[0])} />
        <Button variant="outline" onClick={() => input.current?.click()}><Upload aria-hidden="true" /> Escolher ficheiro CSV</Button>
      </div>

      {preview && (
        <Card
          title="Pré-visualização"
          action={<Button disabled={busy || fresh.length === 0} onClick={() => void importRows()}>Importar {fresh.length} movimentos</Button>}
        >
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Conta">
              {(id) => (
                <Select id={id} value={accountID} onChange={setAccountID}>
                  <option value="">Sem conta</option>
                  {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
                </Select>
              )}
            </Field>
            <Field label="Moeda">{(id) => <Select id={id} value={currency} onChange={setCurrency}><option>EUR</option><option>BRL</option></Select>}</Field>
          </div>
          <dl className="m-0 grid grid-cols-4 gap-3 text-sm">
            <div><dt className="text-muted-foreground">Ficheiro</dt><dd className="m-0 truncate">{preview.fileName}</dd></div>
            <div><dt className="text-muted-foreground">Novos</dt><dd className="m-0 font-semibold">{fresh.length}</dd></div>
            <div><dt className="text-muted-foreground">Já existentes</dt><dd className="m-0">{preview.rows.length - fresh.length}</dd></div>
            <div><dt className="text-muted-foreground">Linhas ignoradas</dt><dd className="m-0">{preview.skipped}</dd></div>
          </dl>
          <ul className="m-0 flex max-h-96 list-none flex-col gap-1 overflow-y-auto p-0">
            {preview.rows.map((r, i) => {
              const category = categories.find((c) => c.id === r.categoryID);
              return (
                <li key={i} className={cn("flex items-center gap-3 rounded-md px-2 py-1.5", r.duplicate && "opacity-50")}>
                  <span className="w-16 text-xs text-muted-foreground">{date(r.date, "short")}</span>
                  <span className="min-w-0 flex-1 truncate">{r.title}</span>
                  <span className="w-28 truncate text-xs text-muted-foreground">{r.duplicate ? "Já existe" : category?.name ?? "Sem categoria"}</span>
                  <span className={cn("tabular w-24 text-right", r.signedAmount > 0 && "text-positive")}>{money(r.signedAmount, currency, { signed: true })}</span>
                </li>
              );
            })}
          </ul>
        </Card>
      )}
    </div>
  );
}

function AccountForm({ account, open, onOpenChange }: { account: AccountRow | null; open: boolean; onOpenChange: (o: boolean) => void }) {
  const [name, setName] = useState("");
  const [type, setType] = useState("checking");
  const [currency, setCurrency] = useState("EUR");
  const [initial, setInitial] = useState<number | null>(0);
  const [archived, setArchived] = useState(false);
  useEffect(() => {
    if (!open) return;
    setName(account?.name ?? "");
    setType(account?.type ?? "checking");
    setCurrency(account?.currency_code ?? "EUR");
    setInitial(account?.initial_balance ?? 0);
    setArchived(account?.is_archived ?? false);
  }, [open, account]);
  const save = async () => {
    const row = { name: name.trim(), type, currency_code: currency, initial_balance: initial ?? 0, is_archived: archived };
    if (account) await mutate.update("accounts", account.id, row);
    else await mutate.insert("accounts", { id: newID(), created_at: now(), ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={account ? "Editar conta" : "Nova conta"} onSubmit={save} valid={name.trim().length > 0}
      onDelete={account ? async () => {
        // Como no iPhone: os movimentos ficam, sem conta.
        await mutate.remove("accounts", [account.id]);
      } : undefined} deleteWhat="esta conta">
      <Field label="Nome">{(id) => <Input id={id} autoFocus value={name} onChange={(e) => setName(e.target.value)} />}</Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Tipo">{(id) => <Select id={id} value={type} onChange={setType}>{Object.entries(accountTypes).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
        <Field label="Moeda">{(id) => <Select id={id} value={currency} onChange={setCurrency}><option>EUR</option><option>BRL</option></Select>}</Field>
      </div>
      <Field label="Saldo inicial">{(id) => <MoneyInput id={id} value={initial} onChange={setInitial} />}</Field>
      {account && (
        <div className="flex items-center gap-2"><Switch id="archived" checked={archived} onCheckedChange={setArchived} /><Label htmlFor="archived">Arquivada</Label></div>
      )}
    </FormDialog>
  );
}

function CategoryForm({ category, open, onOpenChange, nextOrder }: { category: CategoryRow | null; open: boolean; onOpenChange: (o: boolean) => void; nextOrder: number }) {
  const [name, setName] = useState("");
  const [kind, setKind] = useState("expense");
  const [symbol, setSymbol] = useState("tag");
  const [color, setColor] = useState("gray");
  useEffect(() => {
    if (!open) return;
    setName(category?.name ?? "");
    setKind(category?.kind ?? "expense");
    setSymbol(category?.symbol_name ?? "tag");
    setColor(category?.color_name ?? "gray");
  }, [open, category]);
  const save = async () => {
    const row = { name: name.trim(), kind, symbol_name: symbol, color_name: color };
    if (category) await mutate.update("categories", category.id, row);
    else await mutate.insert("categories", { id: newID(), sort_order: nextOrder, monthly_budget: 0, ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={category ? "Editar categoria" : "Nova categoria"} onSubmit={save} valid={name.trim().length > 0}
      onDelete={category ? () => mutate.remove("categories", [category.id]) : undefined} deleteWhat="esta categoria">
      <Field label="Nome">{(id) => <Input id={id} autoFocus value={name} onChange={(e) => setName(e.target.value)} />}</Field>
      <Field label="Tipo">{(id) => <Select id={id} value={kind} onChange={setKind}><option value="expense">Gasto</option><option value="income">Receita</option></Select>}</Field>
      <div className="flex flex-col gap-1.5"><Label>Ícone</Label><SymbolPicker symbols={categorySymbols} value={symbol} onChange={setSymbol} color={color} /></div>
      <div className="flex flex-col gap-1.5"><Label>Cor</Label><ColorPicker value={color} onChange={setColor} /></div>
    </FormDialog>
  );
}

/** Contas (com saldo) e categorias (ícone, cor, tipo). */
export function ManageView() {
  const { categories, allAccounts } = useFinanceBasics();
  const { rows: transactions } = useTable("transactions");
  const [account, setAccount] = useState<AccountRow | null>(null);
  const [accountOpen, setAccountOpen] = useState(false);
  const [category, setCategory] = useState<CategoryRow | null>(null);
  const [categoryOpen, setCategoryOpen] = useState(false);
  const sortedAccounts = useMemo(() => [...allAccounts].sort((a, b) => Number(a.is_archived) - Number(b.is_archived) || a.name.localeCompare(b.name)), [allAccounts]);
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <Card title="Contas" action={<Button size="sm" onClick={() => { setAccount(null); setAccountOpen(true); }}><Plus aria-hidden="true" /> Conta</Button>}>
        {sortedAccounts.length === 0 && <Empty title="Sem contas" />}
        {sortedAccounts.map((a) => (
          <button key={a.id} type="button" onClick={() => { setAccount(a); setAccountOpen(true); }} className={cn("flex items-center justify-between gap-3 text-left", a.is_archived && "opacity-50")}>
            <span className="flex flex-col"><span className="font-medium">{a.name}</span><span className="text-xs text-muted-foreground">{accountTypes[a.type] ?? a.type}{a.is_archived && " · arquivada"}</span></span>
            <span className="tabular font-semibold">{money(accountBalance(a, transactions), a.currency_code)}</span>
          </button>
        ))}
      </Card>
      <Card title="Categorias" action={<Button size="sm" onClick={() => { setCategory(null); setCategoryOpen(true); }}><Plus aria-hidden="true" /> Categoria</Button>}>
        {(["expense", "income"] as const).map((kind) => (
          <div key={kind} className="flex flex-col gap-2">
            <span className="text-xs text-muted-foreground">{kind === "expense" ? "Gastos" : "Receitas"}</span>
            {categories.filter((c) => c.kind === kind).map((c) => (
              <button key={c.id} type="button" onClick={() => { setCategory(c); setCategoryOpen(true); }} className="flex items-center gap-2.5 text-left">
                <SymbolIcon name={c.symbol_name} color={c.color_name} size={28} />{c.name}
              </button>
            ))}
          </div>
        ))}
      </Card>
      <AccountForm account={account} open={accountOpen} onOpenChange={setAccountOpen} />
      <CategoryForm category={category} open={categoryOpen} onOpenChange={setCategoryOpen} nextOrder={categories.length} />
    </div>
  );
}
