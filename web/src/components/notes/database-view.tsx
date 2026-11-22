"use client";

import { DndContext, type DragEndEvent, PointerSensor, useDraggable, useDroppable, useSensor, useSensors } from "@dnd-kit/core";
import { ChevronLeft, ChevronRight, Plus, Trash2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Segmented, Select } from "@/components/common/fields";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { dayValue, encodeProperties, encodeValues, type NoteProperty, properties, type PropertyType, propertyTypes, values } from "@/lib/calc/notes";
import { newID, now } from "@/lib/db/client";
import type { NoteRow } from "@/lib/db/schema";
import { mutate } from "@/lib/db/store";
import { cn } from "@/lib/utils";
import { createNote } from "./note-actions";

function setValue(row: NoteRow, property: NoteProperty, value: string) {
  return mutate.update("notes", row.id, { property_values: encodeValues({ ...values(row), [property.id]: value }), edited_at: now() });
}

function ValueEditor({ row, property, onSchema }: { row: NoteRow; property: NoteProperty; onSchema: (p: NoteProperty) => void }) {
  const value = values(row)[property.id] ?? "";
  switch (property.type) {
    case "checkbox":
      return <Checkbox checked={value === "true"} onCheckedChange={(v) => void setValue(row, property, v ? "true" : "")} aria-label={property.name} />;
    case "date":
      return <input type="date" value={value} aria-label={property.name} onChange={(e) => void setValue(row, property, e.target.value)} className="bg-transparent text-sm outline-none" />;
    case "select":
      return (
        <Select aria-label={property.name} value={value} className="h-7 border-0 bg-transparent px-1" onChange={(v) => {
          if (v === "__new") {
            const option = prompt("Nova opção")?.trim();
            if (!option) return;
            onSchema({ ...property, options: [...(property.options ?? []), option] });
            void setValue(row, property, option);
          } else void setValue(row, property, v);
        }}>
          <option value="">—</option>
          {(property.options ?? []).map((o) => <option key={o} value={o}>{o}</option>)}
          <option value="__new">Nova opção…</option>
        </Select>
      );
    default:
      return <input defaultValue={value} key={value} aria-label={property.name} inputMode={property.type === "number" ? "decimal" : undefined} onBlur={(e) => e.target.value !== value && void setValue(row, property, e.target.value)} className="w-full bg-transparent text-sm outline-none" />;
  }
}

function BoardCard({ row, open }: { row: NoteRow; open: () => void }) {
  const { attributes, listeners, setNodeRef, transform } = useDraggable({ id: row.id });
  return (
    <div ref={setNodeRef} {...attributes} {...listeners} style={transform ? { transform: `translate(${transform.x}px, ${transform.y}px)` } : undefined}
      className="cursor-grab rounded-lg border border-border bg-background p-2.5 text-sm">
      <button type="button" onPointerDown={(e) => e.stopPropagation()} onClick={open} className="text-left">{row.icon} {row.title || "Sem título"}</button>
    </div>
  );
}

function BoardColumn({ option, rows, open }: { option: string; rows: NoteRow[]; open: (r: NoteRow) => void }) {
  const { setNodeRef, isOver } = useDroppable({ id: option || "__none" });
  return (
    <div ref={setNodeRef} className={cn("flex min-h-40 w-64 shrink-0 flex-col gap-2 rounded-lg bg-card p-2", isOver && "ring-2 ring-primary")}>
      <span className="px-1 text-sm font-medium">{option || "Sem valor"} <span className="text-muted-foreground">{rows.length}</span></span>
      {rows.map((r) => <BoardCard key={r.id} row={r} open={() => open(r)} />)}
    </div>
  );
}

/** Base de dados: as linhas são as subpáginas; propriedades e valores em JSON (como no iPhone). */
export function DatabaseView({ database, notes }: { database: NoteRow; notes: NoteRow[] }) {
  const router = useRouter();
  const props = properties(database);
  const rows = notes.filter((n) => n.parent_id === database.id).sort((a, b) => a.sort_order - b.sort_order || a.created_at.localeCompare(b.created_at));
  const view = (["table", "board", "calendar"].includes(database.database_view) ? database.database_view : "table") as "table" | "board" | "calendar";
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 5 } }));
  const saveSchema = (next: NoteProperty[]) => void mutate.update("notes", database.id, { database_schema: encodeProperties(next), edited_at: now() });
  const updateProperty = (p: NoteProperty) => saveSchema(props.map((x) => (x.id === p.id ? p : x)));
  const open = (r: NoteRow) => router.push(`/notas/?id=${r.id}`);
  const addRow = async (extra: Record<string, string> = {}) => {
    const row = await createNote(notes, { parent_id: database.id, property_values: encodeValues(extra) });
    void mutate.update("notes", database.id, { edited_at: now() });
    return row;
  };
  const addProperty = (type: PropertyType) => saveSchema([...props, { id: newID(), name: propertyTypes[type], type, options: type === "select" ? ["Opção 1"] : [] }]);
  const boardProperty = props.find((p) => p.type === "select");
  const dateProperty = props.find((p) => p.type === "date");

  const onBoardDrop = (e: DragEndEvent) => {
    const row = rows.find((r) => r.id === e.active.id);
    if (!row || !e.over || !boardProperty) return;
    const option = e.over.id === "__none" ? "" : String(e.over.id);
    if ((values(row)[boardProperty.id] ?? "") !== option) void setValue(row, boardProperty, option);
  };

  // Calendário: semanas a começar à segunda (NoteDatabase.monthGrid).
  const first = new Date(month);
  first.setDate(1 - ((first.getDay() + 6) % 7));
  const days = Array.from({ length: 42 }, (_, i) => new Date(first.getFullYear(), first.getMonth(), first.getDate() + i));

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm text-muted-foreground">Base de dados · {rows.length} linhas</span>
        <div className="flex gap-2">
          <Segmented label="Vista" value={view} onChange={(v) => void mutate.update("notes", database.id, { database_view: v })}
            options={[{ value: "table", label: "Tabela" }, { value: "board", label: "Quadro" }, { value: "calendar", label: "Calendário" }]} />
          <DropdownMenu>
            <DropdownMenuTrigger asChild><Button variant="outline" size="sm"><Plus aria-hidden="true" /> Propriedade</Button></DropdownMenuTrigger>
            <DropdownMenuContent>{(Object.keys(propertyTypes) as PropertyType[]).map((t) => <DropdownMenuItem key={t} onSelect={() => addProperty(t)}>{propertyTypes[t]}</DropdownMenuItem>)}</DropdownMenuContent>
          </DropdownMenu>
          <Button size="sm" onClick={() => void addRow()}><Plus aria-hidden="true" /> Nova linha</Button>
        </div>
      </div>

      {view === "table" && (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="bg-card text-left text-xs text-muted-foreground">
                <th className="px-2 py-2 font-normal">Nome</th>
                {props.map((p) => (
                  <th key={p.id} className="px-2 py-2 font-normal">
                    <DropdownMenu>
                      <DropdownMenuTrigger className="hover:text-foreground">{p.name} · {propertyTypes[p.type]}</DropdownMenuTrigger>
                      <DropdownMenuContent>
                        <DropdownMenuItem onSelect={() => { const name = prompt("Nome", p.name)?.trim(); if (name) updateProperty({ ...p, name }); }}>Mudar o nome…</DropdownMenuItem>
                        <DropdownMenuItem className="text-danger" onSelect={() => {
                          saveSchema(props.filter((x) => x.id !== p.id));
                          for (const r of rows) if (values(r)[p.id] != null) { const v = values(r); delete v[p.id]; void mutate.update("notes", r.id, { property_values: encodeValues(v) }); }
                        }}>Apagar propriedade</DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </th>
                ))}
                <th />
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-t border-border">
                  <td className="px-2 py-1.5"><button type="button" onClick={() => open(r)} className="text-left font-medium">{r.icon} {r.title || "Sem título"}</button></td>
                  {props.map((p) => <td key={p.id} className="px-2 py-1"><ValueEditor row={r} property={p} onSchema={updateProperty} /></td>)}
                  <td className="w-8"><button type="button" aria-label="Apagar linha" className="text-muted-foreground" onClick={() => void mutate.remove("notes", [r.id])}><Trash2 size={14} /></button></td>
                </tr>
              ))}
            </tbody>
          </table>
          {rows.length === 0 && <p className="m-0 p-4 text-sm text-muted-foreground">Sem linhas. Cria uma com &quot;Nova linha&quot;.</p>}
        </div>
      )}

      {view === "board" && (boardProperty ? (
        <DndContext sensors={sensors} onDragEnd={onBoardDrop}>
          <div className="flex gap-3 overflow-x-auto pb-2">
            {rows.some((r) => !(boardProperty.options ?? []).includes(values(r)[boardProperty.id] ?? "")) && (
              <BoardColumn option="" rows={rows.filter((r) => !(boardProperty.options ?? []).includes(values(r)[boardProperty.id] ?? ""))} open={open} />
            )}
            {(boardProperty.options ?? []).map((o) => <BoardColumn key={o} option={o} rows={rows.filter((r) => values(r)[boardProperty.id] === o)} open={open} />)}
          </div>
        </DndContext>
      ) : <p className="m-0 text-sm text-muted-foreground">Acrescenta uma propriedade de seleção para agrupar o quadro.</p>)}

      {view === "calendar" && (dateProperty ? (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="icon" aria-label="Mês anterior" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}><ChevronLeft /></Button>
            <span className="min-w-36 text-center font-medium">{new Intl.DateTimeFormat("pt-PT", { month: "long", year: "numeric" }).format(month)}</span>
            <Button variant="ghost" size="icon" aria-label="Mês seguinte" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}><ChevronRight /></Button>
          </div>
          <div className="grid grid-cols-7 gap-px overflow-hidden rounded-lg border border-border bg-border text-xs">
            {["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"].map((d) => <div key={d} className="bg-card px-2 py-1 text-muted-foreground">{d}</div>)}
            {days.map((d) => {
              const key = dayValue(d);
              const items = rows.filter((r) => values(r)[dateProperty.id] === key);
              return (
                <div key={key} className={cn("group flex min-h-20 flex-col gap-1 bg-background p-1", d.getMonth() !== month.getMonth() && "opacity-40")}>
                  <div className="flex justify-between"><span>{d.getDate()}</span>
                    <button type="button" aria-label={`Nova neste dia (${key})`} className="opacity-0 group-hover:opacity-100" onClick={() => void addRow({ [dateProperty.id]: key })}><Plus size={12} /></button>
                  </div>
                  {items.map((r) => <button key={r.id} type="button" onClick={() => open(r)} className="truncate rounded bg-primary/20 px-1 text-left">{r.icon} {r.title || "Sem título"}</button>)}
                </div>
              );
            })}
          </div>
        </div>
      ) : <p className="m-0 text-sm text-muted-foreground">Acrescenta uma propriedade de data para ver o calendário.</p>)}
    </div>
  );
}
