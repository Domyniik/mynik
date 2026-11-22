"use client";

import { Check, Flame, Pencil, Plus } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { ColorPicker, Field, FormDialog, SymbolPicker } from "@/components/common/fields";
import { Card, Empty, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { checkFor, habitProgress } from "@/lib/calc/life";
import { newID, now } from "@/lib/db/client";
import type { HabitRow } from "@/lib/db/schema";
import { mutate, useTables } from "@/lib/db/store";
import { colorHex, habitSymbols, SymbolIcon } from "@/lib/icons";
import { cn } from "@/lib/utils";

/** Marca ou desmarca o dia de hoje (um registo por dia, como `HabitService.toggle`). */
export async function toggleHabitToday(habit: HabitRow, checks: Parameters<typeof checkFor>[1]) {
  const existing = checkFor(habit, checks);
  if (existing) return mutate.remove("habit_checks", [existing.id]);
  const day = new Date();
  day.setHours(0, 0, 0, 0);
  await mutate.insert("habit_checks", { id: newID(), day: day.toISOString(), created_at: now(), habit_id: habit.id });
}

function HabitForm({ habit, open, onOpenChange, nextOrder }: { habit: HabitRow | null; open: boolean; onOpenChange: (o: boolean) => void; nextOrder: number }) {
  const [name, setName] = useState("");
  const [symbol, setSymbol] = useState("checkmark.circle");
  const [color, setColor] = useState("green");
  const [target, setTarget] = useState(7);
  const [archived, setArchived] = useState(false);
  useEffect(() => {
    if (!open) return;
    setName(habit?.name ?? "");
    setSymbol(habit?.symbol_name ?? "checkmark.circle");
    setColor(habit?.color_name ?? "green");
    setTarget(habit?.target_per_week ?? 7);
    setArchived(habit?.is_archived ?? false);
  }, [open, habit]);
  const save = async () => {
    const row = { name: name.trim(), symbol_name: symbol, color_name: color, target_per_week: Math.min(7, Math.max(1, target)), is_archived: archived };
    if (habit) await mutate.update("habits", habit.id, row);
    else await mutate.insert("habits", { id: newID(), sort_order: nextOrder, created_at: now(), ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={habit ? "Editar hábito" : "Novo hábito"} onSubmit={save} valid={name.trim().length > 0}
      onDelete={habit ? () => mutate.remove("habits", [habit.id]) : undefined} deleteWhat="este hábito">
      <Field label="Nome">{(id) => <Input id={id} autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex.: Ginásio" />}</Field>
      <Field label="Objetivo" hint="Dias por semana (1 a 7).">
        {(id) => <Input id={id} type="number" min={1} max={7} value={target} onChange={(e) => setTarget(Number(e.target.value))} className="w-24" />}
      </Field>
      <div className="flex flex-col gap-1.5"><Label>Ícone</Label><SymbolPicker symbols={habitSymbols} value={symbol} onChange={setSymbol} color={color} /></div>
      <div className="flex flex-col gap-1.5"><Label>Cor</Label><ColorPicker value={color} onChange={setColor} /></div>
      {habit && <div className="flex items-center gap-2"><Checkbox id="habit-archived" checked={archived} onCheckedChange={(v) => setArchived(v === true)} /><Label htmlFor="habit-archived">Arquivado</Label></div>}
    </FormDialog>
  );
}

const weekday = (offset: number) => {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  return new Intl.DateTimeFormat("pt-PT", { weekday: "narrow" }).format(d).toUpperCase();
};

function Habits() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const { data } = useTables("habits", "habit_checks");
  const [form, setForm] = useState<{ open: boolean; habit: HabitRow | null }>({ open: false, habit: null });
  const habits = data.habits.filter((h) => !h.is_archived).sort((a, b) => a.sort_order - b.sort_order);
  const archived = data.habits.filter((h) => h.is_archived);
  const doneToday = habits.filter((h) => habitProgress(h, data.habit_checks).isDoneToday).length;

  useEffect(() => {
    if (params.get("novo")) {
      setForm({ open: true, habit: null });
      router.replace(pathname);
    }
  }, [params, router, pathname]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Hábitos" subtitle={habits.length ? `${doneToday} de ${habits.length} feitos hoje` : "Marca todos os dias para construir uma sequência"}
        actions={<Button onClick={() => setForm({ open: true, habit: null })}><Plus aria-hidden="true" /> Novo hábito</Button>} />
      <Card>
        {habits.length === 0 ? <Empty icon={<Flame aria-hidden="true" />} title="Sem hábitos">Cria um hábito e marca-o todos os dias para construir uma sequência.</Empty> : habits.map((h) => {
          const p = habitProgress(h, data.habit_checks);
          const hex = colorHex(h.color_name);
          return (
            <div key={h.id} className="flex flex-wrap items-center gap-4 border-b border-surface py-2 last:border-0">
              <button type="button" onClick={() => void toggleHabitToday(h, data.habit_checks)} aria-pressed={p.isDoneToday} aria-label={`${p.isDoneToday ? "Desmarcar" : "Marcar"} ${h.name} hoje`}
                className="flex size-10 items-center justify-center rounded-full border-2" style={{ borderColor: hex, background: p.isDoneToday ? hex : "transparent", color: p.isDoneToday ? "#0e0f11" : hex }}>
                {p.isDoneToday ? <Check size={20} aria-hidden="true" /> : <SymbolIcon name={h.symbol_name} color={h.color_name} size={22} className="bg-transparent" />}
              </button>
              <div className="flex min-w-40 flex-1 flex-col">
                <span className="font-medium">{h.name}</span>
                <span className={cn("text-xs", p.isWeekGoalReached ? "text-positive" : "text-muted-foreground")}>
                  {p.thisWeek} de {p.target} esta semana{p.streak > 0 && ` · 🔥 ${p.streak} ${p.streak === 1 ? "dia" : "dias"} seguidos`}
                </span>
              </div>
              <div className="flex gap-1.5" aria-label="Últimos 7 dias">
                {p.lastSevenDays.map((done, i) => (
                  <span key={i} className="flex flex-col items-center gap-1 text-[10px] text-muted-foreground">
                    <span className="size-5 rounded-full" style={{ background: done ? hex : "var(--track)" }} aria-label={done ? "feito" : "por fazer"} />
                    {weekday(i - 6)}
                  </span>
                ))}
              </div>
              <Button variant="ghost" size="icon" aria-label={`Editar ${h.name}`} onClick={() => setForm({ open: true, habit: h })}><Pencil aria-hidden="true" /></Button>
            </div>
          );
        })}
      </Card>
      {archived.length > 0 && (
        <Card title="Arquivados">
          {archived.map((h) => (
            <button key={h.id} type="button" onClick={() => setForm({ open: true, habit: h })} className="flex items-center gap-2 text-left text-muted-foreground">
              <SymbolIcon name={h.symbol_name} color={h.color_name} size={24} />{h.name}
            </button>
          ))}
        </Card>
      )}
      <HabitForm habit={form.habit} open={form.open} onOpenChange={(o) => setForm((s) => ({ ...s, open: o }))} nextOrder={data.habits.length} />
    </div>
  );
}

export default function HabitsPage() {
  return (
    <Suspense>
      <Habits />
    </Suspense>
  );
}
