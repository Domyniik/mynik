import type { NoteBlockRow, NoteRow } from "../db/schema";
import { searchKey } from "./search";

/** Tipos de bloco (NoteBlockKind no iPhone; "heading" é o Título 1). */
export const blockKinds = {
  text: { title: "Texto", subtitle: "Parágrafo simples", terms: ["paragrafo", "texto", "p"] },
  heading: { title: "Título 1", subtitle: "Título grande de secção", terms: ["h1", "titulo"] },
  heading2: { title: "Título 2", subtitle: "Título médio", terms: ["h2", "titulo", "subtitulo"] },
  heading3: { title: "Título 3", subtitle: "Título pequeno", terms: ["h3", "titulo"] },
  bulleted: { title: "Lista com marcas", subtitle: "Lista simples com marcas", terms: ["ul", "marcas", "bullet", "lista"] },
  numbered: { title: "Lista numerada", subtitle: "Lista com números", terms: ["ol", "numeros", "lista"] },
  checklist: { title: "Lista de tarefas", subtitle: "Tarefas para marcar", terms: ["todo", "tarefa", "checkbox", "lista"] },
  toggle: { title: "Alternar", subtitle: "Texto que abre e fecha", terms: ["toggle", "expandir", "recolher"] },
  quote: { title: "Citação", subtitle: "Citação em destaque", terms: ["quote", "citacao"] },
  callout: { title: "Destaque", subtitle: "Caixa com emoji", terms: ["callout", "nota", "aviso", "emoji"] },
  code: { title: "Código", subtitle: "Bloco de código", terms: ["code", "codigo", "programar"] },
  table: { title: "Tabela", subtitle: "Tabela simples", terms: ["table", "grelha"] },
  divider: { title: "Divisor", subtitle: "Linha de separação", terms: ["hr", "linha", "separador", "divider"] },
  image: { title: "Imagem", subtitle: "Foto ou imagem", terms: ["foto", "imagem", "img"] },
} as const;
export type BlockKind = keyof typeof blockKinds;
export const kindOrder = Object.keys(blockKinds) as BlockKind[];
export const isTextual = (k: string) => !["image", "divider", "table"].includes(k);
export const continuesOnReturn = (k: string) => k === "bulleted" || k === "numbered" || k === "checklist";

export function matchingKinds(query: string): BlockKind[] {
  const q = searchKey(query);
  if (!q) return kindOrder;
  return kindOrder.filter((k) => searchKey(blockKinds[k].title).includes(q) || blockKinds[k].terms.some((t) => t.startsWith(q)));
}

export const covers: Record<string, { title: string; css: string }> = {
  sunset: { title: "Pôr do sol", css: "linear-gradient(135deg,#fa8c5c,#e84d78)" },
  ocean: { title: "Oceano", css: "linear-gradient(135deg,#338cd9,#21c7c2)" },
  forest: { title: "Floresta", css: "linear-gradient(135deg,#338c5c,#8cc266)" },
  lavender: { title: "Lavanda", css: "linear-gradient(135deg,#9e87eb,#db9ee6)" },
  peach: { title: "Pêssego", css: "linear-gradient(135deg,#ffcc9e,#fa9e94)" },
  graphite: { title: "Grafite", css: "linear-gradient(135deg,#40454f,#78808c)" },
  sand: { title: "Areia", css: "linear-gradient(135deg,#edd9b3,#ccad85)" },
  aurora: { title: "Aurora", css: "linear-gradient(135deg,#26408c,#40bfa6,#b3e68c)" },
};

// ---------- Atalhos Markdown ao escrever (NoteMarkdown.shortcut) ----------
const shortcutRules: [string, BlockKind, boolean][] = [
  ["### ", "heading3", false], ["## ", "heading2", false], ["# ", "heading", false],
  ["- [ ] ", "checklist", false], ["- [x] ", "checklist", true], ["- [X] ", "checklist", true],
  ["[] ", "checklist", false], ["[ ] ", "checklist", false],
  ["- ", "bulleted", false], ["* ", "bulleted", false], ["• ", "bulleted", false],
  ["> ", "quote", false], ["```", "code", false],
];

export interface ParsedBlock {
  kind: BlockKind;
  text: string;
  isChecked?: boolean;
  emoji?: string;
  language?: string;
  detail?: string;
}

export function shortcut(text: string): ParsedBlock | null {
  if (text === "---" || text === "***") return { kind: "divider", text: "" };
  const numbered = text.match(/^(\d{1,3})[.)] /);
  if (numbered) return { kind: "numbered", text: text.slice(numbered[0].length) };
  for (const [prefix, kind, checked] of shortcutRules) {
    if (text.startsWith(prefix)) return { kind, text: text.slice(prefix.length), isChecked: checked, ...(kind === "code" ? { language: text.slice(3).trim(), text: "" } : {}) };
  }
  return null;
}

// ---------- Tabelas: linhas por \n, células por tab ----------
export const parseTable = (text: string) => (text ? text.split("\n").map((r) => r.split("\t")) : [["", ""], ["", ""]]);
export const serializeTable = (rows: string[][]) => rows.map((r) => r.join("\t")).join("\n");

// ---------- Markdown: importar e exportar (NoteMarkdown.parse / export) ----------
export function parseMarkdown(markdown: string): ParsedBlock[] {
  const lines = markdown.split("\n");
  const blocks: ParsedBlock[] = [];
  for (let i = 0; i < lines.length; i += 1) {
    const raw = lines[i];
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith("```")) {
      const code: string[] = [];
      for (i += 1; i < lines.length && !lines[i].trim().startsWith("```"); i += 1) code.push(lines[i]);
      blocks.push({ kind: "code", text: code.join("\n"), language: line.slice(3).trim() });
    } else if (line.toLowerCase() === "<aside>") {
      const body: string[] = [];
      for (i += 1; i < lines.length && lines[i].trim().toLowerCase() !== "</aside>"; i += 1) body.push(lines[i].trim());
      const text = body.join("\n").trim();
      const emoji = [...text][0] ?? "💡";
      const hasEmoji = /\p{Extended_Pictographic}/u.test(emoji);
      blocks.push({ kind: "callout", emoji: hasEmoji ? emoji : "💡", text: hasEmoji ? text.slice(emoji.length).trim() : text });
    } else if (line.startsWith("|")) {
      const rows: string[][] = [];
      for (; i < lines.length && lines[i].trim().startsWith("|"); i += 1) {
        const cells = lines[i].trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim().replace(/\\\|/g, "|"));
        if (!cells.every((c) => /^[-:]+$/.test(c) || c === "")) rows.push(cells);
      }
      i -= 1;
      blocks.push({ kind: "table", text: serializeTable(rows) });
    } else if (line.startsWith(">")) {
      const quote: string[] = [];
      for (; i < lines.length && lines[i].trim().startsWith(">"); i += 1) quote.push(lines[i].trim().replace(/^>\s?/, ""));
      i -= 1;
      blocks.push({ kind: "quote", text: quote.join("\n") });
    } else {
      const empty = ["-", "*", "- [ ]", "[]", "[ ]"].includes(line) || /^\d{1,3}\.$/.test(line);
      blocks.push(shortcut(empty ? `${line} ` : line) ?? { kind: "text", text: line });
    }
  }
  return blocks;
}

export function exportMarkdown(title: string, blocks: NoteBlockRow[]) {
  const lines = [`# ${title || "Sem título"}`, ""];
  let number = 0;
  for (const b of [...blocks].sort((a, c) => a.sort_order - c.sort_order)) {
    number = b.kind === "numbered" ? number + 1 : 0;
    switch (b.kind) {
      case "heading": lines.push(`# ${b.text}`); break;
      case "heading2": lines.push(`## ${b.text}`); break;
      case "heading3": lines.push(`### ${b.text}`); break;
      case "bulleted": lines.push(`- ${b.text}`); break;
      case "numbered": lines.push(`${number}. ${b.text}`); break;
      case "checklist": lines.push(`- [${b.is_checked ? "x" : " "}] ${b.text}`); break;
      case "toggle": lines.push(`- ${b.text}`, ...b.detail.split("\n").map((l) => `    ${l}`)); break;
      case "quote": lines.push(...b.text.split("\n").map((l) => `> ${l}`)); break;
      case "callout": lines.push("<aside>", `${b.emoji} ${b.text}`, "</aside>"); break;
      case "code": lines.push(`\`\`\`${b.language}`, b.text, "```"); break;
      case "table": {
        const rows = parseTable(b.text);
        const row = (cells: string[]) => `| ${cells.map((c) => c.replace(/\|/g, "\\|")).join(" | ")} |`;
        lines.push(row(rows[0]), row(rows[0].map(() => "---")), ...rows.slice(1).map(row));
        break;
      }
      case "divider": lines.push("---"); break;
      case "image": lines.push(`![${b.text}](imagem)`); break;
      default: lines.push(b.text);
    }
  }
  return lines.join("\n") + "\n";
}

// ---------- Menções (NoteMention) ----------
export type MentionKind = "note" | "project" | "transaction" | "date";
export const mentionToken = (label: string, kind: MentionKind, id: string) => `[@${label}](mynik://${kind}/${id})`;
export const dateLabel = (d: Date) => new Intl.DateTimeFormat("pt-PT", { day: "numeric", month: "short", year: "numeric" }).format(d);
export const dayValue = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

/** "@pal" no fim do texto a ser escrito (para abrir o seletor). */
export function activeMentionQuery(text: string, caret: number) {
  const before = text.slice(0, caret);
  const m = before.match(/(?:^|\s)@([^\s@[\]()]{0,30})$/);
  return m ? m[1] : null;
}

export const legacyMentions = (text: string) => [...text.matchAll(/\[\[([^[\]\n]+)\]\]/g)].map((m) => m[1]);

export function backlinks(note: NoteRow, notes: NoteRow[], blocks: NoteBlockRow[]) {
  const link = `mynik://note/${note.id}`;
  const title = note.title.trim().toLowerCase();
  const textByNote = new Map<string, string>();
  for (const b of blocks) textByNote.set(b.note_id ?? "", `${textByNote.get(b.note_id ?? "") ?? ""}\n${b.text}`);
  return notes.filter((other) => {
    if (other.id === note.id) return false;
    const text = textByNote.get(other.id) ?? "";
    return text.includes(link) || (title !== "" && legacyMentions(text).some((m) => m.toLowerCase() === title));
  });
}

// ---------- Bases de dados (NoteDatabase) ----------
export type PropertyType = "text" | "number" | "select" | "date" | "checkbox";
export interface NoteProperty {
  id: string;
  name: string;
  type: PropertyType;
  options?: string[];
}
export const propertyTypes: Record<PropertyType, string> = { text: "Texto", number: "Número", select: "Seleção", date: "Data", checkbox: "Caixa" };
const parseJSON = <T,>(text: string, fallback: T): T => {
  try {
    return text ? (JSON.parse(text) as T) : fallback;
  } catch {
    return fallback;
  }
};
export const properties = (n: NoteRow) => parseJSON<NoteProperty[]>(n.database_schema, []).map((p) => ({ ...p, options: p.options ?? [] }));
export const values = (n: NoteRow) => parseJSON<Record<string, string>>(n.property_values, {});
/** JSON com as chaves ordenadas e sem vazios, como o iPhone escreve. */
export function encodeValues(v: Record<string, string>) {
  const entries = Object.entries(v).filter(([, x]) => x !== "").sort(([a], [b]) => (a < b ? -1 : 1));
  return entries.length ? JSON.stringify(Object.fromEntries(entries)) : "";
}
export const encodeProperties = (p: NoteProperty[]) => JSON.stringify(p.map(({ id, name, type, options }) => ({ id, name, options: options ?? [], type })));

// ---------- Templates (NoteTemplates) ----------
export interface BuiltInTemplate {
  id: string;
  title: string;
  icon: string;
  cover: string;
  markdown: string;
  properties?: Omit<NoteProperty, "id">[];
}
export const builtInTemplates: BuiltInTemplate[] = [
  { id: "meeting", title: "Reunião {{data}}", icon: "🤝", cover: "ocean", markdown: "## Participantes\n- \n## Pontos\n1. \n## Decisões\n<aside>\n✅ \n</aside>\n## Próximos passos\n- [ ] " },
  { id: "journal", title: "Diário {{data}}", icon: "📔", cover: "peach", markdown: "## Como me sinto\n## Gratidão\n- \n## Hoje fiz\n- [ ] \n> Uma frase para lembrar" },
  { id: "project", title: "Novo projeto", icon: "🎯", cover: "forest", markdown: "<aside>\n🎯 Objetivo: \n</aside>\n## Contexto\n## Tarefas\n- [ ] \n## Orçamento\n| Item | Valor (€) |\n| --- | --- |\n|  |  |\n---\n## Notas" },
  {
    id: "reading", title: "Leituras", icon: "📚", cover: "lavender", markdown: "Livros e artigos para ler, a ler e lidos.",
    properties: [
      { name: "Estado", type: "select", options: ["Para ler", "A ler", "Lido"] }, { name: "Autor", type: "text" },
      { name: "Nota", type: "number" }, { name: "Terminado em", type: "date" },
    ],
  },
  { id: "week", title: "Semana de {{data}}", icon: "🗓️", cover: "sand", markdown: "## Prioridades\n1. \n## Segunda\n- [ ] \n## Terça\n- [ ] \n## Quarta\n- [ ] \n## Quinta\n- [ ] \n## Sexta\n- [ ] \n## Revisão" },
];
export const fillTemplate = (text: string, d = new Date()) => text.replaceAll("{{data}}", dateLabel(d));
