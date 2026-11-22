"use client";

import { parseCSV } from "@/lib/calc/csv";
import { encodeProperties, encodeValues, type NoteProperty, type ParsedBlock, parseMarkdown } from "@/lib/calc/notes";
import { newID } from "@/lib/db/client";
import type { NoteRow } from "@/lib/db/schema";
import { mutate } from "@/lib/db/store";
import { createNote, insertBlocks } from "./note-actions";

/** "Plano 1a2b…" → "Plano" (tira o id do Notion do fim do nome). */
const cleanName = (name: string) => name.replace(/\.(md|csv)$/i, "").replace(/(_all)$/i, "").replace(/\s+[0-9a-f]{32}$/i, "").trim();
const IMAGE = /\.(png|jpe?g|gif|webp|heic)$/i;

async function imageBase64(bytes: Uint8Array): Promise<string> {
  const bitmap = await createImageBitmap(new Blob([bytes as BlobPart]));
  const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d")!.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/jpeg", 0.8).split(",")[1];
}

/** Tipo da coluna pelos valores: caixa (Yes/No), número, data, seleção (poucos valores repetidos) ou texto. */
function inferType(samples: string[]): NoteProperty["type"] {
  const filled = samples.filter((s) => s.trim());
  if (filled.length === 0) return "text";
  if (filled.every((s) => /^(yes|no|sim|não|true|false)$/i.test(s))) return "checkbox";
  if (filled.every((s) => /^-?\d+([.,]\d+)?$/.test(s.trim()))) return "number";
  if (filled.every((s) => !Number.isNaN(Date.parse(s.split(" → ")[0])))) return "date";
  const distinct = new Set(filled);
  if (distinct.size <= Math.max(3, filled.length / 2) && filled.length > distinct.size) return "select";
  return "text";
}

function toValue(type: NoteProperty["type"], raw: string) {
  const v = raw.trim();
  if (!v) return "";
  if (type === "checkbox") return /^(yes|sim|true)$/i.test(v) ? "true" : "";
  if (type === "number") return v.replace(",", ".");
  if (type === "date") {
    const d = new Date(Date.parse(v.split(" → ")[0]));
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
  return v;
}

/** Importa um export do Notion ("Markdown & CSV", em ZIP) para as Notas. */
export async function importNotion(file: File, notes: NoteRow[], parentID: string | null) {
  const { default: JSZip } = await import("jszip");
  const files = new Map<string, Uint8Array>();
  const read = async (data: Blob | Uint8Array, prefix: string, depth: number) => {
    const zip = await JSZip.loadAsync(data);
    for (const entry of Object.values(zip.files)) {
      if (entry.dir) continue;
      const bytes = await entry.async("uint8array");
      if (/\.zip$/i.test(entry.name) && depth < 2) await read(bytes, prefix, depth + 1); // ZIPs partidos
      else files.set(prefix + entry.name, bytes);
    }
  };
  await read(file, "", 0);
  const decoder = new TextDecoder();
  const known = [...notes];
  const created = new Map<string, string>(); // caminho sem extensão → id da nota
  let pages = 0;
  let images = 0;

  const paths = [...files.keys()].filter((p) => /\.(md|csv)$/i.test(p)).sort((a, b) => a.split("/").length - b.split("/").length || a.localeCompare(b));
  const parentFor = (path: string) => {
    const folder = path.split("/").slice(0, -1).join("/");
    return created.get(folder) ?? parentID;
  };

  for (const path of paths) {
    const base = path.replace(/\.(md|csv)$/i, "").replace(/_all$/i, "");
    if (created.has(base)) continue;
    const name = cleanName(path.split("/").pop()!);
    if (/\.csv$/i.test(path)) {
      const table = parseCSV(decoder.decode(files.get(path)).replace(/﻿/g, ""));
      const [header = [], ...rows] = table;
      const props: NoteProperty[] = header.slice(1).map((h, i) => {
        const type = inferType(rows.map((r) => r[i + 1] ?? ""));
        const options = type === "select" ? [...new Set(rows.map((r) => (r[i + 1] ?? "").trim()).filter(Boolean))] : [];
        return { id: newID(), name: h, type, options };
      });
      const db = await createNote(known, { parent_id: parentFor(path), title: name, icon: "🗂️", is_database: true, database_schema: encodeProperties(props) });
      known.push(db);
      created.set(base, db.id);
      pages += 1;
      for (const r of rows) {
        const vals: Record<string, string> = {};
        props.forEach((p, i) => (vals[p.id] = toValue(p.type, r[i + 1] ?? "")));
        const row = await createNote(known, { parent_id: db.id, title: r[0] ?? "", property_values: encodeValues(vals) });
        known.push(row);
        created.set(`${base}/${r[0] ?? ""}`, row.id);
        pages += 1;
      }
      continue;
    }
    const text = decoder.decode(files.get(path));
    const [first, ...rest] = text.split("\n");
    const title = first.startsWith("# ") ? first.slice(2).trim() : name;
    const body = first.startsWith("# ") ? rest.join("\n") : text;
    // Linha de base de dados com o mesmo título já criada pelo CSV: só acrescenta o conteúdo.
    const folder = path.split("/").slice(0, -1).join("/");
    const rowID = [...created.entries()].find(([k]) => k.startsWith(`${folder}/`) && cleanName(k.split("/").pop()!) === title && k.split("/").length === path.split("/").length)?.[1];
    const note = rowID ? known.find((n) => n.id === rowID)! : await createNote(known, { parent_id: parentFor(path), title });
    if (!rowID) {
      known.push(note);
      pages += 1;
    }
    created.set(base, note.id);
    const blocks: ParsedBlock[] = [];
    for (const b of parseMarkdown(
      body
        .replace(/^([A-Za-zÀ-ÿ ]+): (.+)$/gm, (m) => m) // propriedades no topo ficam como texto
        .replace(/\[([^\]]+)\]\(([^)]+?\.md)\)/g, (_m, label: string) => `[[${label}]]`),
    )) {
      const image = b.text.match(/^!\[([^\]]*)\]\(([^)]+)\)$/);
      if (image && IMAGE.test(image[2])) {
        const target = decodeURIComponent(image[2]);
        const key = [...files.keys()].find((k) => k.endsWith(target) || k.endsWith(target.split("/").pop()!));
        if (key) {
          blocks.push({ kind: "image", text: image[1] });
          (blocks[blocks.length - 1] as ParsedBlock & { image?: string }).image = await imageBase64(files.get(key)!);
          images += 1;
          continue;
        }
      }
      blocks.push(b);
    }
    let order = 0;
    for (const b of blocks) {
      const image = (b as ParsedBlock & { image?: string }).image;
      if (image) {
        await mutate.insert("note_blocks", { id: newID(), note_id: note.id, kind: "image", text: b.text, image_data: image, sort_order: order, created_at: new Date().toISOString(), is_checked: false, emoji: "💡", language: "", detail: "" });
      } else await insertBlocks(note.id, [b], order);
      order += 1;
    }
  }
  if (pages === 0) throw new Error("O ZIP não tem páginas do Notion (Markdown ou CSV).");
  return { pages, images };
}
