"use client";

import { Trash2 } from "lucide-react";
import { type FormEvent, type ReactNode, useEffect, useId, useState } from "react";
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter,
  AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { parseAmount } from "@/lib/format";
import { colorHex, colors, symbolIcon } from "@/lib/icons";
import { cn } from "@/lib/utils";

export function Field({ label, hint, children, className }: { label: string; hint?: ReactNode; children: (id: string) => ReactNode; className?: string }) {
  const id = useId();
  return (
    <div className={cn("flex flex-col gap-1.5", className)}>
      <Label htmlFor={id}>{label}</Label>
      {children(id)}
      {hint && <p className="m-0 text-xs text-muted-foreground">{hint}</p>}
    </div>
  );
}

const controlClass =
  "h-9 w-full rounded-md border border-input bg-input/30 px-3 text-sm text-foreground outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:opacity-50";

/** Seletor nativo com o estilo dos campos (rápido e acessível no teclado). */
export function Select({ id, value, onChange, children, className, ...rest }: { id?: string; value: string; onChange: (value: string) => void; children: ReactNode; className?: string; "aria-label"?: string }) {
  return (
    <select id={id} value={value} onChange={(e) => onChange(e.target.value)} className={cn(controlClass, "pr-8", className)} {...rest}>
      {children}
    </select>
  );
}

/** Valor em dinheiro: aceita "12,50" ou "12.50". */
export function MoneyInput({ id, value, onChange, placeholder = "0,00", autoFocus }: { id?: string; value: number | null; onChange: (value: number | null) => void; placeholder?: string; autoFocus?: boolean }) {
  const [text, setText] = useState(value == null ? "" : String(value).replace(".", ","));
  useEffect(() => {
    // Só reage a mudanças de fora (ex.: a fatura lida pelo OCR).
    setText((current) => (parseAmount(current) === value ? current : value == null ? "" : String(value).replace(".", ",")));
  }, [value]);
  return (
    <Input
      id={id}
      inputMode="decimal"
      autoFocus={autoFocus}
      className="tabular"
      value={text}
      placeholder={placeholder}
      onChange={(e) => {
        setText(e.target.value);
        onChange(parseAmount(e.target.value));
      }}
    />
  );
}

export function SymbolPicker({ symbols, value, onChange, color }: { symbols: string[]; value: string; onChange: (value: string) => void; color: string }) {
  return (
    <div role="radiogroup" aria-label="Ícone" className="flex flex-wrap gap-1.5">
      {symbols.map((name) => {
        const Icon = symbolIcon(name);
        const selected = name === value;
        return (
          <button
            key={name}
            type="button"
            role="radio"
            aria-checked={selected}
            aria-label={name}
            onClick={() => onChange(name)}
            className={cn("flex size-9 items-center justify-center rounded-lg border", selected ? "border-transparent" : "border-input")}
            style={selected ? { background: `${colorHex(color)}33`, color: colorHex(color) } : undefined}
          >
            <Icon size={18} aria-hidden="true" />
          </button>
        );
      })}
    </div>
  );
}

export function ColorPicker({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  return (
    <div role="radiogroup" aria-label="Cor" className="flex flex-wrap gap-2">
      {Object.entries(colors).map(([name, { hex, name: label }]) => (
        <button
          key={name}
          type="button"
          role="radio"
          aria-checked={value === name}
          aria-label={label}
          title={label}
          onClick={() => onChange(name)}
          className={cn("size-7 rounded-full ring-offset-2 ring-offset-card", value === name && "ring-2 ring-foreground")}
          style={{ background: hex }}
        />
      ))}
    </div>
  );
}

/** Controlo segmentado do mockup (período da loja, vistas…). */
export function Segmented<T extends string>({ options, value, onChange, label }: { options: { value: T; label: ReactNode }[]; value: T; onChange: (value: T) => void; label: string }) {
  return (
    <div role="group" aria-label={label} className="flex gap-1 rounded-[10px] border border-border bg-card p-1">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          aria-pressed={o.value === value}
          onClick={() => onChange(o.value)}
          className={cn(
            "min-h-8 rounded-[7px] px-3.5 text-[13px] font-medium",
            o.value === value ? "bg-input text-white" : "text-sidebar-foreground hover:text-foreground",
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Filtros em pílula do mockup (ranking da loja, estados…). */
export function Chips<T extends string>({ options, value, onChange, label }: { options: { value: T; label: ReactNode }[]; value: T; onChange: (value: T) => void; label: string }) {
  return (
    <div role="group" aria-label={label} className="flex flex-wrap gap-1.5">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          aria-pressed={o.value === value}
          onClick={() => onChange(o.value)}
          className={cn(
            "min-h-8 rounded-lg border px-3 text-[13px]",
            o.value === value ? "border-[#4b4f59] bg-track text-white" : "border-input text-sidebar-foreground hover:text-foreground",
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function ConfirmDelete({ what, onConfirm, children, description }: { what: string; onConfirm: () => void | Promise<void>; children?: ReactNode; description?: string }) {
  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        {children ?? (
          <Button type="button" variant="ghost" className="text-danger hover:text-danger">
            <Trash2 aria-hidden="true" /> Apagar
          </Button>
        )}
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Apagar {what}?</AlertDialogTitle>
          <AlertDialogDescription>{description ?? "Apaga também no iPhone. Não se pode desfazer."}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <AlertDialogAction onClick={() => void onConfirm()} className="bg-destructive text-white hover:bg-destructive/90">
            Apagar
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

/** Diálogo de formulário: Guardar com ⌘↩ ou Enter, Apagar à esquerda quando é para editar. */
export function FormDialog({
  open, onOpenChange, title, description, children, onSubmit, onDelete, deleteWhat, submitLabel = "Guardar", valid = true, wide,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  children: ReactNode;
  onSubmit: () => void | Promise<void>;
  onDelete?: () => void | Promise<void>;
  deleteWhat?: string;
  submitLabel?: string;
  valid?: boolean;
  wide?: boolean;
}) {
  const [busy, setBusy] = useState(false);
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!valid || busy) return;
    setBusy(true);
    try {
      await onSubmit();
      onOpenChange(false);
    } finally {
      setBusy(false);
    }
  };
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className={cn("max-h-[90dvh] overflow-y-auto", wide ? "sm:max-w-2xl" : "sm:max-w-lg")}>
        <form
          onSubmit={submit}
          onKeyDown={(e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === "Enter") void submit(e);
          }}
          className="flex flex-col gap-4"
        >
          <DialogHeader>
            <DialogTitle>{title}</DialogTitle>
            {description && <DialogDescription>{description}</DialogDescription>}
          </DialogHeader>
          {children}
          <DialogFooter className="gap-2 sm:justify-between">
            <div>
              {onDelete && (
                <ConfirmDelete
                  what={deleteWhat ?? "este item"}
                  onConfirm={async () => {
                    await onDelete();
                    onOpenChange(false);
                  }}
                />
              )}
            </div>
            <div className="flex gap-2">
              <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancelar</Button>
              <Button type="submit" disabled={!valid || busy}>{submitLabel}</Button>
            </div>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/** Abas por parâmetro do URL (`?tab=`), para os atalhos e o ⌘K poderem abrir uma aba. */
export function TabBar<T extends string>({ tabs, value, onChange }: { tabs: { value: T; label: string }[]; value: T; onChange: (value: T) => void }) {
  return (
    <div role="tablist" className="flex flex-wrap gap-1 border-b border-border">
      {tabs.map((t) => (
        <button
          key={t.value}
          role="tab"
          type="button"
          aria-selected={t.value === value}
          onClick={() => onChange(t.value)}
          className={cn(
            "-mb-px border-b-2 px-3 py-2 text-sm font-medium",
            t.value === value ? "border-primary text-foreground" : "border-transparent text-muted-foreground hover:text-foreground",
          )}
        >
          {t.label}
        </button>
      ))}
    </div>
  );
}
