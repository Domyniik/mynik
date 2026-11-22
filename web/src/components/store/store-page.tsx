"use client";

import { Copy, PackageCheck, RefreshCw, ShoppingCart, TriangleAlert } from "lucide-react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { Area, AreaChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { toast } from "sonner";
import { Chips, Segmented } from "@/components/common/fields";
import { type Column, SortableTable } from "@/components/common/sortable-table";
import { Bar, Card, Empty, Kpi, Loading, PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import {
  classMeta, diagnoseFunnel, ordersToShip, phase, phaseOrder, phaseTitle, type ProductClass, type ProductScore,
  problemMeta, recentCheckouts, stageStatus, storeAlerts, unitCount,
} from "@/lib/calc/store";
import { getDb, useRpc, useTable } from "@/lib/db/store";
import { change, date, money, percent, TIME_ZONE } from "@/lib/format";
import { notify } from "@/lib/notify";
import { useSession } from "@/lib/session";
import { useSettings } from "@/lib/settings";
import { cn } from "@/lib/utils";
import { ClassBadge } from "./class-badge";
import { ProductPanel } from "./product-panel";

interface Kpis {
  period: "current" | "previous";
  orders: number; units: number; gross_sales: number; vat: number; net_revenue: number; product_costs: number;
  shipping_costs: number; payment_fees: number; ad_spend: number; profit: number; margin: number | null;
  average_order_value: number | null; sessions: number; completed_sessions: number; has_traffic: boolean; conversion_rate: number | null;
}

const LAST_SYNC_KEY = "mynik.storeLastSync";
const MIN_INTERVAL = 15 * 60_000;

/** Sincroniza a loja pela Edge Function (a conta) e avisa das vendas novas. */
export function useStoreSync() {
  const { status } = useSession();
  const [state, setState] = useState<{ syncing: boolean; shopName: string | null; error: string | null; lastSync: number | null }>({
    syncing: false, shopName: null, error: null, lastSync: null,
  });
  const { settings } = useSettings();

  const sync = useCallback(async () => {
    if (status !== "cloud") return;
    setState((s) => ({ ...s, syncing: true, error: null }));
    try {
      const result = await getDb().invoke<{ shopName: string; newOrders: { name: string; total: number; items: string[] }[]; trafficError?: string }>("mynik-api", { action: "shopify-sync" });
      const at = Date.now();
      localStorage.setItem(LAST_SYNC_KEY, String(at));
      if (settings.storeSaleNotifications) {
        for (const o of result.newOrders.slice(-3)) notify(`Nova venda · ${money(o.total)}`, `${o.name}: ${o.items.join(", ")}`);
      }
      if (settings.googleAdsSheet) await getDb().invoke("mynik-api", { action: "google-ads", sheet: settings.googleAdsSheet }).catch(() => undefined);
      setState({ syncing: false, shopName: result.shopName, error: result.trafficError ?? null, lastSync: at });
    } catch (error) {
      setState((s) => ({ ...s, syncing: false, error: error instanceof Error ? error.message : String(error) }));
    }
  }, [status, settings.storeSaleNotifications, settings.googleAdsSheet]);

  useEffect(() => {
    const last = Number(localStorage.getItem(LAST_SYNC_KEY) ?? 0);
    setState((s) => ({ ...s, lastSync: last || null }));
    if (status === "cloud" && Date.now() - last > MIN_INTERVAL) void sync();
  }, [status, sync]);

  return { ...state, sync, demo: status === "demo" };
}

const periods = [{ value: "1", label: "Hoje" }, { value: "7", label: "7 dias" }, { value: "30", label: "30 dias" }] as const;
const comparison: Record<string, string> = { "1": "vs ontem", "7": "vs 7 dias antes", "30": "vs 30 dias antes" };

function Store() {
  const params = useSearchParams();
  const router = useRouter();
  const sync = useStoreSync();
  const { settings } = useSettings();
  const [days, setDays] = useState<"1" | "7" | "30">("30");
  const [filter, setFilter] = useState<"all" | ProductClass>("all");
  const [funnelDays, setFunnelDays] = useState<"7" | "30">("30");
  const [selected, setSelected] = useState<string | null>(params.get("produto"));
  const deps = ["store_orders", "store_products", "store_checkouts", "daily_stats", "user_settings"] as const;
  const { data: kpiRows } = useRpc<Kpis>("store_kpis", { p_days: Number(days), p_tz: TIME_ZONE }, [...deps]);
  const { data: scores, loading: scoresLoading } = useRpc<ProductScore>("store_product_scores", { p_tz: TIME_ZONE }, [...deps]);
  const { data: points } = useRpc<{ day: string; sales: number; profit: number }>("store_daily_points", { p_days: 30, p_tz: TIME_ZONE }, [...deps]);
  const { rows: products } = useTable("store_products");
  const { rows: orders } = useTable("store_orders");
  const { rows: checkouts } = useTable("store_checkouts");
  const { rows: stats } = useTable("daily_stats");

  useEffect(() => {
    const p = params.get("produto");
    if (p) setSelected(p);
  }, [params]);

  const current = kpiRows.find((k) => k.period === "current");
  const previous = kpiRows.find((k) => k.period === "previous");
  const productByID = useMemo(() => new Map(products.map((p) => [p.id, p])), [products]);
  const counts = useMemo(() => Object.fromEntries((Object.keys(classMeta) as ProductClass[]).map((c) => [c, scores.filter((s) => s.classification === c).length])), [scores]);
  const visible = scores.filter((s) => filter === "all" || s.classification === filter);
  const selectedScore = scores.find((s) => s.product_id === selected) ?? visible[0] ?? null;
  const funnel = useMemo(() => diagnoseFunnel(stats, Number(funnelDays)), [stats, funnelDays]);
  const toShip = useMemo(() => ordersToShip(orders), [orders]);
  const abandoned = useMemo(() => recentCheckouts(checkouts), [checkouts]);
  const alerts = useMemo(() => storeAlerts(orders, scores, settings.storeNoSaleDays), [orders, scores, settings.storeNoSaleDays]);
  const soldIDs = new Set(orders.flatMap((o) => (o.lines as { productID: string }[]).map((l) => l.productID)));
  const missingCost = products.filter((p) => p.unit_cost === 0 && soldIDs.has(p.id));
  const lifecycle = scores
    .map((s) => ({ s, p: phase(s.age_days, productByID.get(s.product_id)?.decision ?? "", s.classification) }))
    .sort((a, b) => phaseOrder(a.p) - phaseOrder(b.p) || b.s.score - a.s.score);

  const kpi = (label: string, value: string, now?: number | null, before?: number | null, note?: string) => {
    const delta = now != null && before != null && before !== 0 ? (now - before) / Math.abs(before) : null;
    return <Kpi label={label} value={value} note={note ?? (delta == null ? comparison[days] : `${change(delta)} ${comparison[days]}`)} tone={note ? "muted" : delta == null ? "muted" : delta >= 0 ? "positive" : "warning"} />;
  };

  const columns: Column<ProductScore>[] = [
    {
      key: "title", header: "Produto", sort: (s) => s.title,
      cell: (s) => {
        const image = productByID.get(s.product_id)?.image_url;
        return (
          <span className="flex min-w-0 items-center gap-2.5">
            {image ? <img src={image} alt="" className="size-8 flex-none rounded-lg object-cover" /> : <span className="size-8 flex-none rounded-lg bg-track" />}
            <span className="truncate">{s.title}</span>
          </span>
        );
      },
    },
    {
      key: "score", header: "Score", sort: (s) => s.score,
      cell: (s) => (
        <span className="flex items-center gap-2">
          <span className="w-6 font-semibold tabular">{s.score}</span>
          <span className="min-w-16 flex-1"><Bar value={s.score / 100} height={6} color={classMeta[s.classification].fg} /></span>
        </span>
      ),
    },
    { key: "class", header: "Estado", sort: (s) => s.classification, cell: (s) => <ClassBadge value={s.classification} /> },
    { key: "units", header: "Vendas", align: "right", sort: (s) => s.units, cell: (s) => s.units },
    { key: "revenue", header: "Receita", align: "right", sort: (s) => s.revenue, cell: (s) => money(s.revenue) },
    { key: "funnel", header: "Checkout→compra", align: "right", sort: (s) => s.checkout_conversion, cell: (s) => percent(s.checkout_conversion) },
    {
      key: "margin", header: "Margem", align: "right", sort: (s) => s.margin_rate,
      cell: (s) => <span className={s.unit_cost > 0 && (s.margin_rate ?? 0) < 0 ? "text-danger" : undefined}>{s.unit_cost > 0 ? percent(s.margin_rate) : "—"}</span>,
    },
  ];

  return (
    <div className="flex flex-col gap-[22px]">
      <PageHeader
        title={sync.shopName ?? "Neloce"}
        subtitle={
          <>
            Loja Shopify ·{" "}
            {sync.demo ? <span className="text-link">dados de exemplo</span> : sync.syncing ? "A atualizar…" : sync.lastSync ? `Atualizado às ${date(new Date(sync.lastSync), "time")}` : "Ainda não sincronizado"}
          </>
        }
        actions={
          <>
            <Segmented label="Período" value={days} onChange={setDays} options={[...periods]} />
            {!sync.demo && (
              <Button variant="outline" onClick={() => void sync.sync()} disabled={sync.syncing}>
                <RefreshCw aria-hidden="true" className={cn(sync.syncing && "animate-spin")} /> Atualizar
              </Button>
            )}
          </>
        }
      />
      {sync.error && <p className="m-0 rounded-lg bg-surface px-3 py-2 text-sm text-warning" role="alert">{sync.error}</p>}

      <section aria-label="Indicadores" className="grid grid-cols-2 gap-3.5 md:grid-cols-5">
        {kpi("Vendas", money(current?.gross_sales ?? 0), current?.gross_sales, previous?.gross_sales)}
        {kpi("Pedidos", String(current?.orders ?? 0), current?.orders, previous?.orders)}
        {kpi("Ticket médio", current?.average_order_value != null ? money(current.average_order_value) : "—", current?.average_order_value, previous?.average_order_value)}
        {kpi("Lucro real", money(current?.profit ?? 0), undefined, undefined, "após custo, frete, taxas e ads")}
        {kpi("Conversão", current?.conversion_rate != null ? percent(current.conversion_rate, 1) : "—", current?.conversion_rate, previous?.conversion_rate)}
      </section>

      <section className="flex flex-wrap items-start gap-4">
        <div className="flex min-w-0 flex-[999_1_640px] flex-col gap-3.5 rounded-[14px] border border-border bg-card p-[18px]">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h2 className="m-0 text-[15px] font-semibold">Ranking de produtos</h2>
            <Chips
              label="Filtrar por estado"
              value={filter}
              onChange={setFilter}
              options={[
                { value: "all", label: "Todos" },
                ...(Object.keys(classMeta) as ProductClass[]).map((c) => ({ value: c, label: `${classMeta[c].plural} ${counts[c] ?? 0}` })),
              ]}
            />
          </div>
          {scoresLoading ? <Loading /> : (
            <SortableTable
              rows={visible}
              columns={columns}
              rowKey={(s) => s.product_id}
              selectedKey={selectedScore?.product_id ?? null}
              onRowClick={(s) => {
                setSelected(s.product_id);
                router.replace(`/loja/?produto=${encodeURIComponent(s.product_id)}`);
              }}
              empty={<Empty title="Nenhum produto nesta classificação" />}
            />
          )}
          <p className="m-0 text-xs text-muted-foreground">Score de 0 a 100 nos últimos 30 dias: vendas, receita, margem, funil, reembolsos, recência e ROAS. Clica num produto para o diagnóstico.</p>
        </div>
        <div className="min-w-0 flex-[1_1_300px]">
          {selectedScore && productByID.get(selectedScore.product_id) ? (
            <ProductPanel score={selectedScore} product={productByID.get(selectedScore.product_id)!} />
          ) : (
            <Card title="Diagnóstico"><Empty title="Sem produtos ativos" /></Card>
          )}
        </div>
      </section>

      <section className="grid gap-4 lg:grid-cols-[1fr_2fr]">
        <Card title={`Lucro real · ${periods.find((p) => p.value === days)!.label}`}>
          {current && (
            <dl className="m-0 grid grid-cols-[1fr_auto] gap-y-2 text-[13px]">
              <dt>Vendas (com IVA)</dt><dd className="m-0 text-right tabular">{money(current.gross_sales)}</dd>
              {([["IVA", current.vat], ["Artigos", current.product_costs], ["Envio", current.shipping_costs], ["Taxas de pagamento", current.payment_fees], ["Anúncios", current.ad_spend]] as const).map(([l, v]) => (
                <div key={l} className="contents text-muted-foreground"><dt>− {l}</dt><dd className="m-0 text-right tabular">{money(v)}</dd></div>
              ))}
              <dt className="border-t border-border pt-2 font-semibold">Lucro real</dt>
              <dd className={cn("m-0 border-t border-border pt-2 text-right font-semibold tabular", current.profit >= 0 ? "text-positive" : "text-danger")}>{money(current.profit)}</dd>
              <dt className="text-muted-foreground">Margem</dt><dd className="m-0 text-right tabular text-muted-foreground">{percent(current.margin)}</dd>
            </dl>
          )}
          {missingCost.length > 0 && (
            <p className="m-0 flex gap-2 text-xs text-warning"><TriangleAlert size={14} className="flex-none" aria-hidden="true" />{missingCost.length} produto(s) vendidos sem custo: o lucro está sobrestimado ({missingCost.map((p) => p.title).join(", ")}).</p>
          )}
        </Card>
        <Card title="Vendas e lucro · 30 dias">
          <div className="h-56" role="img" aria-label="Vendas e lucro dos últimos 30 dias">
            <ResponsiveContainer>
              <AreaChart data={points.map((p) => ({ ...p, label: date(`${p.day}T12:00:00`, "short") }))}>
                <XAxis dataKey="label" stroke="var(--muted-foreground)" tickLine={false} axisLine={false} interval={6} />
                <YAxis stroke="var(--muted-foreground)" tickLine={false} axisLine={false} width={60} tickFormatter={(v) => money(Number(v), "EUR", { compact: true })} />
                <Tooltip formatter={(v, n) => [money(Number(v)), n === "sales" ? "Vendas" : "Lucro"]} contentStyle={{ background: "var(--card)", border: "1px solid var(--border)", borderRadius: 10 }} />
                <Area dataKey="sales" stroke="var(--primary)" fill="var(--primary)" fillOpacity={0.25} strokeWidth={2} />
                <Area dataKey="profit" stroke="var(--positive)" fill="var(--positive)" fillOpacity={0.12} strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </section>

      <section className="grid gap-4 lg:grid-cols-2">
        <Card title="Funil da loja" action={<Segmented label="Período do funil" value={funnelDays} onChange={setFunnelDays} options={[{ value: "7", label: "7 dias" }, { value: "30", label: "30 dias" }]} />}>
          {funnel.stages.map((s, i) => {
            const status = stageStatus(s);
            return (
              <div key={s.name} className="flex flex-col gap-1">
                <div className="flex justify-between text-[13px]">
                  <span>{s.name}</span>
                  <span className={cn("tabular", status === "weak" ? "text-alert" : status === "good" ? "text-positive" : "text-muted-foreground")}>
                    {s.count}{s.rate != null && ` · ${percent(s.rate, 1)}`}
                  </span>
                </div>
                <Bar value={funnel.stages[0].count ? s.count / funnel.stages[0].count : 0} height={10} color={i === 0 ? "#4b4f59" : undefined} />
              </div>
            );
          })}
          <div className="flex flex-col gap-1.5 rounded-[10px] bg-surface p-3.5">
            <span className="text-xs text-muted-foreground">Diagnóstico · {Math.round(funnel.sessionsPerDay)} visitas/dia · conversão {percent(funnel.conversionRate, 1)}</span>
            <span className="font-semibold">{problemMeta[funnel.problem].title}</span>
            <span className="text-[13px] text-[#c3c7ce]">{problemMeta[funnel.problem].explanation}</span>
            {problemMeta[funnel.problem].suggestions.length > 0 && (
              <ul className="m-0 pl-4 text-[13px] text-[#c3c7ce]">{problemMeta[funnel.problem].suggestions.map((x) => <li key={x}>{x}</li>)}</ul>
            )}
          </div>
        </Card>
        <Card title="Ciclo de vida">
          {lifecycle.length === 0 && <Empty title="Sem produtos ativos" />}
          {lifecycle.map(({ s, p }) => (
            <button key={s.product_id} type="button" onClick={() => setSelected(s.product_id)} className="flex items-center justify-between gap-3 text-left">
              <span className="flex min-w-0 items-center gap-2"><span aria-hidden="true">{classMeta[s.classification].emoji}</span><span className="truncate">{s.title}</span></span>
              <span className={cn("text-xs", p.kind === "awaiting" ? "text-warning" : "text-muted-foreground")}>
                {phaseTitle(p)}{p.kind === "awaiting" && p.suggested && ` · sugere ${({ scale: "escalar", keep: "manter", discontinue: "descontinuar" })[p.suggested]}`}
              </span>
            </button>
          ))}
        </Card>
      </section>

      <section className="grid gap-4 lg:grid-cols-3">
        <Card title={`Por enviar (${toShip.length})`}>
          {toShip.length === 0 ? <Empty icon={<PackageCheck aria-hidden="true" />} title="Tudo enviado" /> : toShip.map(({ order, daysWaiting, isLate }) => (
            <div key={order.id} className="flex items-center justify-between gap-3 text-[13px]">
              <span className="flex flex-col"><span className="font-medium">{order.name}</span><span className="text-xs text-muted-foreground">{unitCount(order)} un. · {money(order.total, order.currency_code)}</span></span>
              <span className={isLate ? "text-alert" : "text-muted-foreground"}>{daysWaiting === 0 ? "Hoje" : `Há ${daysWaiting} dias`}</span>
            </div>
          ))}
        </Card>
        <Card title="Carrinhos abandonados · 30 dias">
          <p className="m-0 text-[13px] text-muted-foreground">{abandoned.length} checkouts · {money(abandoned.reduce((s, c) => s + c.total, 0))} em carrinhos</p>
          {abandoned.length === 0 ? <Empty icon={<ShoppingCart aria-hidden="true" />} title="Sem carrinhos abandonados" /> : abandoned.slice(0, 8).map((c) => (
            <div key={c.id} className="flex items-center justify-between gap-2 text-[13px]">
              <span className="flex min-w-0 flex-col"><span className="truncate">{(c.lines as { title: string }[]).map((l) => l.title).filter(Boolean).join(", ") || c.name}</span><span className="text-xs text-muted-foreground">{date(c.created_at, "short")} · {money(c.total)}</span></span>
              {c.recovery_url && (
                <Button variant="ghost" size="icon" aria-label="Copiar link de recuperação" onClick={() => void navigator.clipboard.writeText(c.recovery_url).then(() => toast.success("Link copiado"))}>
                  <Copy aria-hidden="true" />
                </Button>
              )}
            </div>
          ))}
        </Card>
        <Card title="Alertas">
          {alerts.length === 0 ? <Empty title="Sem alertas" /> : alerts.map((a) => (
            <button key={a.id} type="button" onClick={() => a.productID && setSelected(a.productID)} className="flex gap-2 text-left text-[13px]">
              <TriangleAlert size={16} className={cn("mt-0.5 flex-none", a.critical ? "text-alert" : "text-warning")} aria-hidden="true" />
              <span className="flex flex-col"><span className="font-medium">{a.title}</span><span className="text-muted-foreground">{a.message}</span></span>
            </button>
          ))}
        </Card>
      </section>

      <Card title="Últimos pedidos">
        {orders.length === 0 ? <Empty title="Ainda não há pedidos" /> : (
          [...orders].sort((a, b) => b.created_at.localeCompare(a.created_at)).slice(0, 10).map((o) => (
            <div key={o.id} className="flex items-center justify-between gap-3 text-[13px]">
              <span className="flex min-w-0 flex-col">
                <span className={cn("font-medium", o.cancelled_at && "line-through opacity-60")}>{o.name} · {(o.lines as { title: string }[]).map((l) => l.title).join(", ")}</span>
                <span className="text-xs text-muted-foreground">{date(o.created_at, "short")} {date(o.created_at, "time")}{o.refunded > 0 && ` · reembolso ${money(o.refunded, o.currency_code)}`}</span>
              </span>
              <span className="tabular font-semibold">{money(o.total, o.currency_code)}</span>
            </div>
          ))
        )}
      </Card>
    </div>
  );
}

export default function StorePage() {
  return (
    <Suspense>
      <Store />
    </Suspense>
  );
}
