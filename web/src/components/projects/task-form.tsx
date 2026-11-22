"use client";

import { useEffect, useState } from "react";
import { Field, FormDialog, Select } from "@/components/common/fields";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { statusPatch, taskPriority, taskStatus } from "@/lib/calc/life";
import { newID, now } from "@/lib/db/client";
import type { TaskRow } from "@/lib/db/schema";
import { mutate, useTable } from "@/lib/db/store";
import { fromDateInput, toDateInput } from "@/lib/format";

export function TaskForm({
  open, onOpenChange, task, projectID, status = "todo",
}: { open: boolean; onOpenChange: (o: boolean) => void; task?: TaskRow | null; projectID?: string | null; status?: string }) {
  const { rows: projects } = useTable("projects");
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const [state, setState] = useState("todo");
  const [priority, setPriority] = useState("1");
  const [due, setDue] = useState("");
  const [project, setProject] = useState("");

  useEffect(() => {
    if (!open) return;
    setTitle(task?.title ?? "");
    setNotes(task?.notes ?? "");
    setState(task?.status ?? status);
    setPriority(String(task?.priority ?? 1));
    setDue(toDateInput(task?.due_date));
    setProject(task ? task.project_id ?? "" : projectID ?? "");
  }, [open, task, projectID, status]);

  async function save() {
    const row = { title: title.trim(), notes, priority: Number(priority), due_date: fromDateInput(due, 18), project_id: project || null };
    if (task) {
      await mutate.update("tasks", task.id, { ...row, ...(task.status !== state ? statusPatch(state) : {}) });
    } else {
      await mutate.insert("tasks", { id: newID(), created_at: now(), ...row, ...statusPatch(state) });
    }
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={task ? "Editar tarefa" : "Nova tarefa"}
      onSubmit={save}
      valid={title.trim().length > 0}
      onDelete={task ? () => mutate.remove("tasks", [task.id]) : undefined}
      deleteWhat="esta tarefa"
    >
      <Field label="Tarefa">{(id) => <Input id={id} autoFocus value={title} onChange={(e) => setTitle(e.target.value)} />}</Field>
      <div className="grid grid-cols-3 gap-3">
        <Field label="Estado">{(id) => <Select id={id} value={state} onChange={setState}>{Object.entries(taskStatus).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
        <Field label="Prioridade">{(id) => <Select id={id} value={priority} onChange={setPriority}>{taskPriority.map((l, i) => <option key={l} value={i}>{l}</option>)}</Select>}</Field>
        <Field label="Prazo">{(id) => <Input id={id} type="date" value={due} onChange={(e) => setDue(e.target.value)} />}</Field>
      </div>
      <Field label="Projeto">
        {(id) => (
          <Select id={id} value={project} onChange={setProject}>
            <option value="">Sem projeto</option>
            {projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </Select>
        )}
      </Field>
      <Field label="Notas">{(id) => <Textarea id={id} rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />}</Field>
    </FormDialog>
  );
}
