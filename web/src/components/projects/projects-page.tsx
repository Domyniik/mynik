"use client";

import {
  DndContext, type DragEndEvent, KeyboardSensor, PointerSensor, useDraggable, useDroppable, useSensor, useSensors,
} from "@dnd-kit/core";
import { CalendarClock, Pencil, Plus } from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import { ColorPicker, Field, FormDialog, Segmented, Select, SymbolPicker } from "@/components/common/fields";
import { Bar, Card, Empty, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { isOverdue, statusPatch, taskColumns, taskStatus } from "@/lib/calc/life";
import { newID, now } from "@/lib/db/client";
import type { ProjectRow, TaskRow } from "@/lib/db/schema";
import { mutate, useTable } from "@/lib/db/store";
import { date, fromDateInput, toDateInput } from "@/lib/format";
import { colorHex, projectSymbols, SymbolIcon } from "@/lib/icons";
import { useSettings } from "@/lib/settings";
import { cn } from "@/lib/utils";
import { TaskForm } from "./task-form";

const projectStatus = { active: "Em curso", paused: "Em pausa", done: "Concluídos" } as const;
const LOOSE = "avulsas";

function ProjectForm({ project, open, onOpenChange, onDeleted }: { project: ProjectRow | null; open: boolean; onOpenChange: (o: boolean) => void; onDeleted: () => void }) {
  const { rows: tasks } = useTable("tasks");
  const [name, setName] = useState("");
  const [details, setDetails] = useState("");
  const [symbol, setSymbol] = useState("folder");
  const [color, setColor] = useState("blue");
  const [status, setStatus] = useState("active");
  const [due, setDue] = useState("");
  useEffect(() => {
    if (!open) return;
    setName(project?.name ?? "");
    setDetails(project?.details ?? "");
    setSymbol(project?.symbol_name ?? "folder");
    setColor(project?.color_name ?? "blue");
    setStatus(project?.status ?? "active");
    setDue(toDateInput(project?.due_date));
  }, [open, project]);
  const save = async () => {
    const row = { name: name.trim(), details, symbol_name: symbol, color_name: color, status, due_date: fromDateInput(due) };
    if (project) await mutate.update("projects", project.id, row);
    else await mutate.insert("projects", { id: newID(), created_at: now(), ...row });
  };
  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={project ? "Editar projeto" : "Novo projeto"}
      onSubmit={save}
      valid={name.trim().length > 0}
      deleteWhat="este projeto e as suas tarefas"
      onDelete={project ? async () => {
        // Como no iPhone: apagar o projeto apaga as tarefas (cascata).
        await mutate.remove("tasks", tasks.filter((t) => t.project_id === project.id).map((t) => t.id));
        await mutate.remove("projects", [project.id]);
        onDeleted();
      } : undefined}
    >
      <Field label="Nome">{(id) => <Input id={id} autoFocus value={name} onChange={(e) => setName(e.target.value)} />}</Field>
      <Field label="Descrição">{(id) => <Textarea id={id} rows={2} value={details} onChange={(e) => setDetails(e.target.value)} />}</Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Estado">{(id) => <Select id={id} value={status} onChange={setStatus}>{Object.entries(projectStatus).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
        <Field label="Prazo">{(id) => <Input id={id} type="date" value={due} onChange={(e) => setDue(e.target.value)} />}</Field>
      </div>
      <div className="flex flex-col gap-1.5"><Label>Ícone</Label><SymbolPicker symbols={projectSymbols} value={symbol} onChange={setSymbol} color={color} /></div>
      <div className="flex flex-col gap-1.5"><Label>Cor</Label><ColorPicker value={color} onChange={setColor} /></div>
    </FormDialog>
  );
}

function TaskCard({ task, onEdit, draggable }: { task: TaskRow; onEdit: (t: TaskRow) => void; draggable?: boolean }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({ id: task.id, disabled: !draggable });
  const overdue = isOverdue(task);
  return (
    <div
      ref={setNodeRef}
      {...(draggable ? attributes : {})}
      {...(draggable ? listeners : {})}
      aria-roledescription={draggable ? "tarefa arrastável" : undefined}
      style={transform ? { transform: `translate(${transform.x}px, ${transform.y}px)` } : undefined}
      className={cn(
        "flex cursor-grab flex-col gap-1.5 rounded-[10px] border border-border bg-background p-3 active:cursor-grabbing",
        isDragging && "z-10 opacity-80 shadow-xl",
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <span className={cn("text-sm", task.status === "done" && "text-muted-foreground line-through")}>{task.title}</span>
        <button type="button" aria-label={`Editar ${task.title}`} onPointerDown={(e) => e.stopPropagation()} onClick={() => onEdit(task)} className="text-muted-foreground hover:text-foreground">
          <Pencil size={14} aria-hidden="true" />
        </button>
      </div>
      <div className="flex flex-wrap gap-1.5 text-xs">
        {task.priority === 2 && <span className="rounded bg-loser-bg px-1.5 py-0.5 text-loser-fg">Alta</span>}
        {task.due_date && (
          <span className={cn("flex items-center gap-1", overdue ? "text-warning" : "text-muted-foreground")}>
            <CalendarClock size={12} aria-hidden="true" /> {date(task.due_date, "short")}
          </span>
        )}
      </div>
    </div>
  );
}

function Column({ status, tasks, onEdit, onAdd }: { status: keyof typeof taskStatus; tasks: TaskRow[]; onEdit: (t: TaskRow) => void; onAdd: () => void }) {
  const { setNodeRef, isOver } = useDroppable({ id: status });
  return (
    <section ref={setNodeRef} aria-label={taskStatus[status]} className={cn("flex min-h-64 flex-col gap-2 rounded-[14px] border border-border bg-card p-3", isOver && "border-primary")}>
      <div className="flex items-center justify-between px-1">
        <h3 className="m-0 text-sm font-semibold">{taskStatus[status]} <span className="text-muted-foreground">{tasks.length}</span></h3>
        <Button variant="ghost" size="icon" aria-label={`Adicionar tarefa em ${taskStatus[status]}`} onClick={onAdd}><Plus aria-hidden="true" /></Button>
      </div>
      {tasks.map((t) => <TaskCard key={t.id} task={t} onEdit={onEdit} draggable />)}
    </section>
  );
}

function Projects() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const { rows: projects } = useTable("projects");
  const { rows: tasks } = useTable("tasks");
  const { rows: notes } = useTable("notes");
  const { settings, set } = useSettings();
  const [projectForm, setProjectForm] = useState<{ open: boolean; project: ProjectRow | null }>({ open: false, project: null });
  const [taskForm, setTaskForm] = useState<{ open: boolean; task: TaskRow | null; status: string }>({ open: false, task: null, status: "todo" });
  const selectedID = params.get("projeto") ?? projects.find((p) => p.status === "active")?.id ?? LOOSE;
  const selected = projects.find((p) => p.id === selectedID) ?? null;
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }), useSensor(KeyboardSensor));

  useEffect(() => {
    if (params.get("novo")) {
      setTaskForm({ open: true, task: null, status: "todo" });
      router.replace(`${pathname}?projeto=${selectedID}`);
    }
  }, [params, router, pathname, selectedID]);

  const scoped = useMemo(() => tasks.filter((t) => (selectedID === LOOSE ? !t.project_id || !projects.some((p) => p.id === t.project_id) : t.project_id === selectedID)), [tasks, selectedID, projects]);
  const columns = taskColumns(scoped);
  const layout = settings.taskLayout === "list" ? "list" : "board";
  const linkedNotes = selected ? notes.filter((n) => n.linked_project_ids.includes(selected.id)) : [];
  const select = (id: string) => router.replace(`${pathname}?projeto=${id}`);
  const edit = (task: TaskRow) => setTaskForm({ open: true, task, status: task.status });

  const onDragEnd = (event: DragEndEvent) => {
    const status = event.over?.id as string | undefined;
    const task = tasks.find((t) => t.id === event.active.id);
    if (task && status && status !== task.status) void mutate.update("tasks", task.id, statusPatch(status));
  };

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Projetos"
        subtitle="Projetos com tarefas em Kanban ou em lista"
        actions={
          <>
            <Button variant="outline" onClick={() => setProjectForm({ open: true, project: null })}><Plus aria-hidden="true" /> Projeto</Button>
            <Button onClick={() => setTaskForm({ open: true, task: null, status: "todo" })}><Plus aria-hidden="true" /> Nova tarefa</Button>
          </>
        }
      />
      <div className="grid gap-4 lg:grid-cols-[260px_1fr]">
        <nav aria-label="Projetos" className="flex flex-col gap-4">
          {(Object.keys(projectStatus) as (keyof typeof projectStatus)[]).map((status) => {
            const list = projects.filter((p) => p.status === status).sort((a, b) => a.name.localeCompare(b.name, "pt"));
            if (list.length === 0) return null;
            return (
              <div key={status} className="flex flex-col gap-1">
                <span className="px-2 text-xs text-muted-foreground">{projectStatus[status]}</span>
                {list.map((p) => {
                  const all = tasks.filter((t) => t.project_id === p.id);
                  const done = all.filter((t) => t.status === "done").length;
                  return (
                    <button key={p.id} type="button" onClick={() => select(p.id)} aria-current={p.id === selectedID ? "page" : undefined}
                      className={cn("flex flex-col gap-1.5 rounded-lg px-2 py-2 text-left", p.id === selectedID ? "bg-sidebar-active" : "hover:bg-sidebar-active/60")}>
                      <span className="flex items-center gap-2"><SymbolIcon name={p.symbol_name} color={p.color_name} size={24} /><span className="flex-1 truncate">{p.name}</span><span className="text-xs text-muted-foreground">{all.length - done}</span></span>
                      {all.length > 0 && <Bar value={done / all.length} height={4} color={colorHex(p.color_name)} />}
                    </button>
                  );
                })}
              </div>
            );
          })}
          <button type="button" onClick={() => select(LOOSE)} aria-current={selectedID === LOOSE ? "page" : undefined}
            className={cn("rounded-lg px-2 py-2 text-left", selectedID === LOOSE ? "bg-sidebar-active" : "hover:bg-sidebar-active/60")}>
            Tarefas avulsas
          </button>
        </nav>

        <div className="flex min-w-0 flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex min-w-0 flex-col">
              <h2 className="m-0 flex items-center gap-2 text-lg font-semibold">
                {selected ? <><SymbolIcon name={selected.symbol_name} color={selected.color_name} size={28} />{selected.name}</> : "Tarefas avulsas"}
                {selected && <Button variant="ghost" size="icon" aria-label="Editar projeto" onClick={() => setProjectForm({ open: true, project: selected })}><Pencil aria-hidden="true" /></Button>}
              </h2>
              <span className="text-sm text-muted-foreground">
                {selected ? `${columns.done.length} de ${scoped.length} tarefas feitas${selected.due_date ? ` · prazo ${date(selected.due_date)}` : ""}` : "Tarefas que não pertencem a nenhum projeto."}
              </span>
              {selected?.details && <p className="m-0 mt-1 text-sm">{selected.details}</p>}
            </div>
            <Segmented label="Vista" value={layout} onChange={(v) => void set("taskLayout", v)} options={[{ value: "board", label: "Kanban" }, { value: "list", label: "Lista" }]} />
          </div>

          {layout === "board" ? (
            <DndContext sensors={sensors} onDragEnd={onDragEnd}>
              <div className="grid gap-3 md:grid-cols-3">
                {(Object.keys(taskStatus) as (keyof typeof taskStatus)[]).map((s) => (
                  <Column key={s} status={s} tasks={columns[s]} onEdit={edit} onAdd={() => setTaskForm({ open: true, task: null, status: s })} />
                ))}
              </div>
            </DndContext>
          ) : (
            <Card>
              {scoped.length === 0 ? <Empty title="Sem tarefas">Adiciona a primeira tarefa com ⌘N.</Empty> : [...columns.doing, ...columns.todo, ...columns.done].map((t) => (
                <div key={t.id} className="flex items-center gap-3">
                  <Checkbox checked={t.status === "done"} onCheckedChange={(v) => void mutate.update("tasks", t.id, statusPatch(v ? "done" : "todo"))} aria-label={`Concluir ${t.title}`} />
                  <button type="button" onClick={() => edit(t)} className={cn("flex-1 text-left", t.status === "done" && "text-muted-foreground line-through", isOverdue(t) && "text-warning")}>{t.title}</button>
                  <span className="text-xs text-muted-foreground">{taskStatus[t.status as keyof typeof taskStatus]}{t.due_date && ` · ${date(t.due_date, "short")}`}</span>
                  <Select aria-label="Mover para" value={t.status} onChange={(v) => void mutate.update("tasks", t.id, statusPatch(v))} className="h-8 w-32">
                    {Object.entries(taskStatus).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                  </Select>
                </div>
              ))}
            </Card>
          )}

          {selected && (
            <Card title="Notas ligadas">
              {linkedNotes.length === 0 ? <p className="m-0 text-sm text-muted-foreground">Liga páginas a este projeto no editor de notas (menção @ ou "Ligações").</p> : linkedNotes.map((n) => (
                <Link key={n.id} href={`/notas/?id=${n.id}`}>{n.icon} {n.title || "Sem título"}</Link>
              ))}
            </Card>
          )}
        </div>
      </div>
      <ProjectForm project={projectForm.project} open={projectForm.open} onOpenChange={(o) => setProjectForm((s) => ({ ...s, open: o }))} onDeleted={() => select(LOOSE)} />
      <TaskForm open={taskForm.open} onOpenChange={(o) => setTaskForm((s) => ({ ...s, open: o }))} task={taskForm.task} status={taskForm.status} projectID={selected?.id ?? null} />
    </div>
  );
}

export default function ProjectsPage() {
  return (
    <Suspense>
      <Projects />
    </Suspense>
  );
}
