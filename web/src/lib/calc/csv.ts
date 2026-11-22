import { searchKey } from "./search";

/** Tradução de CSVParser + BankCSVImporter + DuplicateDetector do iPhone. */

/** Escolhe entre `;`, tab e `,`, conforme o que mais aparece na 1.ª linha (empate: o primeiro). */
export function detectDelimiter(text: string) {
  const firstLine = text.split(/\r?\n/, 1)[0] ?? "";
  const count = (c: string) => firstLine.split(c).length - 1;
  let best = ";";
  for (const candidate of ["\t", ","]) if (count(candidate) > count(best)) best = candidate;
  return best;
}

/** CSV simples: deteta o separador e respeita campos entre aspas. */
export function parseCSV(text: string): string[][] {
  const delimiter = detectDelimiter(text);
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  const endField = () => {
    row.push(field.trim());
    field = "";
  };
  const endRow = () => {
    endField();
    if (row.some((f) => f !== "")) rows.push(row);
    row = [];
  };
  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else quoted = false;
      } else field += c;
    } else if (c === '"') quoted = true;
    else if (c === delimiter) endField();
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i += 1;
      endRow();
    } else field += c;
  }
  if (field !== "" || row.length > 0) endRow();
  return rows;
}

export interface BankRow {
  date: Date;
  title: string;
  /** Positivo = receita, negativo = gasto. */
  signedAmount: number;
}

export interface BankParseResult {
  rows: BankRow[];
  skippedLines: number;
}

export class CSVImportError extends Error {}

const normalize = (header: string) => searchKey(header);

/** Aceita "1.234,56", "-12,30", "1,234.56", "-12.30", "12,30 €", "(12,30)". */
export function parseBankAmount(text: string): number | null {
  let cleaned = [...text].filter((c) => /[\d,.\-(]/.test(c)).join("");
  let negative = cleaned.startsWith("-") || cleaned.startsWith("(") || text.trim().endsWith("-");
  cleaned = cleaned.replace(/[-(]/g, "");
  if (!cleaned) return null;
  const lastComma = cleaned.lastIndexOf(",");
  const lastDot = cleaned.lastIndexOf(".");
  let decimal: string | null;
  if (lastComma >= 0 && lastDot >= 0) decimal = lastComma > lastDot ? "," : ".";
  else if (lastComma >= 0) decimal = ",";
  else if (lastDot >= 0) decimal = cleaned.split(".").length - 1 === 1 ? "." : null;
  else decimal = null;
  let normalized = "";
  for (const c of cleaned) {
    if (c === decimal) normalized += ".";
    else if (/\d/.test(c)) normalized += c;
  }
  if (!normalized || normalized === ".") return null;
  const value = Number(normalized);
  if (!Number.isFinite(value)) return null;
  if (value === 0) negative = false;
  return negative ? -value : value;
}

/** Datas "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "yyyy-MM-dd", "yyyy/MM/dd", "dd/MM/yy" (ignora horas). */
export function parseBankDate(text: string): Date | null {
  const part = text.trim().split(/[ T]/)[0] ?? "";
  let y: number, m: number, d: number;
  let match = part.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/);
  if (match) {
    [y, m, d] = [Number(match[1]), Number(match[2]), Number(match[3])];
  } else {
    match = part.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})$/);
    if (!match) return null;
    [d, m, y] = [Number(match[1]), Number(match[2]), Number(match[3])];
    if (match[3].length === 2) y += 2000;
  }
  const date = new Date(y, m - 1, d);
  if (date.getFullYear() !== y || date.getMonth() !== m - 1 || date.getDate() !== d) return null;
  return date;
}

interface Columns {
  date: number;
  title: number;
  amount: number | null;
  debit: number | null;
  credit: number | null;
}

function columnsFor(header: string[]): Columns | null {
  const names = header.map(normalize);
  const dateKeywords = ["data", "date", "fecha"];
  const find = (keywords: string[], used: (number | null)[] = []) => {
    const index = names.findIndex((name, i) => {
      const mentionsDate = keywords !== dateKeywords && dateKeywords.some((k) => name.includes(k));
      return !used.includes(i) && !mentionsDate && keywords.some((k) => name.includes(k));
    });
    return index >= 0 ? index : null;
  };
  const date = find(dateKeywords);
  if (date == null) return null;
  const title = find(["descri", "concept", "detalhe", "movimento", "description", "memo", "payee", "beneficiario"], [date]);
  if (title == null) return null;
  const amount = find(["valor", "montante", "importe", "amount", "quantia", "cantidad"], [date, title]);
  const debit = find(["debito", "debit", "cargo"], [date, title, amount]);
  const credit = find(["credito", "credit", "abono"], [date, title, amount, debit]);
  if (amount == null && (debit == null || credit == null)) return null;
  if (debit != null && credit != null) return { date, title, amount: null, debit, credit };
  return { date, title, amount, debit: null, credit: null };
}

/** Extrato bancário (cabeçalhos em pt, es ou en) → movimentos. */
export function parseBankCSV(text: string): BankParseResult {
  const table = parseCSV(text.replace(/﻿/g, ""));
  let headerIndex = -1;
  let columns: Columns | null = null;
  for (let i = 0; i < Math.min(15, table.length); i += 1) {
    columns = columnsFor(table[i]);
    if (columns) {
      headerIndex = i;
      break;
    }
  }
  if (!columns) throw new CSVImportError("Não encontrei colunas de data, descrição e valor.");
  const rows: BankRow[] = [];
  let skipped = 0;
  for (const line of table.slice(headerIndex + 1)) {
    const value = (i: number | null) => (i != null && i < line.length ? line[i] : null);
    const date = value(columns.date) ? parseBankDate(value(columns.date)!) : null;
    const title = (value(columns.title) ?? "").trim();
    let signed: number | null;
    if (columns.amount != null) {
      signed = value(columns.amount) != null ? parseBankAmount(value(columns.amount)!) : null;
    } else {
      const debit = Math.abs(parseBankAmount(value(columns.debit) ?? "") ?? 0);
      const credit = Math.abs(parseBankAmount(value(columns.credit) ?? "") ?? 0);
      signed = credit - debit;
    }
    if (!date || !title || signed == null || signed === 0) {
      skipped += 1;
      continue;
    }
    rows.push({ date, title, signedAmount: Math.round(signed * 100) / 100 });
  }
  return { rows, skippedLines: skipped };
}

/** Lê o ficheiro em UTF-8 ou, se não for válido, em Windows-1252 (bancos ibéricos). */
export function decodeBankFile(bytes: ArrayBuffer) {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return new TextDecoder("windows-1252").decode(bytes);
  }
}

/** Mesmo dia, valor e descrição = duplicado. */
export function duplicateKey(date: Date | string, signedAmount: number, title: string) {
  const d = new Date(date);
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}|${signedAmount.toFixed(2)}|${normalize(title)}`;
}
