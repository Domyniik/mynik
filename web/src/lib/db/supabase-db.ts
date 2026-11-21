import type { SupabaseClient } from "@supabase/supabase-js";
import { type ChangeListener, type Db, now, type RowInput } from "./client";
import { type TableName, tableNames, type Tables } from "./schema";

const PAGE = 1000;

/** Dados na conta Supabase do utilizador (RLS: só as suas linhas). */
export class SupabaseDb implements Db {
  readonly mode = "cloud" as const;
  private listeners = new Set<ChangeListener>();
  private channel: ReturnType<SupabaseClient["channel"]> | null = null;

  constructor(private readonly client: SupabaseClient) {}

  async list<T extends TableName>(table: T): Promise<Tables[T][]> {
    const rows: Tables[T][] = [];
    for (let from = 0; ; from += PAGE) {
      const { data, error } = await this.client
        .from(table)
        .select("*")
        .eq("deleted", false)
        .order("id")
        .range(from, from + PAGE - 1);
      if (error) throw error;
      rows.push(...((data ?? []) as Tables[T][]));
      if (!data || data.length < PAGE) return rows;
    }
  }

  async insert<T extends TableName>(table: T, row: RowInput<T>): Promise<Tables[T]> {
    const { data, error } = await this.client
      .from(table)
      .insert({ ...row, modified_at: now() })
      .select()
      .single();
    if (error) throw error;
    this.emit(table);
    return data as Tables[T];
  }

  async update<T extends TableName>(table: T, id: string, patch: RowInput<T>): Promise<void> {
    const { error } = await this.client
      .from(table)
      .update({ ...patch, modified_at: now() })
      .eq("id", id);
    if (error) throw error;
    this.emit(table);
  }

  async remove(table: TableName, ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    const { error } = await this.client
      .from(table)
      .update({ deleted: true, modified_at: now() })
      .in("id", ids);
    if (error) throw error;
    this.emit(table);
  }

  async rpc<R>(fn: string, args: Record<string, unknown>): Promise<R[]> {
    const { data, error } = await this.client.rpc(fn, args);
    if (error) throw error;
    return (Array.isArray(data) ? data : data == null ? [] : [data]) as R[];
  }

  async invoke<R>(fn: string, body?: unknown): Promise<R> {
    const { data, error } = await this.client.functions.invoke(fn, { body: body ?? {} });
    if (error) throw error;
    return data as R;
  }

  subscribe(listener: ChangeListener): () => void {
    this.listeners.add(listener);
    if (!this.channel) {
      // Alterações feitas no iPhone (ou noutra janela) chegam pelo Realtime.
      let channel = this.client.channel("mynik-changes");
      for (const table of tableNames) {
        channel = channel.on("postgres_changes", { event: "*", schema: "public", table }, () => this.emit(table));
      }
      this.channel = channel.subscribe();
    }
    return () => {
      this.listeners.delete(listener);
    };
  }

  private emit(table: TableName) {
    for (const listener of this.listeners) listener(table);
  }
}
