"use client";

import { Check, Fuel, MapPin, Pencil, Plus, Wrench } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import { Bar as RBar, BarChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { toast } from "sonner";
import { Field, FormDialog, MoneyInput, Select } from "@/components/common/fields";
import { Card, Empty, Kpi, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { currentOdometer, deadlineKinds, fuelEconomy, fuelTypes, maintenanceKinds } from "@/lib/calc/life";
import { newID, now } from "@/lib/db/client";
import type { CarDeadlineRow, FuelEntryRow, MaintenanceRow, VehicleRow } from "@/lib/db/schema";
import { getDb, mutate, useTables } from "@/lib/db/store";
import { date, due, fromDateInput, money, number, toDateInput } from "@/lib/format";
import { useSession } from "@/lib/session";
import { useSettings } from "@/lib/settings";
import { removeLinked, upsertLinkedExpense } from "./linked";

type Ctx = Parameters<typeof upsertLinkedExpense>[1];
const km = (n: number) => `${number(n)} km`;

function VehicleForm({ vehicle, open, onOpenChange, onSaved }: { vehicle: VehicleRow | null; open: boolean; onOpenChange: (o: boolean) => void; onSaved: (id: string) => void }) {
  const { data } = useTables("fuel_entries", "maintenance_records", "car_deadlines");
  const [name, setName] = useState("");
  const [plate, setPlate] = useState("");
  const [fuel, setFuel] = useState("gasoline95");
  const [initial, setInitial] = useState(0);
  const [notes, setNotes] = useState("");
  useEffect(() => {
    if (!open) return;
    setName(vehicle?.name ?? "");
    setPlate(vehicle?.plate ?? "");
    setFuel(vehicle?.fuel_type ?? "gasoline95");
    setInitial(vehicle?.initial_odometer ?? 0);
    setNotes(vehicle?.notes ?? "");
  }, [open, vehicle]);
  const save = async () => {
    const row = { name: name.trim(), plate, fuel_type: fuel, initial_odometer: initial, notes };
    if (vehicle) await mutate.update("vehicles", vehicle.id, row);
    else onSaved((await mutate.insert("vehicles", { id: newID(), created_at: now(), ...row })).id);
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={vehicle ? "Editar veículo" : "Novo veículo"} onSubmit={save} valid={name.trim().length > 0}
      deleteWhat="este veículo, os abastecimentos, manutenções e prazos"
      onDelete={vehicle ? async () => {
        const of = <T extends { vehicle_id: string | null; id: string }>(rows: T[]) => rows.filter((r) => r.vehicle_id === vehicle.id).map((r) => r.id);
        await mutate.remove("fuel_entries", of(data.fuel_entries));
        await mutate.remove("maintenance_records", of(data.maintenance_records));
        await mutate.remove("car_deadlines", of(data.car_deadlines));
        await mutate.remove("vehicles", [vehicle.id]);
      } : undefined}>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Nome">{(id) => <Input id={id} autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex.: Golf" />}</Field>
        <Field label="Matrícula">{(id) => <Input id={id} value={plate} onChange={(e) => setPlate(e.target.value)} />}</Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Combustível">{(id) => <Select id={id} value={fuel} onChange={setFuel}>{Object.entries(fuelTypes).map(([v, f]) => <option key={v} value={v}>{f.title}</option>)}</Select>}</Field>
        <Field label="Km iniciais">{(id) => <Input id={id} type="number" value={initial} onChange={(e) => setInitial(Number(e.target.value))} />}</Field>
      </div>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} />}</Field>
    </FormDialog>
  );
}

function FuelForm({ vehicle, entry, open, onOpenChange, ctx }: { vehicle: VehicleRow; entry: FuelEntryRow | null; open: boolean; onOpenChange: (o: boolean) => void; ctx: Ctx }) {
  const [day, setDay] = useState(toDateInput(new Date()));
  const [odometer, setOdometer] = useState(0);
  const [quantity, setQuantity] = useState<number | null>(null);
  const [total, setTotal] = useState<number | null>(null);
  const [full, setFull] = useState(true);
  const [station, setStation] = useState("");
  const [post, setPost] = useState(true);
  useEffect(() => {
    if (!open) return;
    setDay(toDateInput(entry?.date ?? new Date()));
    setOdometer(entry?.odometer ?? 0);
    setQuantity(entry?.quantity ?? null);
    setTotal(entry?.total_cost ?? null);
    setFull(entry?.is_full_tank ?? true);
    setStation(entry?.station ?? "");
    setPost(entry ? entry.transaction_id !== "" : true);
  }, [open, entry]);
  const save = async () => {
    const id = entry?.id ?? newID();
    const dateISO = fromDateInput(day, 19) ?? now();
    const externalID = entry?.transaction_id || `car-fuel-${id}`;
    const name = vehicle.name.trim() || "Carro";
    const linked = post
      ? await upsertLinkedExpense({ externalID, title: station ? `Combustível · ${station}` : `Combustível · ${name}`, amount: total ?? 0, currency: "EUR", date: dateISO, categoryName: "Carro", notes: `Abastecimento de ${name} aos ${number(odometer)} km.` }, ctx)
      : (entry?.transaction_id && (await removeLinked(entry.transaction_id, ctx)), null);
    const row = { date: dateISO, odometer, quantity: quantity ?? 0, total_cost: total ?? 0, is_full_tank: full, station, transaction_id: linked ? externalID : "", vehicle_id: vehicle.id };
    if (entry) await mutate.update("fuel_entries", entry.id, row);
    else await mutate.insert("fuel_entries", { id, created_at: now(), currency_code: "EUR", notes: "", ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={entry ? "Editar abastecimento" : "Novo abastecimento"} onSubmit={save} valid={(quantity ?? 0) > 0 && (total ?? 0) > 0 && odometer > 0}
      onDelete={entry ? async () => { if (entry.transaction_id) await removeLinked(entry.transaction_id, ctx); await mutate.remove("fuel_entries", [entry.id]); } : undefined} deleteWhat="este abastecimento">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Data">{(id) => <Input id={id} type="date" value={day} onChange={(e) => setDay(e.target.value)} />}</Field>
        <Field label="Km">{(id) => <Input id={id} type="number" autoFocus value={odometer || ""} onChange={(e) => setOdometer(Number(e.target.value))} />}</Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field label={`Quantidade (${fuelTypes[vehicle.fuel_type]?.unit ?? "L"})`}>{(id) => <MoneyInput id={id} value={quantity} onChange={setQuantity} placeholder="0,00" />}</Field>
        <Field label="Total" hint={quantity && total ? `Preço: ${money(total / quantity)}/${fuelTypes[vehicle.fuel_type]?.unit ?? "L"}` : undefined}>{(id) => <MoneyInput id={id} value={total} onChange={setTotal} />}</Field>
      </div>
      <Field label="Posto (opcional)">{(id) => <Input id={id} value={station} onChange={(e) => setStation(e.target.value)} />}</Field>
      <div className="flex items-center gap-2"><Switch id="full" checked={full} onCheckedChange={setFull} /><Label htmlFor="full">Depósito atestado</Label></div>
      <div className="flex items-center gap-2"><Switch id="post-fuel" checked={post} onCheckedChange={setPost} /><Label htmlFor="post-fuel">Lançar nas Finanças (Carro)</Label></div>
    </FormDialog>
  );
}

function MaintenanceForm({ vehicle, record, open, onOpenChange, ctx }: { vehicle: VehicleRow; record: MaintenanceRow | null; open: boolean; onOpenChange: (o: boolean) => void; ctx: Ctx }) {
  const [kind, setKind] = useState("service");
  const [title, setTitle] = useState("");
  const [day, setDay] = useState(toDateInput(new Date()));
  const [odometer, setOdometer] = useState(0);
  const [cost, setCost] = useState<number | null>(null);
  const [workshop, setWorkshop] = useState("");
  const [notes, setNotes] = useState("");
  const [nextBy, setNextBy] = useState("none");
  const [nextDate, setNextDate] = useState("");
  const [nextKm, setNextKm] = useState(0);
  const [post, setPost] = useState(true);
  useEffect(() => {
    if (!open) return;
    setKind(record?.kind ?? "service");
    setTitle(record?.title ?? "");
    setDay(toDateInput(record?.date ?? new Date()));
    setOdometer(record?.odometer ?? 0);
    setCost(record?.cost ?? null);
    setWorkshop(record?.workshop ?? "");
    setNotes(record?.notes ?? "");
    setNextBy(record?.next_due_date ? "date" : (record?.next_due_odometer ?? 0) > 0 ? "km" : "none");
    setNextDate(toDateInput(record?.next_due_date ?? new Date(Date.now() + 365 * 86_400_000)));
    setNextKm(record?.next_due_odometer ?? 0);
    setPost(record ? record.transaction_id !== "" : true);
  }, [open, record]);
  const save = async () => {
    const id = record?.id ?? newID();
    const dateISO = fromDateInput(day) ?? now();
    const externalID = record?.transaction_id || `car-maintenance-${id}`;
    const label = title.trim() || maintenanceKinds[kind];
    const linked = post && (cost ?? 0) > 0
      ? await upsertLinkedExpense({ externalID, title: `${label} · ${vehicle.name.trim() || "Carro"}`, amount: cost ?? 0, currency: "EUR", date: dateISO, categoryName: "Carro", notes: workshop }, ctx)
      : (record?.transaction_id && (await removeLinked(record.transaction_id, ctx)), null);
    const row = {
      kind, title, date: dateISO, odometer, cost: cost ?? 0, workshop, notes, vehicle_id: vehicle.id, transaction_id: linked ? externalID : "",
      next_due_date: nextBy === "date" ? fromDateInput(nextDate) : null, next_due_odometer: nextBy === "km" ? nextKm : 0,
    };
    if (record) await mutate.update("maintenance_records", record.id, row);
    else await mutate.insert("maintenance_records", { id, created_at: now(), currency_code: "EUR", ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={record ? "Editar manutenção" : "Nova manutenção"} onSubmit={save}
      onDelete={record ? async () => { if (record.transaction_id) await removeLinked(record.transaction_id, ctx); await mutate.remove("maintenance_records", [record.id]); } : undefined} deleteWhat="esta manutenção">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Tipo">{(id) => <Select id={id} value={kind} onChange={setKind}>{Object.entries(maintenanceKinds).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
        <Field label="Descrição (opcional)">{(id) => <Input id={id} value={title} onChange={(e) => setTitle(e.target.value)} />}</Field>
      </div>
      <div className="grid grid-cols-3 gap-3">
        <Field label="Data">{(id) => <Input id={id} type="date" value={day} onChange={(e) => setDay(e.target.value)} />}</Field>
        <Field label="Km">{(id) => <Input id={id} type="number" value={odometer || ""} onChange={(e) => setOdometer(Number(e.target.value))} />}</Field>
        <Field label="Custo">{(id) => <MoneyInput id={id} value={cost} onChange={setCost} />}</Field>
      </div>
      <Field label="Oficina (opcional)">{(id) => <Input id={id} value={workshop} onChange={(e) => setWorkshop(e.target.value)} />}</Field>
      <Field label="Próxima" hint="A próxima manutenção aparece no Hoje quando estiver perto.">
        {(id) => (
          <div className="flex gap-2">
            <Select id={id} value={nextBy} onChange={setNextBy} className="w-40"><option value="none">Sem próxima</option><option value="date">Por data</option><option value="km">Por km</option></Select>
            {nextBy === "date" && <Input type="date" aria-label="Data da próxima" value={nextDate} onChange={(e) => setNextDate(e.target.value)} />}
            {nextBy === "km" && <Input type="number" aria-label="Km da próxima" value={nextKm || ""} onChange={(e) => setNextKm(Number(e.target.value))} />}
          </div>
        )}
      </Field>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} />}</Field>
      <div className="flex items-center gap-2"><Switch id="post-mnt" checked={post} onCheckedChange={setPost} /><Label htmlFor="post-mnt">Lançar nas Finanças (Carro)</Label></div>
    </FormDialog>
  );
}

function DeadlineForm({ vehicle, deadline, open, onOpenChange }: { vehicle: VehicleRow; deadline: CarDeadlineRow | null; open: boolean; onOpenChange: (o: boolean) => void }) {
  const [kind, setKind] = useState("inspection");
  const [title, setTitle] = useState("");
  const [day, setDay] = useState(toDateInput(new Date()));
  const [amount, setAmount] = useState<number | null>(0);
  const [renewal, setRenewal] = useState("12");
  const [notes, setNotes] = useState("");
  useEffect(() => {
    if (!open) return;
    setKind(deadline?.kind ?? "inspection");
    setTitle(deadline?.title ?? "");
    setDay(toDateInput(deadline?.due_date ?? new Date()));
    setAmount(deadline?.amount ?? 0);
    setRenewal(String(deadline?.renewal_months ?? 12));
    setNotes(deadline?.notes ?? "");
  }, [open, deadline]);
  const save = async () => {
    const row = { kind, title, due_date: fromDateInput(day, 9) ?? now(), amount: amount ?? 0, renewal_months: Number(renewal), notes, vehicle_id: vehicle.id };
    if (deadline) await mutate.update("car_deadlines", deadline.id, row);
    else await mutate.insert("car_deadlines", { id: newID(), created_at: now(), currency_code: "EUR", ...row });
  };
  return (
    <FormDialog open={open} onOpenChange={onOpenChange} title={deadline ? "Editar prazo" : "Novo prazo"} onSubmit={save}
      onDelete={deadline ? () => mutate.remove("car_deadlines", [deadline.id]) : undefined} deleteWhat="este prazo">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Tipo">{(id) => <Select id={id} value={kind} onChange={setKind}>{Object.entries(deadlineKinds).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</Select>}</Field>
        <Field label="Nome">{(id) => <Input id={id} value={title} onChange={(e) => setTitle(e.target.value)} placeholder={deadlineKinds[kind]} />}</Field>
      </div>
      <div className="grid grid-cols-3 gap-3">
        <Field label="Vence a">{(id) => <Input id={id} type="date" value={day} onChange={(e) => setDay(e.target.value)} />}</Field>
        <Field label="Valor">{(id) => <MoneyInput id={id} value={amount} onChange={setAmount} />}</Field>
        <Field label="Repete">{(id) => <Select id={id} value={renewal} onChange={setRenewal}><option value="0">Não se repete</option><option value="1">Todos os meses</option><option value="6">De 6 em 6 meses</option><option value="12">Todos os anos</option><option value="24">De 2 em 2 anos</option></Select>}</Field>
      </div>
      <Field label="Notas">{(id) => <Textarea id={id} rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Apólice, centro de inspeção…" />}</Field>
    </FormDialog>
  );
}

/** "Feito" (CarExpenseService.complete): lança o valor e passa ao próximo vencimento. */
async function completeDeadline(d: CarDeadlineRow, vehicle: VehicleRow, ctx: Ctx) {
  const today = new Date();
  const dayKey = toDateInput(today);
  const label = d.title.trim() || deadlineKinds[d.kind];
  await upsertLinkedExpense({ externalID: `car-deadline-${d.id}-${dayKey}`, title: `${label} · ${vehicle.name.trim() || "Carro"}`, amount: d.amount, currency: d.currency_code, date: today.toISOString(), categoryName: "Carro" }, ctx);
  let next: Date | null = null;
  if (d.renewal_months > 0) {
    if (d.kind === "inspection") {
      next = new Date(today);
      next.setMonth(next.getMonth() + d.renewal_months);
    } else {
      next = new Date(d.due_date);
      const start = new Date(today);
      start.setHours(0, 0, 0, 0);
      do next.setMonth(next.getMonth() + d.renewal_months);
      while (next <= start);
    }
  }
  await mutate.update("car_deadlines", d.id, { last_done_at: today.toISOString(), ...(next ? { due_date: next.toISOString() } : {}) });
  toast.success(`${label} feito`, { description: next ? `Próximo: ${date(next)}` : undefined });
}

const provinces: [string, string][] = [["01", "Álava"], ["02", "Albacete"], ["03", "Alicante"], ["04", "Almería"], ["33", "Asturias"], ["05", "Ávila"], ["06", "Badajoz"], ["07", "Baleares"], ["08", "Barcelona"], ["09", "Burgos"], ["10", "Cáceres"], ["11", "Cádiz"], ["39", "Cantabria"], ["12", "Castellón"], ["51", "Ceuta"], ["13", "Ciudad Real"], ["14", "Córdoba"], ["15", "A Coruña"], ["16", "Cuenca"], ["17", "Girona"], ["18", "Granada"], ["19", "Guadalajara"], ["20", "Gipuzkoa"], ["21", "Huelva"], ["22", "Huesca"], ["23", "Jaén"], ["24", "León"], ["25", "Lleida"], ["27", "Lugo"], ["28", "Madrid"], ["29", "Málaga"], ["52", "Melilla"], ["30", "Murcia"], ["31", "Navarra"], ["32", "Ourense"], ["34", "Palencia"], ["35", "Las Palmas"], ["36", "Pontevedra"], ["26", "La Rioja"], ["37", "Salamanca"], ["38", "Santa Cruz de Tenerife"], ["40", "Segovia"], ["41", "Sevilla"], ["42", "Soria"], ["43", "Tarragona"], ["44", "Teruel"], ["45", "Toledo"], ["46", "Valencia"], ["47", "Valladolid"], ["48", "Bizkaia"], ["49", "Zamora"], ["50", "Zaragoza"]];

interface Station { id: string; brand: string; address: string; town: string; latitude: number; longitude: number; prices: Record<string, number> }

function distanceKm(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  const r = Math.PI / 180;
  const h = Math.sin(((b.latitude - a.latitude) * r) / 2) ** 2 + Math.cos(a.latitude * r) * Math.cos(b.latitude * r) * Math.sin(((b.longitude - a.longitude) * r) / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

function FuelPrices({ fuelType }: { fuelType: string }) {
  const { status } = useSession();
  const { settings, set } = useSettings();
  const [stations, setStations] = useState<Station[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [origin, setOrigin] = useState<{ latitude: number; longitude: number } | null>(null);
  useEffect(() => {
    if (status !== "cloud" || fuelType === "electric") return;
    setStations(null);
    getDb().invoke<{ stations: Station[] }>("mynik-api", { action: "fuel", province: settings.fuelProvinceID })
      .then((r) => setStations(r.stations)).catch((e) => setError(String(e)));
  }, [status, settings.fuelProvinceID, fuelType]);
  const ranked = useMemo(() => {
    const entries = (stations ?? []).filter((s) => s.prices[fuelType]).map((s) => ({ s, price: s.prices[fuelType], distance: origin ? distanceKm(origin, s) : null }));
    const nearby = entries.filter((e) => (e.distance ?? 0) <= 10);
    return (nearby.length ? nearby : entries).sort((a, b) => a.price - b.price || (a.distance ?? 0) - (b.distance ?? 0));
  }, [stations, fuelType, origin]);
  const average = ranked.length ? ranked.reduce((s, e) => s + e.price, 0) / ranked.length : null;
  return (
    <Card title={`Preços de ${fuelTypes[fuelType]?.title ?? "combustível"}`} action={
      <Select aria-label="Província" value={settings.fuelProvinceID} onChange={(v) => void set("fuelProvinceID", v)} className="h-8 w-44">
        {provinces.map(([id, name]) => <option key={id} value={id}>{name}</option>)}
      </Select>
    }>
      {status !== "cloud" ? <p className="m-0 text-sm text-muted-foreground">Os preços do Ministerio (Espanha) carregam com a conta.</p>
        : fuelType === "electric" ? <p className="m-0 text-sm text-muted-foreground">Sem preços para carros elétricos.</p>
        : error ? <p className="m-0 text-sm text-warning">{error}</p>
        : !stations ? <p className="m-0 text-sm text-muted-foreground">A carregar preços…</p> : (
          <>
            <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
              <span className="text-muted-foreground">Média na província: {average != null ? `${number(average, 3)} €` : "—"}</span>
              <Button variant="outline" size="sm" onClick={() => navigator.geolocation.getCurrentPosition(
                (p) => setOrigin({ latitude: p.coords.latitude, longitude: p.coords.longitude }),
                () => toast.error("Sem acesso à localização"),
              )}><MapPin aria-hidden="true" /> {origin ? "Perto de mim (10 km)" : "Ordenar por perto de mim"}</Button>
            </div>
            {ranked.slice(0, 8).map(({ s, price, distance }) => (
              <a key={s.id} href={`https://www.openstreetmap.org/?mlat=${s.latitude}&mlon=${s.longitude}#map=17/${s.latitude}/${s.longitude}`} target="_blank" rel="noreferrer" className="flex items-center justify-between gap-3 text-[13px] text-foreground no-underline">
                <span className="flex min-w-0 flex-col"><span className="truncate font-medium">{s.brand}</span><span className="truncate text-xs text-muted-foreground">{s.address}, {s.town}{distance != null && ` · ${number(distance, 1)} km`}</span></span>
                <span className="tabular font-semibold">{number(price, 3)} €</span>
              </a>
            ))}
          </>
        )}
    </Card>
  );
}

function Car() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const { data } = useTables("vehicles", "fuel_entries", "maintenance_records", "car_deadlines", "transactions", "categories", "accounts");
  const ctx: Ctx = { transactions: data.transactions, categories: data.categories, accounts: data.accounts };
  const vehicles = [...data.vehicles].sort((a, b) => a.created_at.localeCompare(b.created_at));
  const vehicle = vehicles.find((v) => v.id === params.get("veiculo")) ?? vehicles[0] ?? null;
  const [vehicleForm, setVehicleForm] = useState<{ open: boolean; v: VehicleRow | null }>({ open: false, v: null });
  const [fuelForm, setFuelForm] = useState<{ open: boolean; e: FuelEntryRow | null }>({ open: false, e: null });
  const [mntForm, setMntForm] = useState<{ open: boolean; r: MaintenanceRow | null }>({ open: false, r: null });
  const [dlForm, setDlForm] = useState<{ open: boolean; d: CarDeadlineRow | null }>({ open: false, d: null });

  useEffect(() => {
    if (params.get("novo")) {
      if (vehicle) setFuelForm({ open: true, e: null });
      else setVehicleForm({ open: true, v: null });
      router.replace(pathname);
    }
  }, [params, router, pathname, vehicle]);

  const fuel = vehicle ? data.fuel_entries.filter((f) => f.vehicle_id === vehicle.id).sort((a, b) => b.date.localeCompare(a.date) || b.odometer - a.odometer) : [];
  const maintenance = vehicle ? data.maintenance_records.filter((m) => m.vehicle_id === vehicle.id).sort((a, b) => b.date.localeCompare(a.date)) : [];
  const deadlines = vehicle ? data.car_deadlines.filter((d) => d.vehicle_id === vehicle.id).sort((a, b) => a.due_date.localeCompare(b.due_date)) : [];
  const economy = fuelEconomy(fuel);
  const unit = fuelTypes[vehicle?.fuel_type ?? "gasoline95"]?.unit ?? "L";

  if (!vehicle) {
    return (
      <div className="flex flex-col gap-6">
        <PageHeader title="Carro" />
        <Card><Empty title="Sem carro"><Button onClick={() => setVehicleForm({ open: true, v: null })}>Adicionar carro</Button></Empty></Card>
        <VehicleForm vehicle={null} open={vehicleForm.open} onOpenChange={(o) => setVehicleForm((s) => ({ ...s, open: o }))} onSaved={(id) => router.replace(`${pathname}?veiculo=${id}`)} />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={vehicle.name || "Carro"}
        subtitle={[vehicle.plate, fuelTypes[vehicle.fuel_type]?.title].filter(Boolean).join(" · ")}
        actions={
          <>
            {vehicles.length > 1 && (
              <Select aria-label="Veículo" value={vehicle.id} onChange={(id) => router.replace(`${pathname}?veiculo=${id}`)} className="w-40">
                {vehicles.map((v) => <option key={v.id} value={v.id}>{v.name || "Carro"}</option>)}
              </Select>
            )}
            <Button variant="ghost" size="icon" aria-label="Editar veículo" onClick={() => setVehicleForm({ open: true, v: vehicle })}><Pencil aria-hidden="true" /></Button>
            <Button variant="outline" onClick={() => setVehicleForm({ open: true, v: null })}>Outro veículo</Button>
            <Button variant="outline" onClick={() => setMntForm({ open: true, r: null })}><Wrench aria-hidden="true" /> Manutenção</Button>
            <Button onClick={() => setFuelForm({ open: true, e: null })}><Fuel aria-hidden="true" /> Abastecimento</Button>
          </>
        }
      />
      <section className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <Kpi label={`Consumo médio (${unit}/100 km)`} value={economy.average != null ? number(economy.average, 1) : "—"} note={economy.last != null ? `Último: ${number(economy.last, 1)} ${unit}` : "São precisos dois atestos"} />
        <Kpi label="Custo por km" value={economy.costPerKm != null ? money(economy.costPerKm) : "—"} />
        <Kpi label="Km atuais" value={km(currentOdometer(vehicle, data.fuel_entries, data.maintenance_records))} />
        <Kpi label="Combustível (12 meses)" value={money(fuel.filter((f) => Date.now() - Date.parse(f.date) < 365 * 86_400_000).reduce((s, f) => s + f.total_cost, 0))} />
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card title="Prazos" action={<Button size="sm" variant="outline" onClick={() => setDlForm({ open: true, d: null })}><Plus aria-hidden="true" /> ITV, seguro ou imposto</Button>}>
          {deadlines.length === 0 ? <Empty title="Sem prazos" /> : deadlines.map((d) => (
            <div key={d.id} className="flex items-center gap-3">
              <button type="button" onClick={() => setDlForm({ open: true, d })} className="flex min-w-0 flex-1 flex-col text-left">
                <span className="font-medium">{d.title.trim() || deadlineKinds[d.kind]}</span>
                <span className="text-xs text-muted-foreground">{due(d.due_date)}{d.amount > 0 && ` · ${money(d.amount, d.currency_code)}`}{d.last_done_at && ` · feito a ${date(d.last_done_at, "short")}`}</span>
              </button>
              <Button size="sm" variant="outline" onClick={() => void completeDeadline(d, vehicle, ctx)}><Check aria-hidden="true" /> Feito</Button>
            </div>
          ))}
        </Card>
        <Card title={`Consumo por abastecimento (${unit}/100 km)`}>
          {economy.segments.length === 0 ? <Empty title="Regista dois atestos para ver o consumo" /> : (
            <div className="h-48" role="img" aria-label="Consumo por abastecimento">
              <ResponsiveContainer>
                <BarChart data={economy.segments.map((s) => ({ label: date(s.endDate, "short"), value: Math.round(s.per100km * 10) / 10 }))}>
                  <XAxis dataKey="label" stroke="var(--muted-foreground)" tickLine={false} axisLine={false} />
                  <YAxis stroke="var(--muted-foreground)" tickLine={false} axisLine={false} width={40} />
                  <Tooltip contentStyle={{ background: "var(--card)", border: "1px solid var(--border)", borderRadius: 10 }} />
                  <RBar dataKey="value" fill="var(--primary)" radius={[6, 6, 2, 2]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card title="Abastecimentos">
          {fuel.length === 0 ? <Empty title="Sem abastecimentos" /> : fuel.map((f) => (
            <button key={f.id} type="button" onClick={() => setFuelForm({ open: true, e: f })} className="flex items-center justify-between gap-3 text-left text-[13px]">
              <span className="flex flex-col"><span className="font-medium">{date(f.date)} · {km(f.odometer)}</span><span className="text-xs text-muted-foreground">{number(f.quantity, 2)} {unit} · {f.quantity > 0 ? `${number(f.total_cost / f.quantity, 3)} €/${unit}` : ""}{f.is_full_tank ? " · atestado" : ""}{f.station && ` · ${f.station}`}</span></span>
              <span className="tabular font-semibold">{money(f.total_cost, f.currency_code)}</span>
            </button>
          ))}
        </Card>
        <Card title="Manutenções">
          {maintenance.length === 0 ? <Empty title="Sem manutenções" /> : maintenance.map((m) => (
            <button key={m.id} type="button" onClick={() => setMntForm({ open: true, r: m })} className="flex items-center justify-between gap-3 text-left text-[13px]">
              <span className="flex flex-col"><span className="font-medium">{m.title.trim() || maintenanceKinds[m.kind]}</span><span className="text-xs text-muted-foreground">{date(m.date)}{m.odometer > 0 && ` · ${km(m.odometer)}`}{m.workshop && ` · ${m.workshop}`}{m.next_due_date ? ` · próxima ${date(m.next_due_date, "short")}` : m.next_due_odometer > 0 ? ` · próxima aos ${km(m.next_due_odometer)}` : ""}</span></span>
              <span className="tabular font-semibold">{m.cost > 0 ? money(m.cost, m.currency_code) : "—"}</span>
            </button>
          ))}
        </Card>
      </div>

      <FuelPrices fuelType={vehicle.fuel_type} />

      <VehicleForm vehicle={vehicleForm.v} open={vehicleForm.open} onOpenChange={(o) => setVehicleForm((s) => ({ ...s, open: o }))} onSaved={(id) => router.replace(`${pathname}?veiculo=${id}`)} />
      <FuelForm vehicle={vehicle} entry={fuelForm.e} open={fuelForm.open} onOpenChange={(o) => setFuelForm((s) => ({ ...s, open: o }))} ctx={ctx} />
      <MaintenanceForm vehicle={vehicle} record={mntForm.r} open={mntForm.open} onOpenChange={(o) => setMntForm((s) => ({ ...s, open: o }))} ctx={ctx} />
      <DeadlineForm vehicle={vehicle} deadline={dlForm.d} open={dlForm.open} onOpenChange={(o) => setDlForm((s) => ({ ...s, open: o }))} />
    </div>
  );
}

export default function CarPage() {
  return (
    <Suspense>
      <Car />
    </Suspense>
  );
}
