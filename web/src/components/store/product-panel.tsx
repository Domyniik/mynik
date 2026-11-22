"use client";

import { RotateCcw } from "lucide-react";
import { useEffect, useState } from "react";
import { Field, FormDialog, MoneyInput } from "@/components/common/fields";
import { Bar } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import {
  type Decision, decisionMeta, factorNames, phase, phaseTitle, type ProductScore, reviewWarning, suggestedDecision,
} from "@/lib/calc/store";
import { now } from "@/lib/db/client";
import type { StoreProductRow } from "@/lib/db/schema";
import { mutate } from "@/lib/db/store";
import { date, money, number, percent } from "@/lib/format";
import { cn } from "@/lib/utils";
import { ClassBadge } from "./class-badge";

const factorDetail = (p: ProductScore, kind: string) => {
  switch (kind) {
    case "sales": return `${p.units} un. em 30 dias`;
    case "revenue": return money(p.revenue);
    case "margin": return p.unit_cost > 0 && p.margin_rate != null ? percent(p.margin_rate) : "Sem custo definido";
    case "funnel": return p.checkout_conversion != null ? `${percent(p.checkout_conversion)} dos checkouts compram` : "Poucos dados";
    case "refunds": return percent(p.refund_rate);
    case "recency": return p.days_since_last_sale == null ? "Sem vendas" : p.days_since_last_sale === 0 ? "Vendeu hoje" : `Há ${p.days_since_last_sale} dias`;
    case "roas": return p.roas != null ? `${number(p.roas, 1)}×` : "Sem anúncios";
    default: return "";
  }
};

function DecisionDialog({ product, score, open, onOpenChange }: { product: StoreProductRow; score: ProductScore; open: boolean; onOpenChange: (o: boolean) => void }) {
  const suggested = suggestedDecision(score.classification);
  const [decision, setDecision] = useState<Decision | "">("");
  const [note, setNote] = useState("");
  useEffect(() => {
    if (!open) return;
    setDecision((product.decision as Decision) || suggested || "");
    setNote(product.decision_note);
  }, [open, product, suggested]);
  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={`Decisão · ${product.title}`}
      description={suggested ? `O ranking sugere: ${decisionMeta[suggested].title}.` : "Ainda em teste: o ranking não sugere uma decisão."}
      valid={decision !== ""}
      onSubmit={() => mutate.update("store_products", product.id, { decision, decided_at: now(), decision_note: note })}
    >
      <div role="radiogroup" aria-label="Decisão" className="grid grid-cols-3 gap-2">
        {(Object.keys(decisionMeta) as Decision[]).map((d) => (
          <button
            key={d}
            type="button"
            role="radio"
            aria-checked={decision === d}
            onClick={() => setDecision(d)}
            className={cn("rounded-lg border px-3 py-2 text-sm font-medium", decision === d ? "border-primary bg-primary/15" : "border-input")}
          >
            {decisionMeta[d].title}
          </button>
        ))}
      </div>
      <Field label="Nota">{(id) => <Textarea id={id} rows={3} value={note} onChange={(e) => setNote(e.target.value)} placeholder="Porquê, próximos passos…" />}</Field>
    </FormDialog>
  );
}

function CostsDialog({ product, open, onOpenChange }: { product: StoreProductRow; open: boolean; onOpenChange: (o: boolean) => void }) {
  const [cost, setCost] = useState<number | null>(null);
  const [ads, setAds] = useState<number | null>(null);
  useEffect(() => {
    if (!open) return;
    setCost(product.unit_cost);
    setAds(product.ad_spend_30d);
  }, [open, product]);
  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={`Custos · ${product.title}`}
      description="O custo escrito aqui não é substituído pelo da Shopify."
      onSubmit={() =>
        mutate.update("store_products", product.id, {
          unit_cost: cost ?? 0,
          unit_cost_is_manual: (cost ?? 0) !== product.unit_cost || product.unit_cost_is_manual,
          ad_spend_30d: ads ?? 0,
        })
      }
    >
      <Field label="Custo por unidade">{(id) => <MoneyInput id={id} value={cost} onChange={setCost} autoFocus />}</Field>
      <Field label="Anúncios (30 dias)" hint="Com a folha do Google Ads ligada, é atualizado sozinho.">{(id) => <MoneyInput id={id} value={ads} onChange={setAds} />}</Field>
    </FormDialog>
  );
}

/** Painel de diagnóstico do mockup: funil do produto, onde quebra, ação e decisão. */
export function ProductPanel({ score, product }: { score: ProductScore; product: StoreProductRow }) {
  const [decisionOpen, setDecisionOpen] = useState(false);
  const [costsOpen, setCostsOpen] = useState(false);
  const p = phase(score.age_days, product.decision, score.classification);
  const warning = reviewWarning(product.decision, score.classification, product.status === "ACTIVE");
  const weakest = score.factors.filter((f) => f.hasData).sort((a, b) => a.points / a.max - b.points / b.max)[0];
  const reached = score.abandoned_units != null ? score.ordered_units + score.abandoned_units : null;

  return (
    <aside aria-label="Diagnóstico do produto" className="flex min-w-0 flex-col gap-4 rounded-[14px] border border-border bg-card p-[18px]">
      <div className="flex flex-col gap-1.5">
        <span className="text-xs text-muted-foreground">Diagnóstico</span>
        <h2 className="m-0 text-[17px] font-semibold">{score.title}</h2>
        <span className="flex flex-wrap items-center gap-2">
          <ClassBadge value={score.classification} />
          <span className="text-xs text-muted-foreground">Score {score.score} · {phaseTitle(p)}{p.kind === "testing" && ` (faltam ${p.daysLeft} dias)`}</span>
        </span>
      </div>

      <div className="flex flex-col gap-2.5">
        <span className="text-[13px] text-muted-foreground">Funil (30 dias)</span>
        {reached != null && reached > 0 ? (
          <>
            {[
              { label: "Chegaram ao checkout", value: 1, text: `${reached} un.` },
              { label: "Compraram", value: score.ordered_units / reached, text: `${percent(score.ordered_units / reached)} · ${score.ordered_units} un.` },
              { label: "Ficaram (sem reembolso)", value: score.units / reached, text: `${score.units} un.` },
            ].map((s, i) => (
              <div key={s.label} className="flex flex-col gap-1">
                <div className="flex justify-between text-[13px]"><span>{s.label}</span><span className="text-muted-foreground">{s.text}</span></div>
                <Bar value={Math.max(s.value, 0.015)} height={10} color={i === 0 ? "#4b4f59" : undefined} />
              </div>
            ))}
          </>
        ) : (
          <p className="m-0 text-[13px] text-muted-foreground">Sem checkouts abandonados para este produto: o funil por produto aparece quando houver.</p>
        )}
      </div>

      <div className="flex flex-col gap-2">
        <span className="text-[13px] text-muted-foreground">Fatores do score</span>
        {score.factors.map((f) => (
          <div key={f.kind} className="flex flex-col gap-1">
            <div className="flex justify-between gap-2 text-[13px]">
              <span>{factorNames[f.kind]}</span>
              <span className="truncate text-muted-foreground">{factorDetail(score, f.kind)} · {Math.round(f.points)}/{f.max}</span>
            </div>
            <Bar value={f.points / f.max} height={6} color={f.hasData ? undefined : "#4b4f59"} />
          </div>
        ))}
      </div>

      <div className="flex flex-col gap-1.5 rounded-[10px] bg-surface p-3.5">
        <span className="text-xs text-muted-foreground">Onde o funil quebra</span>
        <span className="font-semibold">{weakest ? `${factorNames[weakest.kind]} — ${factorDetail(score, weakest.kind)}` : "Nenhum ponto fraco"}</span>
        <span className="text-[13px] leading-relaxed text-[#c3c7ce]">{score.action}</span>
        {warning && <span className="text-[13px] text-warning">{warning}</span>}
      </div>

      <dl className="m-0 grid grid-cols-2 gap-2 text-[13px]">
        <dt className="text-muted-foreground">Preço</dt><dd className="m-0 text-right">{money(score.price)}</dd>
        <dt className="text-muted-foreground">Custo por unidade</dt><dd className="m-0 text-right">{score.unit_cost > 0 ? money(score.unit_cost) : "—"}</dd>
        <dt className="text-muted-foreground">Margem por unidade</dt><dd className="m-0 text-right">{money(score.price - score.unit_cost)}</dd>
        <dt className="text-muted-foreground">Devolvidas</dt><dd className="m-0 text-right">{score.refunded_units} un.</dd>
        <dt className="text-muted-foreground">Stock</dt><dd className="m-0 text-right">{score.tracks_inventory ? `${score.inventory} un.${score.days_of_stock != null ? ` · ${score.days_of_stock} dias` : ""}` : "Não conta"}</dd>
        <dt className="text-muted-foreground">Anúncios (30 dias)</dt><dd className="m-0 text-right">{money(score.ad_spend)}</dd>
        <dt className="text-muted-foreground">Na loja há</dt><dd className="m-0 text-right">{score.age_days} dias</dd>
        {product.decided_at && (<><dt className="text-muted-foreground">Decidido a</dt><dd className="m-0 text-right">{date(product.decided_at)}</dd></>)}
      </dl>

      <div className="flex flex-wrap gap-2">
        <Button className="flex-1" onClick={() => setDecisionOpen(true)}>Registar decisão</Button>
        <Button variant="outline" onClick={() => setCostsOpen(true)}>Custos</Button>
      </div>
      <div className="flex flex-wrap gap-2">
        {product.decision && (
          <Button variant="ghost" size="sm" onClick={() => void mutate.update("store_products", product.id, { decision: "", decided_at: null, decision_note: "" })}>
            <RotateCcw aria-hidden="true" /> Desfazer decisão
          </Button>
        )}
        {product.unit_cost_is_manual && (
          <Button variant="ghost" size="sm" onClick={() => void mutate.update("store_products", product.id, { unit_cost_is_manual: false })}>
            Voltar a usar o custo da Shopify
          </Button>
        )}
      </div>
      <DecisionDialog product={product} score={score} open={decisionOpen} onOpenChange={setDecisionOpen} />
      <CostsDialog product={product} open={costsOpen} onOpenChange={setCostsOpen} />
    </aside>
  );
}
