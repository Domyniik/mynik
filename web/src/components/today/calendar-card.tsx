"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Card, Empty } from "@/components/shell/page-header";
import { type CalendarEvent, eventsOn } from "@/lib/calc/ical";
import { getDb } from "@/lib/db/store";
import { date } from "@/lib/format";

/** URL iCal do calendário: fica só neste computador (como o EventKit no iPhone). */
export const ICAL_KEY = "mynik.icalURL";

export function readICalURL() {
  try {
    return localStorage.getItem(ICAL_KEY) ?? "";
  } catch {
    return "";
  }
}

/** Eventos de hoje (Google Calendar ou iCloud por URL iCal secreto, só leitura). */
export function CalendarCard() {
  const [events, setEvents] = useState<CalendarEvent[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [url, setURL] = useState("");

  useEffect(() => {
    const saved = readICalURL();
    setURL(saved);
    if (!saved) return;
    let active = true;
    (async () => {
      try {
        const tauriFetch = (window as unknown as { __MYNIK_FETCH_TEXT__?: (u: string) => Promise<string> }).__MYNIK_FETCH_TEXT__;
        const ics = tauriFetch
          ? await tauriFetch(saved.replace(/^webcal:/, "https:"))
          : (await getDb().invoke<{ text: string }>("mynik-api", { action: "ical", url: saved })).text;
        if (active) setEvents(eventsOn(ics));
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : String(e));
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  return (
    <Card title="Agenda de hoje">
      {!url ? (
        <Empty title="Calendário por ligar">
          Cola o endereço iCal do teu calendário em <Link href="/definicoes/">Definições</Link> para veres aqui os eventos de hoje.
        </Empty>
      ) : error ? (
        <p className="m-0 text-sm text-warning">{error}</p>
      ) : events == null ? (
        <p className="m-0 text-sm text-muted-foreground">A carregar…</p>
      ) : events.length === 0 ? (
        <Empty title="Nada no calendário hoje" />
      ) : (
        events.map((e, i) => (
          <div key={i} className="flex gap-3 text-[13px]">
            <span className="w-12 shrink-0 text-muted-foreground">{e.allDay ? "Dia todo" : date(e.start, "time")}</span>
            <span className="flex min-w-0 flex-col"><span className="truncate font-medium">{e.title}</span>{e.location && <span className="truncate text-xs text-muted-foreground">{e.location}</span>}</span>
          </div>
        ))
      )}
    </Card>
  );
}
