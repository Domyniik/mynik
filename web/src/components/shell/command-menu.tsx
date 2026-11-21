"use client";

import { FilePlus2, ListPlus, Plus, Receipt } from "lucide-react";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command";
import { collect, rank } from "@/lib/calc/search";
import { useTables } from "@/lib/db/store";
import { date, money } from "@/lib/format";
import { allSections } from "./nav";

const actions = [
  { label: "Novo gasto", href: "/financas/?novo=gasto", icon: Receipt, keywords: "despesa movimento" },
  { label: "Nova receita", href: "/financas/?novo=receita", icon: Plus, keywords: "movimento entrada" },
  { label: "Nova conta a pagar", href: "/financas/?tab=contas&novo=1", icon: Receipt, keywords: "fatura recorrente" },
  { label: "Nova tarefa", href: "/projetos/?novo=1", icon: ListPlus, keywords: "kanban projeto" },
  { label: "Nova página", href: "/notas/?novo=1", icon: FilePlus2, keywords: "nota documento" },
  { label: "Importar CSV do banco", href: "/financas/?tab=importar", icon: FilePlus2, keywords: "extrato" },
];

/** Resultados nos dados (só carrega as tabelas quando há pesquisa). */
function DataResults({ query, go }: { query: string; go: (href: string) => void }) {
  const { data } = useTables(
    "transactions", "bills", "notes", "note_blocks", "projects", "tasks", "goals", "habits", "vehicles",
    "documents", "job_applications", "courses", "investments", "store_products",
  );
  const results = useMemo(() => {
    const textByNote = new Map<string, string>();
    for (const b of data.note_blocks) textByNote.set(b.note_id ?? "", `${textByNote.get(b.note_id ?? "") ?? ""} ${b.text}`);
    const projectName = new Map(data.projects.map((p) => [p.id, p.name]));
    return collect(query, [
      ...data.transactions.map((t) => ({
        id: `tx-${t.id}`, title: t.title, subtitle: `${money(t.kind === "expense" ? -t.amount : t.amount, t.currency_code)} · ${date(t.date)}`,
        href: `/financas/?editar=${t.id}`, fields: [t.title, t.notes],
      })),
      ...data.bills.map((b) => ({ id: `bill-${b.id}`, title: b.title, subtitle: `Conta a pagar · ${money(b.amount, b.currency_code)}`, href: "/financas/?tab=contas", fields: [b.title, b.notes] })),
      ...data.notes.map((n) => ({ id: `note-${n.id}`, title: n.title || "Sem título", subtitle: "Nota", href: `/notas/?id=${n.id}`, fields: [n.title || "Sem título", textByNote.get(n.id) ?? ""] })),
      ...data.projects.map((p) => ({ id: `prj-${p.id}`, title: p.name, subtitle: "Projeto", href: `/projetos/?projeto=${p.id}`, fields: [p.name] })),
      ...data.tasks.map((t) => ({ id: `task-${t.id}`, title: t.title, subtitle: t.project_id ? `Tarefa · ${projectName.get(t.project_id) ?? ""}` : "Tarefa", href: `/projetos/?projeto=${t.project_id ?? "avulsas"}`, fields: [t.title, t.notes] })),
      ...data.goals.map((g) => ({ id: `goal-${g.id}`, title: g.title, subtitle: "Meta", href: `/metas/?id=${g.id}`, fields: [g.title] })),
      ...data.habits.filter((h) => !h.is_archived).map((h) => ({ id: `hab-${h.id}`, title: h.name, subtitle: "Hábito", href: "/habitos/", fields: [h.name] })),
      ...data.vehicles.map((v) => ({ id: `car-${v.id}`, title: v.name || "Carro", subtitle: "Carro", href: `/carro/?veiculo=${v.id}`, fields: [v.name, v.plate] })),
      // Os números dos documentos nunca entram na busca (ficam atrás do bloqueio).
      ...data.documents.map((d) => ({ id: `doc-${d.id}`, title: d.title || "Documento", subtitle: "Documento", href: `/documentos/?id=${d.id}`, fields: [d.title, d.kind] })),
      ...data.job_applications.map((a) => ({ id: `job-${a.id}`, title: `${a.company} — ${a.role}`, subtitle: "Candidatura", href: "/carreira/", fields: [a.company, a.role] })),
      ...data.courses.map((c) => ({ id: `crs-${c.id}`, title: c.title, subtitle: "Curso", href: "/carreira/?tab=cursos", fields: [c.title, c.provider] })),
      ...data.investments.map((i) => ({ id: `inv-${i.id}`, title: i.name, subtitle: "Investimento", href: "/patrimonio/", fields: [i.name, i.ticker] })),
      ...data.store_products.map((p) => ({ id: `prd-${p.id}`, title: p.title, subtitle: "Produto da loja", href: `/loja/?produto=${encodeURIComponent(p.id)}`, fields: [p.title] })),
    ]);
  }, [data, query]);

  if (results.length === 0) return null;
  return (
    <CommandGroup heading="Resultados">
      {results.map((r) => (
        <CommandItem key={r.id} value={r.id} onSelect={() => go(r.href)}>
          <div className="flex min-w-0 flex-col">
            <span className="truncate">{r.title}</span>
            <span className="truncate text-xs text-muted-foreground">{r.subtitle}</span>
          </div>
        </CommandItem>
      ))}
    </CommandGroup>
  );
}

/** ⌘K: ir para uma secção, executar uma ação ou procurar em todos os dados. */
export function CommandMenu({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const go = (href: string) => {
    onOpenChange(false);
    setQuery("");
    router.push(href);
  };
  const sectionMatches = allSections.filter((s) => !query || rank(query, [s.title]) != null);
  const actionMatches = actions.filter((a) => !query || rank(query, [a.label, a.keywords]) != null);

  return (
    <CommandDialog
      open={open}
      onOpenChange={onOpenChange}
      shouldFilter={false}
      title="Procurar no Mynik"
      description="Secções, ações e todos os teus dados"
    >
      <CommandInput placeholder="Procurar ou executar ação…" value={query} onValueChange={setQuery} />
      <CommandList>
        <CommandEmpty>Sem resultados.</CommandEmpty>
        {actionMatches.length > 0 && (
          <CommandGroup heading="Ações">
            {actionMatches.map((a) => (
              <CommandItem key={a.href} value={`a-${a.href}`} onSelect={() => go(a.href)}>
                <a.icon aria-hidden="true" />
                {a.label}
              </CommandItem>
            ))}
          </CommandGroup>
        )}
        {sectionMatches.length > 0 && (
          <CommandGroup heading="Ir para">
            {sectionMatches.map((s, i) => (
              <CommandItem key={s.href} value={`s-${s.href}`} onSelect={() => go(s.href)}>
                <s.icon aria-hidden="true" />
                {s.title}
                {i < 9 && !query && <span className="ml-auto text-xs text-muted-foreground">⌘{i + 1}</span>}
              </CommandItem>
            ))}
          </CommandGroup>
        )}
        {open && query.trim().length >= 2 && <DataResults query={query} go={go} />}
      </CommandList>
    </CommandDialog>
  );
}
