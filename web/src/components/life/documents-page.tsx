"use client";

import { Eye, ImagePlus, Lock, Plus, Trash2 } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useState } from "react";
import { toast } from "sonner";
import { Field, FormDialog, Select } from "@/components/common/fields";
import { Card, Empty, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { describeExpiry, documentKinds, documentStatus, type DocumentStatus, documentStatusTitle, maskNumber } from "@/lib/calc/life";
import { newID, now } from "@/lib/db/client";
import type { DocumentRow } from "@/lib/db/schema";
import { mutate, useTable } from "@/lib/db/store";
import { date, fromDateInput, toDateInput } from "@/lib/format";
import { addPhoto, checkPin, deletePhoto, hasPin, listPhotos, type LocalPhoto } from "@/lib/lock";
import { cn } from "@/lib/utils";

function DocumentForm({ doc, open, onOpenChange }: { doc: DocumentRow | null; open: boolean; onOpenChange: (o: boolean) => void }) {
  const [kind, setKind] = useState("idCard");
  const [title, setTitle] = useState("");
  const [number, setNumber] = useState("");
  const [issuer, setIssuer] = useState("");
  const [hasExpiry, setHasExpiry] = useState(true);
  const [expiry, setExpiry] = useState("");
  const [remind, setRemind] = useState("60");
  const [notes, setNotes] = useState("");
  useEffect(() => {
    if (!open) return;
    setKind(doc?.kind ?? "idCard");
    setTitle(doc?.title ?? "");
    setNumber(doc?.number ?? "");
    setIssuer(doc?.issuer ?? "");
    setHasExpiry(doc ? Boolean(doc.expiry_date) : true);
    setExpiry(toDateInput(doc?.expiry_date ?? new Date(Date.now() + 5 * 365 * 86_400_000)));
    setRemind(String(doc?.remind_days_before ?? 60));
    setNotes(doc?.notes ?? "");
  }, [open, doc]);
  const save = async () => {
    const row = { kind, title, number, issuer, expiry_date: hasExpiry ? fromDateInput(expiry) : null, remind_days_before: Number(remind), notes };
    if (doc) await mutate.update("documents", doc.id, row);
    else await mutate.insert("documents", { id: newID(), created_at: now(), ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={doc ? "Editar documento" : "Novo documento"} onSubmit={save}
      onDelete={doc ? () => mutate.remove("documents", [doc.id]) : undefined} deleteWhat="este documento">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Tipo">{(id) => <Select id={id} value={kind} onChange={setKind}>{Object.entries(documentKinds).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
        <Field label="Nome (opcional)">{(id) => <Input id={id} value={title} onChange={(e) => setTitle(e.target.value)} placeholder={documentKinds[kind]} />}</Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Número">{(id) => <Input id={id} value={number} onChange={(e) => setNumber(e.target.value)} autoComplete="off" />}</Field>
        <Field label="Emitido por (opcional)">{(id) => <Input id={id} value={issuer} onChange={(e) => setIssuer(e.target.value)} />}</Field>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Switch id="has-expiry" checked={hasExpiry} onCheckedChange={setHasExpiry} /><Label htmlFor="has-expiry">Tem validade</Label>
        {hasExpiry && (
          <>
            <Input type="date" aria-label="Expira a" value={expiry} onChange={(e) => setExpiry(e.target.value)} className="w-44" />
            <Select aria-label="Avisar" value={remind} onChange={setRemind} className="w-44">
              <option value="30">1 mês antes</option><option value="60">2 meses antes</option><option value="90">3 meses antes</option><option value="180">6 meses antes</option>
            </Select>
          </>
        )}
      </div>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} />}</Field>
    </FormDialog>
  );
}

/** Números e fotos atrás do PIN (o Face ID do iPhone). As fotos ficam neste computador. */
function DocumentDetail({ doc, onEdit }: { doc: DocumentRow; onEdit: () => void }) {
  const [unlocked, setUnlocked] = useState(false);
  const [askPin, setAskPin] = useState(false);
  const [pin, setPin] = useState("");
  const [photos, setPhotos] = useState<(LocalPhoto & { url: string })[]>([]);
  const load = useCallback(async () => {
    const list = await listPhotos(doc.id);
    setPhotos((old) => {
      old.forEach((p) => URL.revokeObjectURL(p.url));
      return list.map((p) => ({ ...p, url: URL.createObjectURL(p.blob) }));
    });
  }, [doc.id]);
  useEffect(() => {
    setUnlocked(false);
    setPhotos([]);
  }, [doc.id]);
  useEffect(() => {
    if (unlocked) void load();
    const lock = () => document.hidden && setUnlocked(false);
    document.addEventListener("visibilitychange", lock);
    return () => document.removeEventListener("visibilitychange", lock);
  }, [unlocked, load]);
  const unlock = () => (hasPin() ? setAskPin(true) : setUnlocked(true));
  return (
    <Card title={doc.title.trim() || documentKinds[doc.kind]} action={<Button variant="ghost" size="sm" onClick={onEdit}>Editar</Button>}>
      <dl className="m-0 grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
        <dt className="text-muted-foreground">Tipo</dt><dd className="m-0">{documentKinds[doc.kind]}</dd>
        <dt className="text-muted-foreground">Número</dt><dd className="m-0 font-mono">{unlocked ? doc.number || "—" : maskNumber(doc.number) || "—"}</dd>
        {doc.issuer && <><dt className="text-muted-foreground">Emitido por</dt><dd className="m-0">{doc.issuer}</dd></>}
        <dt className="text-muted-foreground">Validade</dt><dd className="m-0">{describeExpiry(doc.expiry_date)}{doc.expiry_date && ` (${date(doc.expiry_date)})`}</dd>
      </dl>
      {doc.notes && <p className="m-0 text-sm text-muted-foreground">{doc.notes}</p>}
      {!unlocked ? (
        <Button variant="outline" onClick={unlock}><Eye aria-hidden="true" /> Mostrar número e fotos</Button>
      ) : (
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between"><span className="text-sm font-medium">Fotos (só neste computador)</span>
            <label className="inline-flex cursor-pointer items-center gap-1.5 text-sm text-link">
              <ImagePlus size={16} aria-hidden="true" /> Adicionar fotos
              <input type="file" accept="image/*" multiple className="hidden" onChange={async (e) => {
                for (const file of e.target.files ?? []) await addPhoto(doc.id, file);
                await load();
              }} />
            </label>
          </div>
          <div className="grid grid-cols-2 gap-2">
            {photos.map((p) => (
              <figure key={p.id} className="relative m-0">
                <img src={p.url} alt={`Foto de ${doc.title || documentKinds[doc.kind]}`} className="w-full rounded-lg object-cover" />
                <Button size="icon" variant="secondary" className="absolute right-1 top-1" aria-label="Apagar foto" onClick={async () => { await deletePhoto(p.id); await load(); }}><Trash2 aria-hidden="true" /></Button>
              </figure>
            ))}
          </div>
          {photos.length === 0 && <p className="m-0 text-xs text-muted-foreground">Sem fotos neste computador. As do iPhone não saem de lá.</p>}
          {!hasPin() && <p className="m-0 text-xs text-warning">Define um PIN em Definições → Privacidade para proteger os números e as fotos.</p>}
        </div>
      )}
      <FormDialog open={askPin} onOpenChange={setAskPin} title="PIN do Mynik" submitLabel="Desbloquear" valid={pin.length >= 4}
        onSubmit={async () => {
          if (await checkPin(pin)) setUnlocked(true);
          else {
            toast.error("PIN errado");
            throw new Error("PIN errado");
          }
          setPin("");
        }}>
        <Field label="PIN">{(id) => <Input id={id} type="password" inputMode="numeric" autoFocus value={pin} onChange={(e) => setPin(e.target.value)} />}</Field>
      </FormDialog>
    </Card>
  );
}

const order: DocumentStatus[] = ["expired", "expiringSoon", "valid", "noExpiry"];

function Documents() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const { rows } = useTable("documents");
  const [form, setForm] = useState<{ open: boolean; doc: DocumentRow | null }>({ open: false, doc: null });
  const selected = rows.find((d) => d.id === params.get("id")) ?? null;
  useEffect(() => {
    if (params.get("novo")) {
      setForm({ open: true, doc: null });
      router.replace(pathname);
    }
  }, [params, router, pathname]);
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Documentos" subtitle="Validades com aviso antes de expirar" actions={<Button onClick={() => setForm({ open: true, doc: null })}><Plus aria-hidden="true" /> Novo documento</Button>} />
      <div className="grid gap-4 lg:grid-cols-[1fr_1fr]">
        <div className="flex flex-col gap-4">
          {rows.length === 0 && <Card><Empty icon={<Lock aria-hidden="true" />} title="Sem documentos" /></Card>}
          {order.map((status) => {
            const list = rows.filter((d) => documentStatus(d.expiry_date, d.remind_days_before) === status).sort((a, b) => (a.expiry_date ?? "9").localeCompare(b.expiry_date ?? "9"));
            if (list.length === 0) return null;
            return (
              <Card key={status} title={documentStatusTitle[status]}>
                {list.map((d) => (
                  <button key={d.id} type="button" onClick={() => router.replace(`${pathname}?id=${d.id}`)} aria-current={selected?.id === d.id ? "true" : undefined}
                    className={cn("flex items-center justify-between gap-3 rounded-lg p-1.5 text-left", selected?.id === d.id && "bg-sidebar-active")}>
                    <span className="flex flex-col"><span className="font-medium">{d.title.trim() || documentKinds[d.kind]}</span><span className="text-xs text-muted-foreground">{documentKinds[d.kind]}</span></span>
                    <span className={cn("text-xs", status === "expired" ? "text-danger" : status === "expiringSoon" ? "text-warning" : "text-muted-foreground")}>{describeExpiry(d.expiry_date)}</span>
                  </button>
                ))}
              </Card>
            );
          })}
        </div>
        {selected ? <DocumentDetail doc={selected} onEdit={() => setForm({ open: true, doc: selected })} /> : <Card><Empty title="Escolhe um documento" /></Card>}
      </div>
      <DocumentForm doc={form.doc} open={form.open} onOpenChange={(o) => setForm((s) => ({ ...s, open: o }))} />
    </div>
  );
}

export default function DocumentsPage() {
  return (
    <Suspense>
      <Documents />
    </Suspense>
  );
}
