"use client";

import { Plus } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { TabBar } from "@/components/common/fields";
import { PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import type { TransactionRow } from "@/lib/db/schema";
import { useTable } from "@/lib/db/store";
import { BillsView, SubscriptionsView } from "./bills";
import { BudgetView, ReportsView } from "./budget-reports";
import { ImportView, ManageView } from "./import-manage";
import { TransactionForm, type TransactionKind } from "./transaction-form";
import { TransactionsView } from "./transactions-view";

const tabs = [
  { value: "movimentos", label: "Movimentos" },
  { value: "contas", label: "Contas a pagar" },
  { value: "orcamento", label: "Orçamento" },
  { value: "assinaturas", label: "Assinaturas" },
  { value: "relatorios", label: "Relatórios" },
  { value: "importar", label: "Importar CSV" },
  { value: "gerir", label: "Contas e categorias" },
] as const;
type Tab = (typeof tabs)[number]["value"];

function Finance() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const tab = (tabs.some((t) => t.value === params.get("tab")) ? params.get("tab") : "movimentos") as Tab;
  const { rows: transactions } = useTable("transactions");
  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<TransactionRow | null>(null);
  const [kind, setKind] = useState<TransactionKind>("expense");
  const [dropped, setDropped] = useState<File | null>(null);

  const setTab = (value: Tab) => router.replace(`${pathname}?tab=${value}`);

  // ?novo=gasto|receita|1 (⌘N, ⌘K) e ?editar=<id> (busca).
  useEffect(() => {
    const novo = params.get("novo");
    if (novo && tab === "movimentos") {
      setEditing(null);
      setKind(novo === "receita" ? "income" : "expense");
      setFormOpen(true);
      router.replace(`${pathname}?tab=movimentos`);
    }
    const id = params.get("editar");
    const target = id && transactions.find((t) => t.id === id);
    if (target) {
      setEditing(target);
      setFormOpen(true);
      router.replace(`${pathname}?tab=movimentos`);
    }
  }, [params, tab, transactions, router, pathname]);

  return (
    <div
      className="flex flex-col gap-6"
      onDragOver={(e) => {
        if ([...e.dataTransfer.items].some((i) => i.kind === "file")) e.preventDefault();
      }}
      onDrop={(e) => {
        const file = e.dataTransfer.files[0];
        if (!file || !/\.(csv|txt)$/i.test(file.name)) return;
        e.preventDefault();
        setDropped(file);
        setTab("importar");
      }}
    >
      <PageHeader
        title="Finanças"
        subtitle="Gastos, receitas, contas a pagar e orçamento"
        actions={
          <>
            <Button variant="outline" onClick={() => { setEditing(null); setKind("income"); setFormOpen(true); }}>Nova receita</Button>
            <Button onClick={() => { setEditing(null); setKind("expense"); setFormOpen(true); }}><Plus aria-hidden="true" /> Novo gasto</Button>
          </>
        }
      />
      <TabBar tabs={[...tabs]} value={tab} onChange={setTab} />
      {tab === "movimentos" && <TransactionsView onEdit={(t) => { setEditing(t); setFormOpen(true); }} />}
      {tab === "contas" && <BillsView openNew={params.get("novo") === "1"} />}
      {tab === "orcamento" && <BudgetView />}
      {tab === "assinaturas" && <SubscriptionsView />}
      {tab === "relatorios" && <ReportsView />}
      {tab === "importar" && <ImportView droppedFile={dropped} />}
      {tab === "gerir" && <ManageView />}
      <TransactionForm open={formOpen} onOpenChange={setFormOpen} transaction={editing} initialKind={kind} />
    </div>
  );
}

export default function FinancePage() {
  return (
    <Suspense>
      <Finance />
    </Suspense>
  );
}
