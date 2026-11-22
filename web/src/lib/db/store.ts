"use client";

import { useCallback, useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";
import { toast } from "sonner";
import type { Db, RowInput } from "./client";
import type { TableName, Tables } from "./schema";

interface Entry {
  rows: unknown[] | null;
  error: Error | null;
  loading: Promise<void> | null;
  listeners: Set<() => void>;
  stale: boolean;
}

let current: Db | null = null;
let unsubscribe: (() => void) | null = null;
const entries = new Map<TableName, Entry>();
const rpcListeners = new Set<(table: TableName) => void>();
let version = 0;
const versionListeners = new Set<() => void>();

function entry(table: TableName): Entry {
  let e = entries.get(table);
  if (!e) {
    e = { rows: null, error: null, loading: null, listeners: new Set(), stale: true };
    entries.set(table, e);
  }
  return e;
}

function notify(e: Entry) {
  for (const l of e.listeners) l();
}

async function load(table: TableName) {
  const e = entry(table);
  if (!current) return;
  if (e.loading) return e.loading;
  const db = current;
  e.stale = false;
  e.loading = (async () => {
    try {
      const rows = await db.list(table);
      if (db !== current) return;
      e.rows = rows;
      e.error = null;
    } catch (error) {
      e.error = error as Error;
    } finally {
      e.loading = null;
      notify(e);
      if (e.stale) void load(table);
    }
  })();
  return e.loading;
}

const timers = new Map<TableName, ReturnType<typeof setTimeout>>();
function changed(table: TableName) {
  const e = entry(table);
  e.stale = true;
  clearTimeout(timers.get(table));
  timers.set(
    table,
    setTimeout(() => {
      if (e.listeners.size > 0) void load(table);
      for (const l of rpcListeners) l(table);
    }, 150),
  );
}

/** Troca a fonte de dados (conta ↔ demo): limpa a cache. */
export function setDb(db: Db | null) {
  unsubscribe?.();
  current = db;
  for (const e of entries.values()) {
    e.rows = null;
    e.error = null;
    e.stale = true;
    notify(e);
  }
  unsubscribe = db ? db.subscribe(changed) : null;
  // Só em desenvolvimento: para inspecionar os dados na consola.
  if (process.env.NODE_ENV !== "production") (globalThis as Record<string, unknown>).__mynikDb = db;
  version += 1;
  for (const l of versionListeners) l();
}

export function getDb(): Db {
  if (!current) throw new Error("Sem fonte de dados");
  return current;
}

/** Linhas não apagadas de uma tabela, sempre atualizadas. */
export function useTable<T extends TableName>(table: T): { rows: Tables[T][]; loading: boolean; error: Error | null } {
  const e = entry(table);
  const subscribe = useCallback(
    (cb: () => void) => {
      e.listeners.add(cb);
      if (e.stale || (!e.rows && !e.loading)) void load(table);
      return () => e.listeners.delete(cb);
    },
    [e, table],
  );
  const rows = useSyncExternalStore(subscribe, () => e.rows, () => null) as Tables[T][] | null;
  const error = useSyncExternalStore(subscribe, () => e.error, () => null);
  return { rows: rows ?? (EMPTY as Tables[T][]), loading: rows === null && !error, error };
}
const EMPTY: never[] = [];

/** Várias tabelas de uma vez (para cálculos que juntam módulos). */
export function useTables<const T extends readonly TableName[]>(...tables: T) {
  const results = tables.map((t) => useTable(t)); // eslint-disable-line react-hooks/rules-of-hooks
  return {
    data: Object.fromEntries(tables.map((t, i) => [t, results[i].rows])) as { [K in T[number]]: Tables[K][] },
    loading: results.some((r) => r.loading),
  };
}

/** Resultado de uma função SQL, recalculado quando muda uma das tabelas de que depende. */
export function useRpc<R>(fn: string, args: Record<string, unknown>, dependsOn: TableName[]) {
  const [state, setState] = useState<{ data: R[] | null; error: Error | null }>({ data: null, error: null });
  const key = JSON.stringify(args);
  const deps = useRef(dependsOn);
  deps.current = dependsOn;
  const dbVersion = useSyncExternalStore(
    (cb) => {
      versionListeners.add(cb);
      return () => versionListeners.delete(cb);
    },
    () => version,
    () => 0,
  );

  const run = useCallback(async () => {
    if (!current) return;
    try {
      const data = await current.rpc<R>(fn, JSON.parse(key));
      setState({ data, error: null });
    } catch (error) {
      setState((s) => ({ data: s.data, error: error as Error }));
    }
  }, [fn, key]);

  useEffect(() => {
    void run();
    const listener = (table: TableName) => {
      if (deps.current.includes(table)) void run();
    };
    rpcListeners.add(listener);
    return () => {
      rpcListeners.delete(listener);
    };
  }, [run, dbVersion]);

  return useMemo(() => ({ data: state.data ?? [], loading: state.data === null && !state.error, error: state.error, reload: run }), [state, run]);
}

function report(error: unknown): never {
  const message = error instanceof Error ? error.message : String(error);
  toast.error("Não foi possível guardar", { description: message });
  throw error;
}

/** Escritas com last-write-wins e tombstones (o iPhone recebe tudo). */
export const mutate = {
  async insert<T extends TableName>(table: T, row: RowInput<T>) {
    try {
      const inserted = await getDb().insert(table, row);
      changed(table);
      return inserted;
    } catch (error) {
      return report(error);
    }
  },
  async update<T extends TableName>(table: T, id: string, patch: RowInput<T>) {
    try {
      await getDb().update(table, id, patch);
      const e = entry(table);
      if (e.rows) {
        e.rows = e.rows.map((r) => ((r as { id: string }).id === id ? { ...(r as object), ...patch } : r));
        notify(e);
      }
      changed(table);
    } catch (error) {
      report(error);
    }
  },
  async remove(table: TableName, ids: string[]) {
    try {
      await getDb().remove(table, ids);
      const e = entry(table);
      if (e.rows) {
        e.rows = e.rows.filter((r) => !ids.includes((r as { id: string }).id));
        notify(e);
      }
      changed(table);
    } catch (error) {
      report(error);
    }
  },
};
