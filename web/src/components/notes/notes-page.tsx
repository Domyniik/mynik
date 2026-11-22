"use client";

import { ChevronRight, Download, FilePlus2, MoreHorizontal, Search, Star, Upload } from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { Empty } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { backlinks, builtInTemplates, covers, exportMarkdown, fillTemplate } from "@/lib/calc/notes";
import { searchKey } from "@/lib/calc/search";
import { now } from "@/lib/db/client";
import type { NoteRow } from "@/lib/db/schema";
import { mutate, useTables } from "@/lib/db/store";
import { cn } from "@/lib/utils";
import { BlockEditor } from "./block-editor";
import { DatabaseView } from "./database-view";
import { copyNote, createDatabase, createNote, deleteNoteTree, instantiateTemplate } from "./note-actions";
import { importNotion } from "./notion-import";

const title = (n: NoteRow) => n.title.trim() || "Sem título";

function TreeItem({ note, notes, depth, selected, go }: { note: NoteRow; notes: NoteRow[]; depth: number; selected: string | null; go: (id: string) => void }) {
  const children = note.is_database ? [] : notes.filter((n) => n.parent_id === note.id && !n.is_template).sort((a, b) => a.sort_order - b.sort_order);
  const [open, setOpen] = useState(depth === 0 && children.length > 0 && children.some((c) => c.id === selected));
  return (
    <div>
      <div className={cn("flex items-center rounded-md pr-1", selected === note.id ? "bg-sidebar-active text-white" : "hover:bg-sidebar-active/60")} style={{ paddingLeft: depth * 12 }}>
        <button type="button" aria-label={open ? "Fechar" : "Abrir"} aria-expanded={open} className={cn("p-1 text-muted-foreground", !children.length && "invisible")} onClick={() => setOpen(!open)}>
          <ChevronRight size={13} className={cn("transition-transform", open && "rotate-90")} />
        </button>
        <button type="button" onClick={() => go(note.id)} className="flex min-w-0 flex-1 items-center gap-1.5 py-1 text-left text-sm">
          <span aria-hidden="true">{note.icon}</span><span className="truncate">{title(note)}</span>
        </button>
      </div>
      {open && children.map((c) => <TreeItem key={c.id} note={c} notes={notes} depth={depth + 1} selected={selected} go={go} />)}
    </div>
  );
}

function Notes() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const { data } = useTables("notes", "note_blocks", "projects", "transactions");
  const notes = data.notes;
  const [query, setQuery] = useState("");
  const [importing, setImporting] = useState(false);
  const importInput = useRef<HTMLInputElement>(null);
  const selectedID = params.get("id");
  const note = notes.find((n) => n.id === selectedID) ?? null;
  const go = (id: string) => router.push(`${pathname}?id=${id}`);
  const blocks = useMemo(() => (note ? data.note_blocks.filter((b) => b.note_id === note.id) : []), [data.note_blocks, note]);

  const create = async (kind: "page" | "database" | "sub") => {
    const created = kind === "database" ? await createDatabase(notes, null) : await createNote(notes, { parent_id: kind === "sub" ? note?.id ?? null : null });
    go(created.id);
  };

  useEffect(() => {
    if (params.get("novo")) void create("page");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params]);

  // ⇧⌘F: favorito da página aberta.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === "f" && note) {
        e.preventDefault();
        void mutate.update("notes", note.id, { is_favorite: !note.is_favorite });
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [note]);

  const results = useMemo(() => {
    const q = searchKey(query);
    if (q.length < 2) return [];
    const text = new Map<string, string>();
    for (const b of data.note_blocks) text.set(b.note_id ?? "", `${text.get(b.note_id ?? "") ?? ""} ${b.text}`);
    return notes.filter((n) => searchKey(`${n.title} ${text.get(n.id) ?? ""}`).includes(q)).slice(0, 30);
  }, [query, notes, data.note_blocks]);

  const roots = notes.filter((n) => !n.parent_id && !n.is_template).sort((a, b) => a.sort_order - b.sort_order || a.created_at.localeCompare(b.created_at));
  const favorites = notes.filter((n) => n.is_favorite && !n.is_template);
  const templates = notes.filter((n) => n.is_template);
  const ancestors: NoteRow[] = [];
  for (let p = note?.parent_id ? notes.find((n) => n.id === note.parent_id) : undefined; p && !ancestors.includes(p); p = p.parent_id ? notes.find((n) => n.id === p!.parent_id) : undefined) ancestors.unshift(p);
  const children = note && !note.is_database ? notes.filter((n) => n.parent_id === note.id).sort((a, b) => a.sort_order - b.sort_order) : [];
  const linkedProjects = note ? data.projects.filter((p) => note.linked_project_ids.includes(p.id)) : [];
  const linkedTransactions = note ? data.transactions.filter((t) => note.linked_transaction_ids.includes(t.id)) : [];
  const incoming = note ? backlinks(note, notes, data.note_blocks) : [];

  const exportMD = () => {
    if (!note) return;
    const blob = new Blob([exportMarkdown(note.title, blocks)], { type: "text/markdown" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${title(note).replace(/[\\/:*?"<>|]/g, "-")}.md`;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  return (
    <div className="-mx-9 -mt-7 flex min-h-[calc(100dvh)]">
      <aside aria-label="Páginas" className="flex w-64 shrink-0 flex-col gap-3 border-r border-border bg-sidebar/60 p-3">
        <label className="flex h-8 items-center gap-2 rounded-md border border-input bg-input/30 px-2 text-muted-foreground">
          <Search size={14} aria-hidden="true" />
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Procurar nas notas" aria-label="Procurar nas notas" className="flex-1 bg-transparent text-sm text-foreground outline-none" />
        </label>
        <div className="flex gap-1.5">
          <Button size="sm" className="flex-1" onClick={() => void create("page")}><FilePlus2 aria-hidden="true" /> Página</Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild><Button size="sm" variant="outline" aria-label="Mais"><MoreHorizontal /></Button></DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuItem onSelect={() => void create("database")}>Nova base de dados</DropdownMenuItem>
              <DropdownMenuSeparator />
              {builtInTemplates.map((t) => <DropdownMenuItem key={t.id} onSelect={async () => go((await instantiateTemplate(t, notes, null)).id)}>{t.icon} {fillTemplate(t.title)}</DropdownMenuItem>)}
              {templates.map((t) => <DropdownMenuItem key={t.id} onSelect={async () => go((await copyNote(t, data.note_blocks, notes, false, null)).id)}>{t.icon} {fillTemplate(title(t))}</DropdownMenuItem>)}
              <DropdownMenuSeparator />
              <DropdownMenuItem onSelect={() => importInput.current?.click()}><Upload aria-hidden="true" /> Importar do Notion…</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <input ref={importInput} type="file" accept=".zip,application/zip" className="hidden" onChange={async (e) => {
            const file = e.target.files?.[0];
            if (!file) return;
            setImporting(true);
            try {
              const r = await importNotion(file, notes, null);
              toast.success(`Importado do Notion: ${r.pages} páginas, ${r.images} imagens`);
            } catch (error) {
              toast.error("Não foi possível importar", { description: error instanceof Error ? error.message : String(error) });
            } finally {
              setImporting(false);
              e.target.value = "";
            }
          }} />
        </div>
        {importing && <p className="m-0 text-xs text-muted-foreground" role="status">A importar do Notion…</p>}
        <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto">
          {query.trim().length >= 2 ? (
            <section><h2 className="m-0 px-1 pb-1 text-xs text-muted-foreground">Resultados</h2>
              {results.map((n) => <button key={n.id} type="button" onClick={() => go(n.id)} className="block w-full truncate rounded px-2 py-1 text-left text-sm hover:bg-sidebar-active/60">{n.icon} {title(n)}</button>)}
              {results.length === 0 && <p className="m-0 px-2 text-sm text-muted-foreground">Sem resultados</p>}
            </section>
          ) : (
            <>
              {favorites.length > 0 && (
                <section><h2 className="m-0 px-1 pb-1 text-xs text-muted-foreground">Favoritos</h2>
                  {favorites.map((n) => <button key={n.id} type="button" onClick={() => go(n.id)} className={cn("block w-full truncate rounded px-2 py-1 text-left text-sm", n.id === selectedID ? "bg-sidebar-active" : "hover:bg-sidebar-active/60")}>{n.icon} {title(n)}</button>)}
                </section>
              )}
              <section><h2 className="m-0 px-1 pb-1 text-xs text-muted-foreground">Páginas</h2>
                {roots.map((n) => <TreeItem key={n.id} note={n} notes={notes} depth={0} selected={selectedID} go={go} />)}
              </section>
              {templates.length > 0 && (
                <section><h2 className="m-0 px-1 pb-1 text-xs text-muted-foreground">Os meus templates</h2>
                  {templates.map((n) => <button key={n.id} type="button" onClick={() => go(n.id)} className="block w-full truncate rounded px-2 py-1 text-left text-sm hover:bg-sidebar-active/60">{n.icon} {title(n)}</button>)}
                </section>
              )}
            </>
          )}
        </div>
      </aside>

      <article className="min-w-0 flex-1">
        {!note ? (
          <div className="p-10"><Empty title="Escolhe ou cria uma página">⌘N cria uma página nova. Os templates estão no menu “…”.</Empty></div>
        ) : (
          <>
            {note.cover && covers[note.cover] && <div className="h-40 w-full" style={{ background: covers[note.cover].css }} role="img" aria-label={`Capa ${covers[note.cover].title}`} />}
            <div className="mx-auto flex max-w-3xl flex-col gap-4 px-10 py-8">
              <nav aria-label="Caminho" className="flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
                {ancestors.map((a) => <span key={a.id} className="flex items-center gap-1"><Link href={`/notas/?id=${a.id}`} className="text-muted-foreground">{a.icon} {title(a)}</Link><ChevronRight size={12} /></span>)}
              </nav>
              <div className="flex items-start gap-3">
                <button type="button" aria-label="Ícone da página" className="text-5xl leading-none" onClick={() => { const e = prompt("Emoji da página", note.icon)?.trim(); if (e) void mutate.update("notes", note.id, { icon: e }); }}>{note.icon}</button>
                <div className="ml-auto flex items-center gap-1">
                  <Button variant="ghost" size="icon" aria-pressed={note.is_favorite} aria-label="Favorito (⇧⌘F)" onClick={() => void mutate.update("notes", note.id, { is_favorite: !note.is_favorite })}>
                    <Star className={note.is_favorite ? "fill-warning text-warning" : ""} aria-hidden="true" />
                  </Button>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild><Button variant="ghost" size="icon" aria-label="Opções da página"><MoreHorizontal /></Button></DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem onSelect={() => void create("sub")}>Nova subpágina</DropdownMenuItem>
                      <DropdownMenuItem onSelect={async () => go((await createDatabase(notes, note.id)).id)}>Nova base de dados aqui</DropdownMenuItem>
                      {Object.entries(covers).map(([k, c]) => <DropdownMenuItem key={k} onSelect={() => void mutate.update("notes", note.id, { cover: k })}>Capa: {c.title}</DropdownMenuItem>)}
                      {note.cover && <DropdownMenuItem onSelect={() => void mutate.update("notes", note.id, { cover: "" })}>Remover capa</DropdownMenuItem>}
                      <DropdownMenuSeparator />
                      {note.is_template
                        ? <DropdownMenuItem onSelect={async () => go((await copyNote(note, data.note_blocks, notes, false, null)).id)}>Nova página a partir deste template</DropdownMenuItem>
                        : <DropdownMenuItem onSelect={async () => { await copyNote(note, data.note_blocks, notes, true, null); toast.success("Guardado como template"); }}>Guardar como template</DropdownMenuItem>}
                      <DropdownMenuItem onSelect={exportMD}><Download aria-hidden="true" /> Exportar Markdown</DropdownMenuItem>
                      <DropdownMenuSeparator />
                      <DropdownMenuItem className="text-danger" onSelect={async () => {
                        if (!confirm("Apagar esta página e as subpáginas? Apaga também no iPhone.")) return;
                        await deleteNoteTree(note, notes, data.note_blocks);
                        router.push(note.parent_id ? `${pathname}?id=${note.parent_id}` : pathname);
                      }}>Apagar página</DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </div>
              <input
                key={note.id}
                defaultValue={note.title}
                placeholder="Sem título"
                aria-label="Título"
                onBlur={(e) => e.target.value !== note.title && void mutate.update("notes", note.id, { title: e.target.value, edited_at: now() })}
                className="bg-transparent text-[34px] font-bold tracking-tight outline-none"
              />
              {note.is_template && <p className="m-0 rounded-md bg-surface px-3 py-2 text-sm text-muted-foreground">Template: {"{{data}}"} no título é trocado pela data quando se cria uma página.</p>}
              {note.is_database ? <DatabaseView database={note} notes={notes} /> : <BlockEditor key={note.id} note={note} blocks={blocks} />}

              {children.length > 0 && (
                <section className="flex flex-col gap-1 border-t border-border pt-3"><h2 className="m-0 text-sm text-muted-foreground">Subpáginas</h2>
                  {children.map((c) => <Link key={c.id} href={`/notas/?id=${c.id}`}>{c.icon} {title(c)}</Link>)}
                </section>
              )}

              <section className="flex flex-col gap-2 border-t border-border pt-3">
                <div className="flex items-center justify-between"><h2 className="m-0 text-sm text-muted-foreground">Ligações</h2>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild><Button variant="ghost" size="sm">Ligar a…</Button></DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="max-h-80 overflow-y-auto">
                      {data.projects.filter((p) => !note.linked_project_ids.includes(p.id)).map((p) => (
                        <DropdownMenuItem key={p.id} onSelect={() => void mutate.update("notes", note.id, { linked_project_ids: [...note.linked_project_ids, p.id] })}>Projeto · {p.name}</DropdownMenuItem>
                      ))}
                      {[...data.transactions].sort((a, b) => b.date.localeCompare(a.date)).slice(0, 25).filter((t) => !note.linked_transaction_ids.includes(t.id)).map((t) => (
                        <DropdownMenuItem key={t.id} onSelect={() => void mutate.update("notes", note.id, { linked_transaction_ids: [...note.linked_transaction_ids, t.id] })}>Movimento · {t.title}</DropdownMenuItem>
                      ))}
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
                {linkedProjects.map((p) => (
                  <div key={p.id} className="flex justify-between text-sm"><Link href={`/projetos/?projeto=${p.id}`}>Projeto · {p.name}</Link>
                    <button type="button" className="text-xs text-muted-foreground" onClick={() => void mutate.update("notes", note.id, { linked_project_ids: note.linked_project_ids.filter((x) => x !== p.id) })}>Remover ligação</button></div>
                ))}
                {linkedTransactions.map((t) => (
                  <div key={t.id} className="flex justify-between text-sm"><Link href={`/financas/?editar=${t.id}`}>Movimento · {t.title}</Link>
                    <button type="button" className="text-xs text-muted-foreground" onClick={() => void mutate.update("notes", note.id, { linked_transaction_ids: note.linked_transaction_ids.filter((x) => x !== t.id) })}>Remover ligação</button></div>
                ))}
                {incoming.length > 0 && <span className="text-xs text-muted-foreground">Menciona esta página</span>}
                {incoming.map((n) => <Link key={n.id} href={`/notas/?id=${n.id}`} className="text-sm">{n.icon} {title(n)}</Link>)}
                {linkedProjects.length + linkedTransactions.length + incoming.length === 0 && <p className="m-0 text-sm text-muted-foreground">Sem ligações. Escreve @ para mencionar páginas, projetos, movimentos e datas.</p>}
              </section>
            </div>
          </>
        )}
      </article>
    </div>
  );
}

export default function NotesPage() {
  return (
    <Suspense>
      <Notes />
    </Suspense>
  );
}
