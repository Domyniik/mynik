import type { ReactNode } from "react";

/** Título da secção com subtítulo e ações à direita (como no mockup). */
export function PageHeader({ title, subtitle, actions }: { title: ReactNode; subtitle?: ReactNode; actions?: ReactNode }) {
  return (
    <header className="flex flex-wrap items-center justify-between gap-4">
      <div className="flex min-w-0 flex-col gap-1">
        <h1 className="m-0 text-[26px] font-bold tracking-tight">{title}</h1>
        {subtitle && <p className="m-0 text-muted-foreground">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2.5">{actions}</div>}
    </header>
  );
}

/** Cartão do mockup: fundo #16181C, borda subtil, raio 14. */
export function Card({ title, action, children, className = "" }: { title?: ReactNode; action?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <section className={`flex min-w-0 flex-col gap-3.5 rounded-[14px] border border-border bg-card p-[18px] ${className}`}>
      {(title || action) && (
        <div className="flex items-center justify-between gap-3">
          {title && <h2 className="m-0 text-[15px] font-semibold">{title}</h2>}
          {action}
        </div>
      )}
      {children}
    </section>
  );
}

/** Indicador do mockup: rótulo, valor grande e nota colorida. */
export function Kpi({ label, value, note, tone = "muted" }: { label: string; value: ReactNode; note?: ReactNode; tone?: "muted" | "positive" | "warning" | "danger" }) {
  const toneClass = { muted: "text-muted-foreground", positive: "text-positive", warning: "text-warning", danger: "text-danger" }[tone];
  return (
    <div className="flex min-w-0 flex-col gap-2 rounded-[14px] border border-border bg-card p-[18px]">
      <span className="text-[13px] text-muted-foreground">{label}</span>
      <span className="tabular text-[22px] leading-tight font-bold tracking-tight break-words xl:text-[28px]">{value}</span>
      {note && <span className={`text-xs ${toneClass}`}>{note}</span>}
    </div>
  );
}

/** Barra de progresso fina do mockup. */
export function Bar({ value, color, height = 8 }: { value: number; color?: string; height?: number }) {
  const pct = Math.max(0, Math.min(100, value * 100));
  return (
    <div className="w-full rounded-full bg-track" style={{ height }} role="presentation">
      <div className="rounded-full" style={{ height, width: `${pct}%`, background: color ?? "var(--primary)" }} />
    </div>
  );
}

export function Empty({ icon, title, children }: { icon?: ReactNode; title: string; children?: ReactNode }) {
  return (
    <div className="flex flex-col items-center gap-2 py-10 text-center text-muted-foreground">
      {icon}
      <p className="m-0 font-semibold text-foreground">{title}</p>
      {children && <div className="max-w-sm text-sm">{children}</div>}
    </div>
  );
}

export function Loading() {
  return <div className="py-10 text-center text-muted-foreground" role="status">A carregar…</div>;
}
