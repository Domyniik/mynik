"use client";

import { ExternalLink, Plus } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { Chips, Field, FormDialog, Select, TabBar } from "@/components/common/fields";
import { Bar, Card, Empty, Kpi, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { applicationStatus, careerStats, courseStatus, describeExpiry, isActiveApplication } from "@/lib/calc/life";
import { newID, now } from "@/lib/db/client";
import type { CourseRow, JobApplicationRow } from "@/lib/db/schema";
import { mutate, useTable } from "@/lib/db/store";
import { date, due, fromDateInput, percent, toDateInput } from "@/lib/format";

const href = (link: string) => (link.trim() ? (link.includes("://") ? link.trim() : `https://${link.trim()}`) : null);
const inDays = (n: number) => new Date(Date.now() + n * 86_400_000);

function ApplicationForm({ app, open, onOpenChange }: { app: JobApplicationRow | null; open: boolean; onOpenChange: (o: boolean) => void }) {
  const [f, setF] = useState({ company: "", role: "", applied: "", status: "applied", follow: true, followDate: "", location: "", link: "", salary: "", contact: "", notes: "" });
  useEffect(() => {
    if (!open) return;
    setF({
      company: app?.company ?? "", role: app?.role ?? "", applied: toDateInput(app?.applied_at ?? new Date()), status: app?.status ?? "applied",
      follow: app ? Boolean(app.follow_up_date) : true, followDate: toDateInput(app?.follow_up_date ?? inDays(7)),
      location: app?.location ?? "", link: app?.link ?? "", salary: app?.salary ?? "", contact: app?.contact ?? "", notes: app?.notes ?? "",
    });
  }, [open, app]);
  const set = <K extends keyof typeof f>(k: K, v: (typeof f)[K]) => setF((s) => ({ ...s, [k]: v }));
  const save = async () => {
    const active = isActiveApplication(f.status);
    const row = {
      company: f.company.trim(), role: f.role.trim(), applied_at: fromDateInput(f.applied) ?? now(), status: f.status,
      follow_up_date: active && f.follow ? fromDateInput(f.followDate, 9) : null,
      location: f.location, link: f.link, salary: f.salary, contact: f.contact, notes: f.notes,
      ...(app?.status !== f.status ? { status_changed_at: now() } : {}),
    };
    if (app) await mutate.update("job_applications", app.id, row);
    else await mutate.insert("job_applications", { id: newID(), created_at: now(), status_changed_at: now(), ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={app ? "Editar candidatura" : "Nova candidatura"} onSubmit={save} valid={f.company.trim().length > 0} wide
      onDelete={app ? () => mutate.remove("job_applications", [app.id]) : undefined} deleteWhat="esta candidatura">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Empresa">{(id) => <Input id={id} autoFocus value={f.company} onChange={(e) => set("company", e.target.value)} />}</Field>
        <Field label="Cargo">{(id) => <Input id={id} value={f.role} onChange={(e) => set("role", e.target.value)} />}</Field>
        <Field label="Candidatei-me a">{(id) => <Input id={id} type="date" value={f.applied} onChange={(e) => set("applied", e.target.value)} />}</Field>
        <Field label="Estado">{(id) => <Select id={id} value={f.status} onChange={(v) => set("status", v)}>{Object.entries(applicationStatus).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
      </div>
      {isActiveApplication(f.status) && (
        <div className="flex flex-wrap items-center gap-3">
          <Switch id="follow" checked={f.follow} onCheckedChange={(v) => set("follow", v)} /><Label htmlFor="follow">Lembrar follow-up</Label>
          {f.follow && <Input type="date" aria-label="Follow-up a" value={f.followDate} onChange={(e) => set("followDate", e.target.value)} className="w-44" />}
        </div>
      )}
      <div className="grid grid-cols-2 gap-3">
        <Field label="Local">{(id) => <Input id={id} value={f.location} onChange={(e) => set("location", e.target.value)} placeholder="Cidade, remoto…" />}</Field>
        <Field label="Salário">{(id) => <Input id={id} value={f.salary} onChange={(e) => set("salary", e.target.value)} />}</Field>
        <Field label="Link do anúncio">{(id) => <Input id={id} value={f.link} onChange={(e) => set("link", e.target.value)} />}</Field>
        <Field label="Contacto (recrutador)">{(id) => <Input id={id} value={f.contact} onChange={(e) => set("contact", e.target.value)} />}</Field>
      </div>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={f.notes} onChange={(e) => set("notes", e.target.value)} />}</Field>
    </FormDialog>
  );
}

function CourseForm({ course, open, onOpenChange }: { course: CourseRow | null; open: boolean; onOpenChange: (o: boolean) => void }) {
  const [f, setF] = useState({ title: "", provider: "", status: "planned", progress: 0, link: "", credential: "", expires: false, expiresAt: "", notes: "" });
  useEffect(() => {
    if (!open) return;
    setF({
      title: course?.title ?? "", provider: course?.provider ?? "", status: course?.status ?? "planned", progress: Math.round((course?.progress ?? 0) * 100),
      link: course?.link ?? "", credential: course?.credential_id ?? "", expires: Boolean(course?.expires_at), expiresAt: toDateInput(course?.expires_at ?? inDays(730)), notes: course?.notes ?? "",
    });
  }, [open, course]);
  const set = <K extends keyof typeof f>(k: K, v: (typeof f)[K]) => setF((s) => ({ ...s, [k]: v }));
  const save = async () => {
    const completed = f.status === "completed";
    const row = {
      title: f.title.trim(), provider: f.provider, status: f.status, progress: completed ? 1 : f.progress / 100,
      completed_at: completed ? course?.completed_at ?? now() : null, link: f.link, credential_id: f.credential,
      expires_at: f.expires ? fromDateInput(f.expiresAt) : null, notes: f.notes,
    };
    if (course) await mutate.update("courses", course.id, row);
    else await mutate.insert("courses", { id: newID(), created_at: now(), ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={course ? "Editar curso" : "Novo curso"} onSubmit={save} valid={f.title.trim().length > 0}
      onDelete={course ? () => mutate.remove("courses", [course.id]) : undefined} deleteWhat="este curso">
      <Field label="Curso ou certificação">{(id) => <Input id={id} autoFocus value={f.title} onChange={(e) => set("title", e.target.value)} />}</Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Plataforma / entidade">{(id) => <Input id={id} value={f.provider} onChange={(e) => set("provider", e.target.value)} />}</Field>
        <Field label="Estado">{(id) => <Select id={id} value={f.status} onChange={(v) => set("status", v)}>{Object.entries(courseStatus).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
      </div>
      {f.status === "inProgress" && <Field label={`Progresso: ${f.progress} %`}>{(id) => <input id={id} type="range" min={0} max={100} value={f.progress} onChange={(e) => set("progress", Number(e.target.value))} className="accent-primary" />}</Field>}
      <div className="grid grid-cols-2 gap-3">
        <Field label="Link">{(id) => <Input id={id} value={f.link} onChange={(e) => set("link", e.target.value)} />}</Field>
        <Field label="ID da credencial">{(id) => <Input id={id} value={f.credential} onChange={(e) => set("credential", e.target.value)} />}</Field>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Switch id="expires" checked={f.expires} onCheckedChange={(v) => set("expires", v)} /><Label htmlFor="expires">O certificado expira</Label>
        {f.expires && <Input type="date" aria-label="Expira a" value={f.expiresAt} onChange={(e) => set("expiresAt", e.target.value)} className="w-44" />}
      </div>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={f.notes} onChange={(e) => set("notes", e.target.value)} />}</Field>
    </FormDialog>
  );
}

function Career() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const tab = params.get("tab") === "cursos" ? "cursos" : "candidaturas";
  const { rows: apps } = useTable("job_applications");
  const { rows: courses } = useTable("courses");
  const [filter, setFilter] = useState<string>("active");
  const [appForm, setAppForm] = useState<{ open: boolean; app: JobApplicationRow | null }>({ open: false, app: null });
  const [courseForm, setCourseForm] = useState<{ open: boolean; course: CourseRow | null }>({ open: false, course: null });
  const stats = careerStats(apps);
  useEffect(() => {
    if (params.get("novo")) {
      if (tab === "cursos") setCourseForm({ open: true, course: null });
      else setAppForm({ open: true, app: null });
      router.replace(`${pathname}${tab === "cursos" ? "?tab=cursos" : ""}`);
    }
  }, [params, router, pathname, tab]);
  const visible = apps
    .filter((a) => (filter === "all" ? true : filter === "active" ? isActiveApplication(a.status) : a.status === filter))
    .sort((a, b) => b.applied_at.localeCompare(a.applied_at));

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Carreira" subtitle="Candidaturas, cursos e certificações" actions={
        tab === "cursos"
          ? <Button onClick={() => setCourseForm({ open: true, course: null })}><Plus aria-hidden="true" /> Novo curso</Button>
          : <Button onClick={() => setAppForm({ open: true, app: null })}><Plus aria-hidden="true" /> Nova candidatura</Button>
      } />
      <TabBar tabs={[{ value: "candidaturas", label: "Candidaturas" }, { value: "cursos", label: "Cursos e certificações" }]} value={tab} onChange={(v) => router.replace(v === "cursos" ? `${pathname}?tab=cursos` : pathname)} />
      {tab === "candidaturas" ? (
        <>
          <section className="grid grid-cols-2 gap-4 xl:grid-cols-4">
            <Kpi label="Ativas" value={String(stats.active)} />
            <Kpi label="Entrevistas" value={String(stats.interviews)} />
            <Kpi label="Propostas" value={String(stats.offers)} />
            <Kpi label="Taxa de resposta" value={percent(stats.responseRate)} note={`${stats.responded} de ${stats.total}`} />
          </section>
          <Chips label="Estado" value={filter} onChange={setFilter} options={[{ value: "active", label: "Ativas" }, { value: "all", label: "Todas" }, ...Object.entries(applicationStatus).map(([v, l]) => ({ value: v, label: l }))]} />
          <Card>
            {visible.length === 0 ? <Empty title="Sem candidaturas" /> : visible.map((a) => (
              <div key={a.id} className="flex flex-wrap items-center gap-3 border-b border-surface py-2 last:border-0">
                <button type="button" onClick={() => setAppForm({ open: true, app: a })} className="flex min-w-48 flex-1 flex-col text-left">
                  <span className="font-medium">{a.company} — {a.role}</span>
                  <span className="text-xs text-muted-foreground">{applicationStatus[a.status]} · enviada a {date(a.applied_at)}{a.location && ` · ${a.location}`}</span>
                </button>
                {a.follow_up_date && isActiveApplication(a.status) && (
                  <span className="text-xs text-warning">{due(a.follow_up_date, "Follow-up")}</span>
                )}
                {a.follow_up_date && isActiveApplication(a.status) && (
                  <Button size="sm" variant="outline" onClick={() => void mutate.update("job_applications", a.id, { follow_up_date: inDays(7).toISOString() })}>Follow-up feito</Button>
                )}
                {href(a.link) && <a href={href(a.link)!} target="_blank" rel="noreferrer" aria-label="Abrir anúncio"><ExternalLink size={16} aria-hidden="true" /></a>}
              </div>
            ))}
          </Card>
        </>
      ) : (
        <div className="grid gap-4 lg:grid-cols-3">
          {Object.entries(courseStatus).map(([status, title]) => (
            <Card key={status} title={title}>
              {courses.filter((c) => c.status === status).length === 0 && <p className="m-0 text-sm text-muted-foreground">Nenhum</p>}
              {courses.filter((c) => c.status === status).map((c) => (
                <div key={c.id} className="flex flex-col gap-1.5">
                  <button type="button" onClick={() => setCourseForm({ open: true, course: c })} className="flex flex-col text-left">
                    <span className="font-medium">{c.title}</span>
                    <span className="text-xs text-muted-foreground">{[c.provider, c.completed_at && `concluído a ${date(c.completed_at)}`, c.expires_at && describeExpiry(c.expires_at)].filter(Boolean).join(" · ")}</span>
                  </button>
                  {status === "inProgress" && <Bar value={c.progress} height={6} />}
                  <div className="flex gap-2">
                    {status !== "completed" && <Button size="sm" variant="outline" onClick={() => void mutate.update("courses", c.id, { status: "completed", progress: 1, completed_at: now() })}>Marcar como concluído</Button>}
                    {href(c.link) && <a href={href(c.link)!} target="_blank" rel="noreferrer" className="text-sm">Abrir</a>}
                  </div>
                </div>
              ))}
            </Card>
          ))}
        </div>
      )}
      <ApplicationForm app={appForm.app} open={appForm.open} onOpenChange={(o) => setAppForm((s) => ({ ...s, open: o }))} />
      <CourseForm course={courseForm.course} open={courseForm.open} onOpenChange={(o) => setCourseForm((s) => ({ ...s, open: o }))} />
    </div>
  );
}

export default function CareerPage() {
  return (
    <Suspense>
      <Career />
    </Suspense>
  );
}
