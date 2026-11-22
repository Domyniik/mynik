import { searchKey } from "./search";

/** Comerciante, total e data de uma fatura (tradução de ReceiptParser do iPhone). */
export interface ReceiptResult {
  merchant: string | null;
  amount: number | null;
  date: Date | null;
  currencyCode: string;
}

const totalWords = ["total a pagar", "a pagar", "importe total", "total eur", "total €", "total", "importe", "a liquidar", "valor pago"];
const ignoredTotalWords = ["subtotal", "sub-total", "base imp", "iva", "i.v.a", "desconto", "descuento", "cambio", "troco", "entregado", "total articulos", "total artigos", "nº art"];
const ignoredMerchantWords = ["factura", "fatura", "ticket", "talao", "recibo", "simplificada", "cif", "nif", "nipc", "tel", "telf", "fecha", "data", "hora", "calle", "c/", "avda", "rua", "www", "http", "@", "bienvenido", "obrigado", "gracias"];

/** Valores com duas casas decimais: "12,50", "1.234,56", "€ 3.20". */
export function amounts(line: string): number[] {
  const out: number[] = [];
  for (const m of line.matchAll(/(\d{1,3}(?:[.\s]\d{3})+|\d+)[.,](\d{2})(?!\d)/g)) {
    const value = Number(`${m[1].replace(/\D/g, "")}.${m[2]}`);
    if (value > 0 && value < 100_000) out.push(value);
  }
  return out;
}

export function total(lines: string[]): number | null {
  for (let i = lines.length - 1; i >= 0; i -= 1) {
    const key = searchKey(lines[i]);
    if (!totalWords.some((w) => key.includes(w)) || ignoredTotalWords.some((w) => key.includes(w))) continue;
    const found = amounts(lines[i]);
    if (found.length > 0) return found[found.length - 1];
    if (i + 1 < lines.length) {
      const next = amounts(lines[i + 1]);
      if (next.length > 0) return next[0];
    }
  }
  const all = lines.flatMap(amounts);
  return all.length > 0 ? Math.max(...all) : null;
}

function makeDate(y: number, m: number, d: number) {
  if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  const date = new Date(y, m - 1, d, 12);
  return date.getDate() === d ? date : null;
}

export function dateIn(line: string): Date | null {
  let m = line.match(/(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})/);
  if (m) return makeDate(Number(m[1]), Number(m[2]), Number(m[3]));
  m = line.match(/(?:^|\D)(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})(?!\d)/);
  if (m) {
    let year = Number(m[3]);
    if (year < 100) year += 2000;
    return makeDate(year, Number(m[2]), Number(m[1]));
  }
  return null;
}

function prettify(line: string) {
  if (line !== line.toUpperCase()) return line;
  return line
    .split(" ")
    .map((w) => (w.length <= 2 || w.includes(".") ? w : w[0] + w.slice(1).toLowerCase()))
    .join(" ");
}

export function merchant(lines: string[]): string | null {
  for (const line of lines.slice(0, 6)) {
    const key = searchKey(line);
    const letters = (line.match(/\p{L}/gu) ?? []).length;
    const digits = (line.match(/\d/g) ?? []).length;
    if (letters < 3 || digits > letters || ignoredMerchantWords.some((w) => key.includes(w)) || amounts(line).length > 0) continue;
    return prettify(line);
  }
  return null;
}

export function parseReceipt(rawLines: string[]): ReceiptResult {
  const lines = rawLines.map((l) => l.trim()).filter(Boolean);
  const joined = lines.join(" ").toUpperCase();
  return {
    currencyCode: joined.includes("R$") || joined.includes("BRL") ? "BRL" : "EUR",
    merchant: merchant(lines),
    amount: total(lines),
    date: lines.map(dateIn).find((d) => d != null) ?? null,
  };
}
