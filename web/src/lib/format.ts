/** Formatação igual à do iPhone (`Locale.app` = pt_PT). */
export const LOCALE = "pt-PT";
export const TIME_ZONE = "Europe/Madrid";

const currencyFormatters = new Map<string, Intl.NumberFormat>();

/** "12,30 €", "R$ 10,00". */
export function money(amount: number, code = "EUR", options: { signed?: boolean; compact?: boolean } = {}) {
  const key = `${code}-${options.compact ? "c" : ""}`;
  let formatter = currencyFormatters.get(key);
  if (!formatter) {
    formatter = new Intl.NumberFormat(LOCALE, {
      style: "currency",
      currency: code,
      ...(options.compact ? { maximumFractionDigits: 0 } : {}),
    });
    currencyFormatters.set(key, formatter);
  }
  const text = formatter.format(Math.abs(amount) < 0.005 ? 0 : amount);
  return options.signed && amount > 0 ? `+${text}` : text;
}

export function percent(value: number | null | undefined, digits = 0) {
  if (value == null || Number.isNaN(value)) return "—";
  return new Intl.NumberFormat(LOCALE, { style: "percent", maximumFractionDigits: digits, minimumFractionDigits: digits }).format(value);
}

/** Variação relativa com sinal: "+12 %", "−3 %". */
export function change(value: number | null | undefined) {
  if (value == null || !Number.isFinite(value)) return "—";
  const text = percent(Math.abs(value));
  return value > 0 ? `+${text}` : value < 0 ? `−${text}` : text;
}

export function number(value: number, digits = 0) {
  return new Intl.NumberFormat(LOCALE, { maximumFractionDigits: digits, minimumFractionDigits: digits }).format(value);
}

const dateFormats = {
  short: { day: "numeric", month: "short" },
  medium: { day: "numeric", month: "short", year: "numeric" },
  long: { weekday: "long", day: "numeric", month: "long" },
  month: { month: "long", year: "numeric" },
  monthShort: { month: "short" },
  time: { hour: "2-digit", minute: "2-digit" },
  weekday: { weekday: "narrow" },
} as const satisfies Record<string, Intl.DateTimeFormatOptions>;

export function date(value: string | Date | null | undefined, style: keyof typeof dateFormats = "medium") {
  if (!value) return "—";
  const d = typeof value === "string" ? new Date(value) : value;
  return new Intl.DateTimeFormat(LOCALE, { ...dateFormats[style], timeZone: TIME_ZONE }).format(d);
}

/** Início do dia local de uma data, como Date. */
export function startOfDay(value: Date | string = new Date()) {
  const d = typeof value === "string" ? new Date(value) : new Date(value);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function addDays(value: Date, days: number) {
  const d = new Date(value);
  d.setDate(d.getDate() + days);
  return d;
}

/** Dias de calendário entre hoje e `value` (negativo se já passou). */
export function daysUntil(value: string | Date, from: Date = new Date()) {
  const a = startOfDay(from).getTime();
  const b = startOfDay(value).getTime();
  return Math.round((b - a) / 86_400_000);
}

/** "Vence hoje", "Vence amanhã", "Atrasada 2 dias" — como `DueDateText` no iPhone. */
export function due(value: string | Date, word = "Vence") {
  const days = daysUntil(value);
  if (days < -1) return `Atrasada ${-days} dias`;
  if (days === -1) return "Venceu ontem";
  if (days === 0) return `${word} hoje`;
  if (days === 1) return `${word} amanhã`;
  if (days <= 30) return `${word} em ${days} dias`;
  return `${word} a ${date(value, "medium")}`;
}

/** Valor para um <input type="date"> (AAAA-MM-DD, dia local). */
export function toDateInput(value: string | Date | null | undefined) {
  if (!value) return "";
  const d = typeof value === "string" ? new Date(value) : value;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** De um <input type="date"> para ISO, ao meio-dia local (como os formulários do iPhone). */
export function fromDateInput(value: string, hour = 12) {
  if (!value) return null;
  const [y, m, d] = value.split("-").map(Number);
  return new Date(y, m - 1, d, hour, 0, 0).toISOString();
}

/** "12,50", "1.234,56" ou "12.50" → número (aceita vírgula decimal). */
export function parseAmount(text: string): number | null {
  const cleaned = text.replace(/[^\d,.-]/g, "");
  if (!/\d/.test(cleaned)) return null;
  const lastComma = cleaned.lastIndexOf(",");
  const lastDot = cleaned.lastIndexOf(".");
  const decimal = lastComma > lastDot ? "," : ".";
  const thousands = decimal === "," ? "." : ",";
  const normalized = cleaned.split(thousands).join("").replace(decimal, ".");
  const value = Number(normalized);
  return Number.isFinite(value) ? value : null;
}
