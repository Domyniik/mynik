"use client";

import { ArrowDown, ArrowUp } from "lucide-react";
import { type ReactNode, useMemo, useState } from "react";
import { cn } from "@/lib/utils";

export interface Column<T> {
  key: string;
  header: string;
  cell: (row: T) => ReactNode;
  /** Valor para ordenar (sem ele, a coluna não ordena). */
  sort?: (row: T) => string | number | null;
  align?: "left" | "right";
  className?: string;
}

/** Tabela com cabeçalhos clicáveis para ordenar (extra do desktop). */
export function SortableTable<T>({
  rows, columns, rowKey, initialSort, onRowClick, selectedKey, empty,
}: {
  rows: T[];
  columns: Column<T>[];
  rowKey: (row: T) => string;
  initialSort?: { key: string; dir: "asc" | "desc" };
  onRowClick?: (row: T) => void;
  selectedKey?: string | null;
  empty?: ReactNode;
}) {
  const [sort, setSort] = useState(initialSort ?? null);
  const sorted = useMemo(() => {
    const column = columns.find((c) => c.key === sort?.key);
    if (!column?.sort || !sort) return rows;
    const factor = sort.dir === "asc" ? 1 : -1;
    return [...rows].sort((a, b) => {
      const x = column.sort!(a);
      const y = column.sort!(b);
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return (typeof x === "number" && typeof y === "number" ? x - y : String(x).localeCompare(String(y), "pt")) * factor;
    });
  }, [rows, columns, sort]);

  if (rows.length === 0 && empty) return <>{empty}</>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-left">
        <thead>
          <tr className="border-b border-border text-xs text-muted-foreground">
            {columns.map((c) => {
              const active = sort?.key === c.key;
              return (
                <th
                  key={c.key}
                  scope="col"
                  aria-sort={active ? (sort!.dir === "asc" ? "ascending" : "descending") : undefined}
                  className={cn("px-2.5 py-2 font-normal", c.align === "right" && "text-right", c.className)}
                >
                  {c.sort ? (
                    <button
                      type="button"
                      className={cn("inline-flex items-center gap-1 hover:text-foreground", active && "text-foreground")}
                      onClick={() => setSort({ key: c.key, dir: active && sort!.dir === "desc" ? "asc" : "desc" })}
                    >
                      {c.header}
                      {active && (sort!.dir === "asc" ? <ArrowUp size={12} aria-hidden="true" /> : <ArrowDown size={12} aria-hidden="true" />)}
                    </button>
                  ) : (
                    c.header
                  )}
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {sorted.map((row) => {
            const key = rowKey(row);
            return (
              <tr
                key={key}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                onKeyDown={onRowClick ? (e) => (e.key === "Enter" || e.key === " ") && (e.preventDefault(), onRowClick(row)) : undefined}
                tabIndex={onRowClick ? 0 : undefined}
                aria-selected={selectedKey != null ? selectedKey === key : undefined}
                className={cn(
                  "border-b border-surface",
                  onRowClick && "cursor-pointer hover:bg-sidebar-active/60 focus-visible:bg-sidebar-active focus-visible:outline-none",
                  selectedKey === key && "bg-sidebar-active",
                )}
              >
                {columns.map((c) => (
                  <td key={c.key} className={cn("px-2.5 py-2.5", c.align === "right" && "text-right tabular", c.className)}>
                    {c.cell(row)}
                  </td>
                ))}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
