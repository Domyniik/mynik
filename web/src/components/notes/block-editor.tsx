"use client";

import { DndContext, type DragEndEvent, KeyboardSensor, PointerSensor, closestCenter, useSensor, useSensors } from "@dnd-kit/core";
import { SortableContext, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { ChevronRight, Copy, GripVertical, ImagePlus, Plus, Trash2 } from "lucide-react";
import Link from "next/link";
import { type KeyboardEvent, type ReactNode, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { Checkbox } from "@/components/ui/checkbox";
import {
  activeMentionQuery, type BlockKind, blockKinds, continuesOnReturn, dateLabel, dayValue, kindOrder, matchingKinds, mentionToken,
  parseTable, serializeTable, shortcut,
} from "@/lib/calc/notes";
import { searchKey } from "@/lib/calc/search";
import { newID, now } from "@/lib/db/client";
import type { NoteBlockRow, NoteRow } from "@/lib/db/schema";
import { mutate, useTables } from "@/lib/db/store";
import { cn } from "@/lib/utils";

/** ⌥⌘0–8: texto, títulos 1–3, tarefa, marcas, numerada, alternar, código (como no iPhone). */
const transformKeys: BlockKind[] = ["text", "heading", "heading2", "heading3", "checklist", "bulleted", "numbered", "toggle", "code"];

const textClass: Record<string, string> = {
  heading: "text-[26px] font-bold leading-tight", heading2: "text-xl font-semibold", heading3: "text-lg font-semibold",
  quote: "italic", code: "font-mono text-[13px]",
};

/** Texto com links e menções clicáveis (quando o bloco não tem o foco). */
function Inline({ text }: { text: string }) {
  const parts: ReactNode[] = [];
  const re = /\[(@?[^\]]+)\]\((mynik:\/\/(note|project|transaction|date)\/([^)]+)|https?:\/\/[^)]+)\)|\[\[([^[\]\n]+)\]\]|\*\*([^*]+)\*\*|`([^`]+)`/g;
  let last = 0;
  for (const m of text.matchAll(re)) {
    if (m.index! > last) parts.push(text.slice(last, m.index));
    if (m[2]?.startsWith("mynik://")) {
      const [kind, id] = [m[3], decodeURIComponent(m[4])];
      const href = kind === "note" ? `/notas/?id=${id}` : kind === "project" ? `/projetos/?projeto=${id}` : kind === "transaction" ? `/financas/?editar=${id}` : `/notas/?dia=${id}`;
      parts.push(<Link key={m.index} href={href} onClick={(e) => e.stopPropagation()} className="rounded bg-primary/15 px-1 no-underline">{m[1]}</Link>);
    } else if (m[2]) parts.push(<a key={m.index} href={m[2]} target="_blank" rel="noreferrer" onClick={(e) => e.stopPropagation()}>{m[1]}</a>);
    else if (m[5]) parts.push(<span key={m.index} className="text-link">[[{m[5]}]]</span>);
    else if (m[6]) parts.push(<strong key={m.index}>{m[6]}</strong>);
    else if (m[7]) parts.push(<code key={m.index} className="rounded bg-surface px-1 font-mono text-[0.9em]">{m[7]}</code>);
    last = m.index! + m[0].length;
  }
  if (last < text.length) parts.push(text.slice(last));
  return <>{parts.length ? parts : <span className="text-muted-foreground/60">Escreve, ou &quot;/&quot; para blocos e &quot;@&quot; para menções</span>}</>;
}

interface Suggestion { label: string; hint: string; token: string }

function useMentionSuggestions(query: string | null): Suggestion[] {
  const { data } = useTables("notes", "projects", "transactions");
  return useMemo(() => {
    if (query == null) return [];
    const q = searchKey(query);
    const today = new Date();
    const tomorrow = new Date(Date.now() + 86_400_000);
    const dates = [{ label: "Hoje", d: today }, { label: "Amanhã", d: tomorrow }].filter((x) => !q || searchKey(x.label).startsWith(q))
      .map((x) => ({ label: `${x.label} · ${dateLabel(x.d)}`, hint: "Data", token: mentionToken(dateLabel(x.d), "date", dayValue(x.d)) }));
    const match = (t: string) => !q || searchKey(t).includes(q);
    return [
      ...data.notes.filter((n) => !n.is_template && match(n.title || "Sem título")).slice(0, 6).map((n) => ({ label: `${n.icon} ${n.title || "Sem título"}`, hint: "Página", token: mentionToken(n.title || "Sem título", "note", n.id) })),
      ...data.projects.filter((p) => match(p.name)).slice(0, 4).map((p) => ({ label: p.name, hint: "Projeto", token: mentionToken(p.name, "project", p.id) })),
      ...data.transactions.filter((t) => q.length >= 2 && match(t.title)).slice(0, 4).map((t) => ({ label: t.title, hint: "Movimento", token: mentionToken(t.title, "transaction", t.id) })),
      ...dates,
    ];
  }, [query, data]);
}

function AutoTextarea({ value, onChange, onKeyDown, onBlur, className, autoFocus, inputRef, placeholder, ariaLabel }: {
  value: string; onChange: (v: string, caret: number) => void; onKeyDown?: (e: KeyboardEvent<HTMLTextAreaElement>) => void; onBlur?: () => void;
  className?: string; autoFocus?: boolean; inputRef?: (el: HTMLTextAreaElement | null) => void; placeholder?: string; ariaLabel?: string;
}) {
  const ref = useRef<HTMLTextAreaElement | null>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = "0px";
    el.style.height = `${el.scrollHeight}px`;
  }, [value]);
  return (
    <textarea
      ref={(el) => {
        ref.current = el;
        inputRef?.(el);
      }}
      rows={1}
      autoFocus={autoFocus}
      value={value}
      placeholder={placeholder}
      aria-label={ariaLabel}
      onChange={(e) => onChange(e.target.value, e.target.selectionStart)}
      onKeyDown={onKeyDown}
      onBlur={onBlur}
      className={cn("w-full resize-none overflow-hidden bg-transparent outline-none", className)}
    />
  );
}

function TableBlock({ block, save }: { block: NoteBlockRow; save: (patch: Partial<NoteBlockRow>) => void }) {
  const [rows, setRows] = useState(() => parseTable(block.text));
  useEffect(() => setRows(parseTable(block.text)), [block.text]);
  const commit = (next: string[][]) => {
    setRows(next);
    save({ text: serializeTable(next) });
  };
  return (
    <div className="flex flex-col gap-1 overflow-x-auto">
      <table className="border-collapse text-sm">
        <tbody>
          {rows.map((row, r) => (
            <tr key={r}>
              {row.map((cell, c) => (
                <td key={c} className="border border-border p-0">
                  <input value={cell} aria-label={`Linha ${r + 1}, coluna ${c + 1}`} className={cn("w-full bg-transparent px-2 py-1 outline-none", r === 0 && "font-semibold")}
                    onChange={(e) => setRows(rows.map((x, i) => (i === r ? x.map((y, j) => (j === c ? e.target.value : y)) : x)))} onBlur={() => commit(rows)} />
                </td>
              ))}
              <td className="pl-1"><button type="button" aria-label="Apagar linha" className="text-muted-foreground" onClick={() => rows.length > 1 && commit(rows.filter((_, i) => i !== r))}><Trash2 size={13} /></button></td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="flex gap-3 text-xs">
        <button type="button" className="text-link" onClick={() => commit([...rows, rows[0].map(() => "")])}>+ Linha</button>
        <button type="button" className="text-link" onClick={() => commit(rows.map((r) => [...r, ""]))}>+ Coluna</button>
      </div>
    </div>
  );
}

/** Reduz a imagem (máx. 1600 px, JPEG) antes de a guardar na nota, como o iPhone. */
async function downsample(file: File): Promise<string> {
  const bitmap = await createImageBitmap(file);
  const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d")!.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/jpeg", 0.8).split(",")[1];
}

function BlockRow({ block, index, blocks, number, focused, setFocused, api }: {
  block: NoteBlockRow; index: number; blocks: NoteBlockRow[]; number: number; focused: boolean; setFocused: (id: string | null) => void;
  api: { insertAfter: (b: NoteBlockRow, kind: BlockKind, text?: string) => void; remove: (b: NoteBlockRow, focusPrev?: boolean) => void; move: (b: NoteBlockRow, delta: number) => void; duplicate: (b: NoteBlockRow) => void; refs: Map<string, HTMLTextAreaElement> };
}) {
  const { attributes, listeners, setNodeRef, transform, transition } = useSortable({ id: block.id });
  const [text, setText] = useState(block.text);
  const [menuQuery, setMenuQuery] = useState<string | null>(null);
  const [menuIndex, setMenuIndex] = useState(0);
  const [mention, setMention] = useState<string | null>(null);
  const [mentionIndex, setMentionIndex] = useState(0);
  const suggestions = useMentionSuggestions(mention);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => {
    if (!focused) setText(block.text);
  }, [block.text, focused]);

  const save = (patch: Partial<NoteBlockRow>) => void mutate.update("note_blocks", block.id, patch);
  const saveText = (value: string, immediate = false) => {
    clearTimeout(timer.current);
    if (immediate) save({ text: value });
    else timer.current = setTimeout(() => save({ text: value }), 450);
  };
  const transform_ = (kind: BlockKind) => {
    setMenuQuery(null);
    save({ kind, text: kind === "divider" || kind === "image" ? "" : text.startsWith("/") ? "" : text });
    if (text.startsWith("/")) setText("");
    if (kind === "divider") api.insertAfter(block, "text");
  };
  const kinds = menuQuery != null ? matchingKinds(menuQuery) : [];

  const onChange = (value: string, caret: number) => {
    if (block.kind === "text" && !value.includes("\n")) {
      const s = shortcut(value);
      if (s && (value.endsWith(" ") || value === "---" || value.startsWith("```"))) {
        setText(s.text);
        save({ kind: s.kind, text: s.text, is_checked: s.isChecked ?? false, ...(s.language != null ? { language: s.language } : {}) });
        if (s.kind === "divider") api.insertAfter(block, "text");
        return;
      }
    }
    setText(value);
    setMenuQuery(value.startsWith("/") && !value.includes(" ") ? value.slice(1) : null);
    setMenuIndex(0);
    const q = activeMentionQuery(value, caret);
    setMention(q);
    setMentionIndex(0);
    saveText(value);
  };

  const pickMention = (s: Suggestion) => {
    const el = api.refs.get(block.id);
    const caret = el?.selectionStart ?? text.length;
    const before = text.slice(0, caret).replace(/@[^\s@[\]()]*$/, "");
    const value = `${before}${s.token} ${text.slice(caret)}`;
    setText(value);
    setMention(null);
    saveText(value, true);
  };

  const onKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    const mod = e.metaKey || e.ctrlKey;
    if (menuQuery != null && kinds.length) {
      if (e.key === "ArrowDown") { e.preventDefault(); setMenuIndex((i) => (i + 1) % kinds.length); return; }
      if (e.key === "ArrowUp") { e.preventDefault(); setMenuIndex((i) => (i - 1 + kinds.length) % kinds.length); return; }
      if (e.key === "Enter") { e.preventDefault(); transform_(kinds[menuIndex]); return; }
      if (e.key === "Escape") { setMenuQuery(null); return; }
    }
    if (mention != null && suggestions.length) {
      if (e.key === "ArrowDown") { e.preventDefault(); setMentionIndex((i) => (i + 1) % suggestions.length); return; }
      if (e.key === "ArrowUp") { e.preventDefault(); setMentionIndex((i) => (i - 1 + suggestions.length) % suggestions.length); return; }
      if (e.key === "Enter" || e.key === "Tab") { e.preventDefault(); pickMention(suggestions[mentionIndex]); return; }
      if (e.key === "Escape") { setMention(null); return; }
    }
    if (mod && e.shiftKey && (e.key === "ArrowUp" || e.key === "ArrowDown")) { e.preventDefault(); api.move(block, e.key === "ArrowUp" ? -1 : 1); return; }
    if (mod && !e.shiftKey && e.key.toLowerCase() === "d") { e.preventDefault(); api.duplicate(block); return; }
    if (mod && e.shiftKey && e.key === "Backspace") { e.preventDefault(); api.remove(block, true); return; }
    if (mod && e.altKey && /^Digit[0-8]$/.test(e.code)) { e.preventDefault(); transform_(transformKeys[Number(e.code.slice(5))]); return; }
    const multiline = ["text", "quote", "callout", "code"].includes(block.kind);
    if (e.key === "Enter" && !e.shiftKey && (!multiline || block.kind === "text" || mod)) {
      e.preventDefault();
      saveText(text, true);
      if (continuesOnReturn(block.kind) && text.trim() === "") { save({ kind: "text" }); return; }
      api.insertAfter(block, continuesOnReturn(block.kind) ? (block.kind as BlockKind) : "text");
      return;
    }
    const el = e.currentTarget;
    if (e.key === "Backspace" && el.selectionStart === 0 && el.selectionEnd === 0) {
      if (text === "") { e.preventDefault(); api.remove(block, true); return; }
      if (block.kind !== "text") { e.preventDefault(); save({ kind: "text" }); return; }
    }
    if (e.key === "ArrowUp" && el.selectionStart === 0 && index > 0) { e.preventDefault(); setFocused(blocks[index - 1].id); }
    if (e.key === "ArrowDown" && el.selectionStart === text.length && index < blocks.length - 1) { e.preventDefault(); setFocused(blocks[index + 1].id); }
  };

  const editor = (className = "") => focused ? (
    <AutoTextarea value={text} onChange={onChange} onKeyDown={onKeyDown} autoFocus className={cn(textClass[block.kind], className)}
      inputRef={(el) => (el ? api.refs.set(block.id, el) : api.refs.delete(block.id))} ariaLabel={blockKinds[block.kind as BlockKind]?.title}
      onBlur={() => { saveText(text, true); setTimeout(() => { setMenuQuery(null); setMention(null); }, 150); }} />
  ) : (
    <div role="textbox" tabIndex={0} aria-label={blockKinds[block.kind as BlockKind]?.title} onFocus={() => setFocused(block.id)} onClick={() => setFocused(block.id)}
      className={cn("min-h-[1.5em] cursor-text whitespace-pre-wrap break-words", textClass[block.kind], className)}>
      <Inline text={block.text} />
    </div>
  );

  let content: ReactNode;
  switch (block.kind) {
    case "divider": content = <hr className="my-2 border-border" />; break;
    case "table": content = <TableBlock block={block} save={save} />; break;
    case "image":
      content = block.image_data ? (
        <figure className="m-0 flex flex-col gap-1">
          <img src={`data:image/jpeg;base64,${block.image_data}`} alt={block.text || "Imagem"} className="max-h-[480px] rounded-lg object-contain" />
          <input defaultValue={block.text} placeholder="Legenda" aria-label="Legenda" onBlur={(e) => save({ text: e.target.value })} className="bg-transparent text-sm text-muted-foreground outline-none" />
        </figure>
      ) : (
        <label className="flex cursor-pointer items-center gap-2 rounded-lg border border-dashed border-input p-4 text-sm text-muted-foreground">
          <ImagePlus size={18} aria-hidden="true" /> Escolher imagem
          <input type="file" accept="image/*" className="hidden" onChange={async (e) => { const f = e.target.files?.[0]; if (f) save({ image_data: await downsample(f) }); }} />
        </label>
      );
      break;
    case "bulleted": content = <div className="flex gap-2"><span aria-hidden="true">•</span>{editor("flex-1")}</div>; break;
    case "numbered": content = <div className="flex gap-2"><span className="tabular text-muted-foreground">{number}.</span>{editor("flex-1")}</div>; break;
    case "checklist":
      content = <div className="flex items-start gap-2"><Checkbox className="mt-1" checked={block.is_checked} onCheckedChange={(v) => save({ is_checked: v === true })} aria-label="Feito" />{editor(cn("flex-1", block.is_checked && "text-muted-foreground line-through"))}</div>;
      break;
    case "toggle":
      content = (
        <div className="flex flex-col gap-1">
          <div className="flex gap-1"><button type="button" aria-expanded={block.is_expanded} aria-label="Abrir ou fechar" onClick={() => save({ is_expanded: !block.is_expanded })}><ChevronRight size={16} className={cn("transition-transform", block.is_expanded && "rotate-90")} /></button>{editor("flex-1")}</div>
          {block.is_expanded && <textarea defaultValue={block.detail} placeholder="Conteúdo escondido…" aria-label="Conteúdo do alternar" onBlur={(e) => save({ detail: e.target.value })} className="ml-6 min-h-12 resize-y bg-transparent text-sm outline-none" />}
        </div>
      );
      break;
    case "quote": content = <div className="border-l-4 border-foreground/40 pl-3">{editor()}</div>; break;
    case "callout":
      content = (
        <div className="flex gap-2 rounded-lg bg-surface p-3">
          <button type="button" aria-label="Emoji do destaque" onClick={() => { const e = prompt("Emoji", block.emoji); if (e) save({ emoji: e }); }}>{block.emoji}</button>
          {editor("flex-1")}
        </div>
      );
      break;
    case "code":
      content = (
        <div className="flex flex-col gap-1 rounded-lg bg-surface p-3">
          <div className="flex justify-between text-xs text-muted-foreground">
            <input defaultValue={block.language} placeholder="linguagem" aria-label="Linguagem" onBlur={(e) => save({ language: e.target.value })} className="bg-transparent outline-none" />
            <button type="button" onClick={() => void navigator.clipboard.writeText(block.text).then(() => toast.success("Código copiado"))}><Copy size={13} aria-label="Copiar" /></button>
          </div>
          {editor()}
        </div>
      );
      break;
    default: content = editor();
  }

  return (
    <div ref={setNodeRef} style={{ transform: transform ? `translate3d(0, ${transform.y}px, 0)` : undefined, transition }} className="group relative flex items-start gap-1 py-0.5">
      <div className="flex shrink-0 opacity-0 group-hover:opacity-100 group-focus-within:opacity-100">
        <DropdownMenu>
          <DropdownMenuTrigger asChild><button type="button" aria-label="Bloco" className="rounded p-0.5 text-muted-foreground hover:bg-surface"><Plus size={16} /></button></DropdownMenuTrigger>
          <DropdownMenuContent align="start">
            <DropdownMenuLabel>Transformar em</DropdownMenuLabel>
            {kindOrder.map((k) => <DropdownMenuItem key={k} onSelect={() => transform_(k)}>{blockKinds[k].title}</DropdownMenuItem>)}
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => api.duplicate(block)}>Duplicar (⌘D)</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => api.move(block, -1)}>Mover para cima (⇧⌘↑)</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => api.move(block, 1)}>Mover para baixo (⇧⌘↓)</DropdownMenuItem>
            <DropdownMenuItem className="text-danger" onSelect={() => api.remove(block)}>Apagar bloco (⇧⌘⌫)</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <button type="button" aria-label="Arrastar bloco" className="cursor-grab rounded p-0.5 text-muted-foreground hover:bg-surface" {...attributes} {...listeners}><GripVertical size={16} /></button>
      </div>
      <div className="relative min-w-0 flex-1">
        {content}
        {focused && menuQuery != null && (
          <ul role="listbox" aria-label="Blocos" className="absolute left-0 top-full z-20 mt-1 max-h-72 w-72 overflow-y-auto rounded-lg border border-border bg-popover p-1 shadow-xl">
            {kinds.length === 0 && <li className="px-2 py-1.5 text-sm text-muted-foreground">Sem resultados</li>}
            {kinds.map((k, i) => (
              <li key={k} role="option" aria-selected={i === menuIndex}>
                <button type="button" onMouseDown={(e) => { e.preventDefault(); transform_(k); }} className={cn("flex w-full flex-col rounded-md px-2 py-1.5 text-left", i === menuIndex && "bg-accent")}>
                  <span className="text-sm">{blockKinds[k].title}</span><span className="text-xs text-muted-foreground">{blockKinds[k].subtitle}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
        {focused && mention != null && suggestions.length > 0 && (
          <ul role="listbox" aria-label="Menções" className="absolute left-0 top-full z-20 mt-1 max-h-72 w-80 overflow-y-auto rounded-lg border border-border bg-popover p-1 shadow-xl">
            {suggestions.map((s, i) => (
              <li key={s.token} role="option" aria-selected={i === mentionIndex}>
                <button type="button" onMouseDown={(e) => { e.preventDefault(); pickMention(s); }} className={cn("flex w-full justify-between gap-2 rounded-md px-2 py-1.5 text-left text-sm", i === mentionIndex && "bg-accent")}>
                  <span className="truncate">{s.label}</span><span className="text-xs text-muted-foreground">{s.hint}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

/** Editor por blocos da página (o NoteEditorView do iPhone). */
export function BlockEditor({ note, blocks }: { note: NoteRow; blocks: NoteBlockRow[] }) {
  const sorted = useMemo(() => [...blocks].sort((a, b) => a.sort_order - b.sort_order), [blocks]);
  const [focused, setFocused] = useState<string | null>(null);
  const refs = useRef(new Map<string, HTMLTextAreaElement>()).current;
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }), useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }));

  const reorder = async (list: NoteBlockRow[]) => {
    for (const [i, b] of list.entries()) if (b.sort_order !== i) await mutate.update("note_blocks", b.id, { sort_order: i });
    void mutate.update("notes", note.id, { edited_at: now() });
  };
  const api = {
    refs,
    async insertAfter(b: NoteBlockRow, kind: BlockKind, text = "") {
      const i = sorted.findIndex((x) => x.id === b.id);
      const created = await mutate.insert("note_blocks", { id: newID(), note_id: note.id, kind, text, is_checked: false, sort_order: b.sort_order + 1, created_at: now(), emoji: "💡", language: "", detail: "" });
      const list = [...sorted];
      list.splice(i + 1, 0, created);
      await reorder(list);
      setFocused(created.id);
    },
    async remove(b: NoteBlockRow, focusPrev = false) {
      const i = sorted.findIndex((x) => x.id === b.id);
      await mutate.remove("note_blocks", [b.id]);
      if (focusPrev && i > 0) setFocused(sorted[i - 1].id);
    },
    async move(b: NoteBlockRow, delta: number) {
      const i = sorted.findIndex((x) => x.id === b.id);
      const j = i + delta;
      if (j < 0 || j >= sorted.length) return;
      const list = [...sorted];
      [list[i], list[j]] = [list[j], list[i]];
      await reorder(list);
      setFocused(b.id);
    },
    async duplicate(b: NoteBlockRow) {
      const { id: _id, user_id: _u, updated_at: _up, ...copy } = b;
      const created = await mutate.insert("note_blocks", { ...copy, id: newID(), sort_order: b.sort_order + 1, created_at: now() });
      const list = [...sorted];
      list.splice(sorted.findIndex((x) => x.id === b.id) + 1, 0, created);
      await reorder(list);
    },
  };
  const onDragEnd = (e: DragEndEvent) => {
    if (!e.over || e.active.id === e.over.id) return;
    const from = sorted.findIndex((b) => b.id === e.active.id);
    const to = sorted.findIndex((b) => b.id === e.over!.id);
    const list = [...sorted];
    const [moved] = list.splice(from, 1);
    list.splice(to, 0, moved);
    void reorder(list);
  };
  let number = 0;

  return (
    <div className="flex flex-col">
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
        <SortableContext items={sorted.map((b) => b.id)} strategy={verticalListSortingStrategy}>
          {sorted.map((b, i) => {
            number = b.kind === "numbered" ? number + 1 : 0;
            return <BlockRow key={b.id} block={b} index={i} blocks={sorted} number={number} focused={focused === b.id} setFocused={setFocused} api={api} />;
          })}
        </SortableContext>
      </DndContext>
      <button
        type="button"
        onClick={async () => {
          const created = await mutate.insert("note_blocks", { id: newID(), note_id: note.id, kind: "text", text: "", is_checked: false, sort_order: sorted.length, created_at: now(), emoji: "💡", language: "", detail: "" });
          setFocused(created.id);
        }}
        className="mt-2 flex items-center gap-1.5 self-start rounded px-1 py-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <Plus size={16} aria-hidden="true" /> Adicionar bloco
      </button>
    </div>
  );
}
