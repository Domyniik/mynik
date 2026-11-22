"use client";

import { type BuiltInTemplate, encodeProperties, fillTemplate, type ParsedBlock, parseMarkdown } from "@/lib/calc/notes";
import { newID, now } from "@/lib/db/client";
import type { NoteBlockRow, NoteRow } from "@/lib/db/schema";
import { mutate } from "@/lib/db/store";

/** Página nova (NoteEditing.makeNote), no fim dos irmãos. */
export async function createNote(siblings: NoteRow[], extra: Partial<NoteRow> = {}) {
  const parent = extra.parent_id ?? null;
  const order = siblings.filter((n) => (n.parent_id ?? null) === parent).reduce((m, n) => Math.max(m, n.sort_order + 1), 0);
  return mutate.insert("notes", { id: newID(), title: "", icon: "📄", created_at: now(), edited_at: now(), sort_order: order, ...extra });
}

/** Base de dados com Estado e Data (NoteDatabase.makeDatabase). */
export function createDatabase(siblings: NoteRow[], parent: string | null) {
  return createNote(siblings, {
    parent_id: parent, icon: "🗂️", is_database: true, database_view: "table",
    database_schema: encodeProperties([
      { id: newID(), name: "Estado", type: "select", options: ["A fazer", "Em curso", "Feito"] },
      { id: newID(), name: "Data", type: "date" },
    ]),
  });
}

export async function insertBlocks(noteID: string, blocks: ParsedBlock[], startOrder = 0) {
  let order = startOrder;
  for (const b of blocks) {
    await mutate.insert("note_blocks", {
      id: newID(), note_id: noteID, kind: b.kind, text: b.text, is_checked: b.isChecked ?? false, sort_order: order,
      created_at: now(), emoji: b.emoji ?? "💡", language: b.language ?? "", detail: b.detail ?? "",
    });
    order += 1;
  }
}

export async function instantiateTemplate(template: BuiltInTemplate, siblings: NoteRow[], parent: string | null) {
  const note = await createNote(siblings, {
    parent_id: parent, title: fillTemplate(template.title), icon: template.icon, cover: template.cover,
    ...(template.properties ? { is_database: true, database_schema: encodeProperties(template.properties.map((p) => ({ ...p, id: newID() }))) } : {}),
  });
  await insertBlocks(note.id, parseMarkdown(fillTemplate(template.markdown)).map((b) => ({ ...b, text: b.text.trim() })));
  return note;
}

/** Copia título, ícone, capa, propriedades e blocos (templates próprios). */
export async function copyNote(source: NoteRow, blocks: NoteBlockRow[], siblings: NoteRow[], asTemplate: boolean, parent: string | null) {
  const note = await createNote(siblings, {
    parent_id: parent, title: asTemplate ? source.title : fillTemplate(source.title), icon: source.icon, cover: source.cover,
    is_database: source.is_database, database_schema: source.database_schema, database_view: source.database_view,
    is_template: asTemplate,
  });
  await insertBlocks(note.id, blocks.filter((b) => b.note_id === source.id).sort((a, b) => a.sort_order - b.sort_order).map((b) => ({
    kind: b.kind as ParsedBlock["kind"], text: asTemplate ? b.text : fillTemplate(b.text), isChecked: b.is_checked, emoji: b.emoji, language: b.language, detail: b.detail,
  })));
  return note;
}

/** Apaga a página, as subpáginas e os blocos (cascata, como no iPhone). */
export async function deleteNoteTree(note: NoteRow, notes: NoteRow[], blocks: NoteBlockRow[]) {
  const ids = new Set<string>([note.id]);
  let grew = true;
  while (grew) {
    grew = false;
    for (const n of notes) if (n.parent_id && ids.has(n.parent_id) && !ids.has(n.id)) {
      ids.add(n.id);
      grew = true;
    }
  }
  await mutate.remove("note_blocks", blocks.filter((b) => b.note_id && ids.has(b.note_id)).map((b) => b.id));
  await mutate.remove("notes", [...ids]);
}

export const touch = (note: NoteRow) => mutate.update("notes", note.id, { edited_at: now() });
