import type { TableName, Tables } from "./schema";

/** Linha nova ou alteração: o servidor preenche user_id, updated_at e os valores por omissão. */
export type RowInput<T extends TableName> = Partial<Omit<Tables[T], "user_id" | "updated_at">>;

/** Alteração vinda de outro dispositivo (Realtime) ou desta janela. */
export type ChangeListener = (table: TableName) => void;

/**
 * Acesso aos dados do Mynik. Duas implementações com o mesmo esquema:
 * - `SupabaseDb`: a conta do utilizador (iPhone e desktop veem o mesmo);
 * - `LocalDb`: modo de demonstração, Postgres no browser (PGlite) com as
 *   mesmas migrações e funções de cálculo.
 */
export interface Db {
  readonly mode: "cloud" | "demo";
  /** Linhas não apagadas da tabela. */
  list<T extends TableName>(table: T): Promise<Tables[T][]>;
  insert<T extends TableName>(table: T, row: RowInput<T>): Promise<Tables[T]>;
  update<T extends TableName>(table: T, id: string, patch: RowInput<T>): Promise<void>;
  /** Apaga com tombstone (`deleted = true`): o iPhone apaga também. */
  remove(table: TableName, ids: string[]): Promise<void>;
  /** Função SQL (cálculos e sync). */
  rpc<R>(fn: string, args: Record<string, unknown>): Promise<R[]>;
  /** Edge Function do Supabase (Shopify, cotações, combustível). */
  invoke<R>(fn: string, body?: unknown): Promise<R>;
  subscribe(listener: ChangeListener): () => void;
}

/** Hora da alteração (last-write-wins com o iPhone). */
export const now = () => new Date().toISOString();

/** Identificador novo no formato do iPhone (`UUID().uuidString`). */
export const newID = () => crypto.randomUUID().toUpperCase();
