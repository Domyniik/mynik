// Dias no fuso da app (Europe/Madrid), como o `Calendar.current` do iPhone.
export const TIME_ZONE = "Europe/Madrid";

/** "AAAA-MM-DD" do instante `date` no fuso. */
export function localDayKey(date: Date, tz = TIME_ZONE) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" }).format(date);
}

/** Desvio do fuso (minutos) num instante. */
function offsetMinutes(date: Date, tz: string) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone: tz, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit",
    }).formatToParts(date).map((p) => [p.type, p.value]),
  );
  const asUTC = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
  return (asUTC - date.getTime()) / 60000;
}

/** Meia-noite local do dia "AAAA-MM-DD", como Date. */
export function localMidnight(dayKey: string, tz = TIME_ZONE) {
  const [y, m, d] = dayKey.split("-").map(Number);
  const guess = new Date(Date.UTC(y, m - 1, d));
  return new Date(guess.getTime() - offsetMinutes(guess, tz) * 60000);
}

/** Dia "AAAA-MM-DD" `n` dias depois (n pode ser negativo). */
export function addDays(dayKey: string, n: number) {
  const [y, m, d] = dayKey.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

/** Chave dos registos diários do iPhone: segundos desde 1970 da meia-noite local ("1763679600.0"). */
export function dailyKey(dayKey: string) {
  const seconds = localMidnight(dayKey).getTime() / 1000;
  return Number.isInteger(seconds) ? `${seconds}.0` : String(seconds);
}
