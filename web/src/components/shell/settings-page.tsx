"use client";

import { Download, RefreshCw, Upload } from "lucide-react";
import { type ReactNode, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { Field, MoneyInput } from "@/components/common/fields";
import { Card, PageHeader } from "@/components/shell/page-header";
import { ICAL_KEY, readICalURL } from "@/components/today/calendar-card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { backupFileName, exportBackup, importBackup } from "@/lib/backup";
import { getDb } from "@/lib/db/store";
import { date, money, number } from "@/lib/format";
import { appLockEnabled, hasPin, removePin, setAppLock, setPin } from "@/lib/lock";
import { useSession } from "@/lib/session";
import { type SettingKey, type Settings, useSettings } from "@/lib/settings";

function Toggle({ id, label, checked, onChange, hint }: { id: string; label: string; checked: boolean; onChange: (v: boolean) => void; hint?: ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-2"><Switch id={id} checked={checked} onCheckedChange={onChange} /><Label htmlFor={id}>{label}</Label></div>
      {hint && <p className="m-0 pl-11 text-xs text-muted-foreground">{hint}</p>}
    </div>
  );
}

function NumberSetting({ label, k, settings, set, suffix }: { label: string; k: SettingKey; settings: Settings; set: (k: SettingKey, v: never) => Promise<void>; suffix?: string }) {
  const [value, setValue] = useState<number | null>(settings[k] as number);
  useEffect(() => setValue(settings[k] as number), [settings, k]);
  return (
    <Field label={suffix ? `${label} (${suffix})` : label}>
      {(id) => (
        <div onBlur={() => value != null && value !== settings[k] && void set(k, value as never)}>
          <MoneyInput id={id} value={value} onChange={setValue} />
        </div>
      )}
    </Field>
  );
}

export default function SettingsPage() {
  const session = useSession();
  const { settings, set } = useSettings();
  const setAny = set as (k: SettingKey, v: never) => Promise<void>;
  const cloud = session.status === "cloud";
  const [shop, setShop] = useState<string | null>(null);
  const [ical, setICal] = useState("");
  const [sheet, setSheet] = useState(settings.googleAdsSheet);
  const [pin, setPinText] = useState("");
  const [lock, setLock] = useState(false);
  const [pinSet, setPinSet] = useState(false);
  const importRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setICal(readICalURL());
    setLock(appLockEnabled());
    setPinSet(hasPin());
  }, []);
  useEffect(() => setSheet(settings.googleAdsSheet), [settings.googleAdsSheet]);
  useEffect(() => {
    if (!cloud) return;
    getDb().invoke<{ configured: boolean; shop?: { name: string }; domain?: string }>("mynik-api", { action: "shopify-status" })
      .then((r) => setShop(r.configured ? `Ligada a ${r.shop?.name ?? r.domain}` : "Por ligar: faltam os segredos SHOPIFY_* na Edge Function"))
      .catch((e) => setShop(`Sem resposta da Edge Function (${e instanceof Error ? e.message : e})`));
  }, [cloud]);

  const updateRate = async () => {
    try {
      const r = await getDb().invoke<{ rate: number; date: string }>("mynik-api", { action: "rate", from: "EUR", to: "BRL" });
      await set("brlPerEUR", Math.round(r.rate * 10000) / 10000);
      await set("exchangeRateDate", r.date);
      toast.success(`1 EUR = ${number(r.rate, 4)} BRL`);
    } catch (e) {
      toast.error("Sem câmbio do BCE", { description: String(e) });
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Definições" subtitle="As definições da conta são as mesmas do iPhone" />
      <div className="grid gap-4 lg:grid-cols-2">
        <Card title="Conta">
          {session.status === "demo" ? (
            <>
              <p className="m-0 text-sm">Estás no modo de demonstração: os dados são de exemplo e ficam só neste browser.</p>
              <Button variant="outline" onClick={() => session.leaveDemo()}>Sair da demonstração</Button>
            </>
          ) : (
            <>
              <p className="m-0 text-sm">Sessão iniciada: <strong>{session.email}</strong>. Os dados sincronizam com o iPhone pelo Supabase.</p>
              <Button variant="outline" onClick={() => void session.signOut()}>Terminar sessão</Button>
            </>
          )}
        </Card>

        <Card title="Moedas">
          <NumberSetting label="1 EUR em BRL" k="brlPerEUR" settings={settings} set={setAny} />
          <p className="m-0 text-xs text-muted-foreground">1 BRL = {number(1 / (settings.brlPerEUR || 6), 4)} EUR{settings.exchangeRateDate && ` · taxa de ${settings.exchangeRateDate}`}</p>
          {cloud && <Button variant="outline" onClick={() => void updateRate()}><RefreshCw aria-hidden="true" /> Atualizar taxa do dia (BCE)</Button>}
        </Card>

        <Card title="Loja Shopify">
          <p className="m-0 text-sm">{cloud ? shop ?? "A verificar…" : "Na demonstração a loja usa dados de exemplo."}</p>
          <p className="m-0 text-xs text-muted-foreground">O token da Shopify fica só no servidor (segredos da Edge Function mynik-api), nunca no computador nem no git.</p>
          <div className="grid grid-cols-2 gap-3">
            <NumberSetting label="Taxa de pagamento" suffix="%" k="storeFeePercent" settings={settings} set={setAny} />
            <NumberSetting label="Taxa fixa por pedido" suffix="€" k="storeFeeFixed" settings={settings} set={setAny} />
            <NumberSetting label="Envio por pedido" suffix="€" k="storeShippingCost" settings={settings} set={setAny} />
            <NumberSetting label="Anúncios por mês" suffix="€" k="storeMonthlyAds" settings={settings} set={setAny} />
          </div>
          <Toggle id="profit" label="Lançar o lucro mensal nas Finanças" checked={settings.storeProfitToFinance} onChange={(v) => void set("storeProfitToFinance", v)} />
        </Card>

        <Card title="Alertas da loja">
          <Toggle id="sales" label="Avisar de cada venda" checked={settings.storeSaleNotifications} onChange={(v) => void set("storeSaleNotifications", v)} hint="A loja é verificada ao abrir e de 15 em 15 minutos com a app aberta." />
          <NumberSetting label="Alerta sem vendas" suffix="dias" k="storeNoSaleDays" settings={settings} set={setAny} />
        </Card>

        <Card title="Google Ads">
          <Field label="Folha do Google Sheets" hint="Partilhada como &quot;qualquer pessoa com o link pode ver&quot; (script em scripts/google-ads).">
            {(id) => <Input id={id} value={sheet} onChange={(e) => setSheet(e.target.value)} onBlur={() => sheet !== settings.googleAdsSheet && void set("googleAdsSheet", sheet.trim())} placeholder="https://docs.google.com/spreadsheets/d/…" />}
          </Field>
          <p className="m-0 text-sm">Gasto nos últimos 30 dias: <strong>{money(settings.googleAdsTotal30d)}</strong>{settings.googleAdsLastImport > 0 && ` · atualizado a ${date(new Date(settings.googleAdsLastImport * 1000))}`}</p>
          {cloud && sheet && (
            <Button variant="outline" onClick={async () => {
              try {
                const r = await getDb().invoke<{ total: number }>("mynik-api", { action: "google-ads", sheet });
                toast.success(`Google Ads: ${money(r.total)} em 30 dias`);
              } catch (e) {
                toast.error("Não foi possível ler a folha", { description: String(e) });
              }
            }}>Atualizar agora</Button>
          )}
        </Card>

        <Card title="Notificações">
          <Toggle id="bills" label="Lembrar contas a pagar" checked={settings.billRemindersEnabled} onChange={(v) => void set("billRemindersEnabled", v)} />
          <NumberSetting label="Avisar antes" suffix="dias" k="billReminderDaysBefore" settings={settings} set={setAny} />
          <Toggle id="agenda" label="Lembrar prazos (carro, documentos, follow-ups)" checked={settings.agendaRemindersEnabled} onChange={(v) => void set("agendaRemindersEnabled", v)} />
          <Toggle id="weekly" label="Revisão semanal ao domingo às 19h" checked={settings.weeklyReviewReminder} onChange={(v) => void set("weeklyReviewReminder", v)} />
          <p className="m-0 text-xs text-muted-foreground">Na app desktop chegam como notificações do sistema.</p>
        </Card>

        <Card title="Calendário">
          <Field label="Endereço iCal (só leitura)" hint="Google Calendar: Definições → Endereço secreto em formato iCal. iCloud: partilhar calendário → Calendário público. Fica só neste computador.">
            {(id) => <Input id={id} value={ical} onChange={(e) => setICal(e.target.value)} onBlur={() => { try { localStorage.setItem(ICAL_KEY, ical.trim()); } catch { /* sem armazenamento */ } }} placeholder="webcal://… ou https://….ics" />}
          </Field>
        </Card>

        <Card title="Inteligência">
          <Toggle id="ai" label="Sugerir categoria dos movimentos" checked={settings.autoCategorize} onChange={(v) => void set("autoCategorize", v)} hint="Pelo histórico e pelo nome do comerciante, como o iPhone sem Apple Intelligence." />
        </Card>

        <Card title="Privacidade">
          <p className="m-0 text-sm text-muted-foreground">O PIN protege os números e as fotos dos documentos e, se quiseres, a abertura do Mynik. Fica só neste computador.</p>
          <div className="flex gap-2">
            <Input type="password" inputMode="numeric" aria-label="Novo PIN" placeholder={pinSet ? "Novo PIN" : "Escolhe um PIN (mín. 4)"} value={pin} onChange={(e) => setPinText(e.target.value)} className="w-48" />
            <Button variant="outline" disabled={pin.length < 4} onClick={async () => { await setPin(pin); setPinText(""); setPinSet(true); toast.success("PIN guardado"); }}>Guardar PIN</Button>
            {pinSet && <Button variant="ghost" onClick={() => { removePin(); setPinSet(false); setLock(false); }}>Remover</Button>}
          </div>
          <Toggle id="lock" label="Pedir o PIN ao abrir o Mynik" checked={lock} onChange={(v) => { if (!pinSet) return toast.error("Define primeiro um PIN"); setAppLock(v); setLock(v); }} />
        </Card>

        <Card title="Cópia de segurança">
          <p className="m-0 text-sm text-muted-foreground">O mesmo ficheiro JSON do iPhone: exporta aqui e importa lá (ou ao contrário). Importar junta, não apaga.</p>
          <div className="flex flex-wrap gap-2">
            <Button variant="outline" onClick={async () => {
              const archive = await exportBackup(getDb());
              const a = document.createElement("a");
              a.href = URL.createObjectURL(new Blob([JSON.stringify(archive, null, 2)], { type: "application/json" }));
              a.download = backupFileName();
              a.click();
              URL.revokeObjectURL(a.href);
            }}><Download aria-hidden="true" /> Criar cópia de segurança</Button>
            <Button variant="outline" onClick={() => importRef.current?.click()}><Upload aria-hidden="true" /> Importar cópia…</Button>
            <input ref={importRef} type="file" accept="application/json,.json" className="hidden" onChange={async (e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              try {
                const count = await importBackup(getDb(), JSON.parse(await file.text()));
                toast.success(`Importados ${count} registos`);
              } catch (error) {
                toast.error("Não foi possível importar", { description: error instanceof Error ? error.message : String(error) });
              }
              e.target.value = "";
            }} />
          </div>
        </Card>
      </div>
    </div>
  );
}
