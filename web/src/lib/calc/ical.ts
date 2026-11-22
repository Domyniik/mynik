/** Eventos de um dia a partir de um calendário iCal (.ics), com repetições simples. */
export interface CalendarEvent {
  title: string;
  start: Date;
  end: Date | null;
  allDay: boolean;
  location: string;
}

function unfold(text: string) {
  return text.replace(/\r?\n[ \t]/g, "");
}

function parseDate(value: string, params: string): { date: Date; allDay: boolean } | null {
  const allDay = /VALUE=DATE(?!-)/.test(params) || /^\d{8}$/.test(value);
  const m = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);
  if (!m) return null;
  const [, y, mo, d, h = "0", mi = "0", s = "0", z] = m;
  const date = z
    ? new Date(Date.UTC(+y, +mo - 1, +d, +h, +mi, +s))
    : new Date(+y, +mo - 1, +d, +h, +mi, +s); // hora local (TZID tratado como local)
  return { date, allDay };
}

const sameDay = (a: Date, b: Date) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
const weekdays = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

/** O evento com regra de repetição acontece no dia `day`? (DAILY, WEEKLY+BYDAY, MONTHLY, YEARLY; UNTIL e INTERVAL) */
function occursOn(start: Date, rrule: string, day: Date, exdates: Date[]) {
  if (exdates.some((d) => sameDay(d, day))) return false;
  const rule = Object.fromEntries(rrule.split(";").map((p) => p.split("=")));
  const first = new Date(start.getFullYear(), start.getMonth(), start.getDate());
  const target = new Date(day.getFullYear(), day.getMonth(), day.getDate());
  if (target < first) return false;
  if (rule.UNTIL) {
    const until = parseDate(rule.UNTIL, "");
    if (until && target > until.date) return false;
  }
  const interval = Number(rule.INTERVAL ?? 1);
  const days = Math.round((target.getTime() - first.getTime()) / 86_400_000);
  switch (rule.FREQ) {
    case "DAILY":
      return days % interval === 0;
    case "WEEKLY": {
      const byDay: string[] = rule.BYDAY ? rule.BYDAY.split(",") : [weekdays[first.getDay()]];
      const weeks = Math.floor((days + ((first.getDay() + 6) % 7)) / 7);
      return weeks % interval === 0 && byDay.includes(weekdays[target.getDay()]);
    }
    case "MONTHLY": {
      const months = (target.getFullYear() - first.getFullYear()) * 12 + target.getMonth() - first.getMonth();
      return months % interval === 0 && target.getDate() === first.getDate();
    }
    case "YEARLY":
      return (target.getFullYear() - first.getFullYear()) % interval === 0 && target.getMonth() === first.getMonth() && target.getDate() === first.getDate();
    default:
      return false;
  }
}

export function eventsOn(ics: string, day = new Date()): CalendarEvent[] {
  const events: CalendarEvent[] = [];
  for (const block of unfold(ics).split("BEGIN:VEVENT").slice(1)) {
    const body = block.split("END:VEVENT")[0];
    const fields = new Map<string, { params: string; value: string }[]>();
    for (const line of body.split(/\r?\n/)) {
      const m = line.match(/^([A-Z-]+)((?:;[^:]*)?):(.*)$/);
      if (!m) continue;
      const list = fields.get(m[1]) ?? [];
      list.push({ params: m[2], value: m[3] });
      fields.set(m[1], list);
    }
    const startField = fields.get("DTSTART")?.[0];
    const start = startField && parseDate(startField.value, startField.params);
    if (!start) continue;
    const endField = fields.get("DTEND")?.[0];
    const end = endField ? parseDate(endField.value, endField.params) : null;
    const rrule = fields.get("RRULE")?.[0]?.value;
    const exdates = (fields.get("EXDATE") ?? []).flatMap((f) => f.value.split(",").map((v) => parseDate(v, f.params)?.date).filter((d): d is Date => !!d));
    const happens = rrule ? occursOn(start.date, rrule, day, exdates) : start.allDay ? sameDay(start.date, day) || (end != null && start.date <= day && day < end.date) : sameDay(start.date, day);
    if (!happens) continue;
    const shifted = new Date(day.getFullYear(), day.getMonth(), day.getDate(), start.date.getHours(), start.date.getMinutes());
    const text = (k: string) => (fields.get(k)?.[0]?.value ?? "").replace(/\\n/g, " ").replace(/\\([,;\\])/g, "$1");
    events.push({ title: text("SUMMARY") || "Sem título", start: start.allDay ? start.date : shifted, end: end?.date ?? null, allDay: start.allDay, location: text("LOCATION") });
  }
  return events.sort((a, b) => Number(b.allDay) - Number(a.allDay) || a.start.getTime() - b.start.getTime());
}
