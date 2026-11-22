import type { PGlite, Results, Transaction } from "@electric-sql/pglite";
import { type ChangeListener, type Db, now, type RowInput } from "./client";
import { columnTypes, type TableName, tableNames, type Tables } from "./schema";

/** Utilizador fictício do modo de demonstração. */
export const DEMO_USER = "00000000-0000-4000-8000-000000000001";

/** O mínimo do Supabase para as migrações correrem: auth.users, auth.uid() e os papéis. */
const SUPABASE_STUB = `
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to anon, authenticated;
grant usage on schema public to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
insert into auth.users (id) values ('${DEMO_USER}');
`;

const IDENTIFIER = /^[a-z_][a-z0-9_]*$/;
const NUMERIC_OIDS = new Set([20, 21, 23, 700, 701, 1700]);
const TIMESTAMP_OIDS = new Set([1114, 1184]);
const DATE_OID = 1082;

function assertIdentifier(name: string) {
  if (!IDENTIFIER.test(name)) throw new Error(`Nome inválido: ${name}`);
}

function assertTable(table: string): asserts table is TableName {
  if (!tableNames.includes(table as TableName)) throw new Error(`Tabela desconhecida: ${table}`);
}

/** Converte os valores do PGlite para o formato do supabase-js (números e datas ISO). */
function normalize<R>(result: Results<Record<string, unknown>>): R[] {
  const numeric = result.fields.filter((f) => NUMERIC_OIDS.has(f.dataTypeID)).map((f) => f.name);
  const dates = result.fields.filter((f) => TIMESTAMP_OIDS.has(f.dataTypeID)).map((f) => f.name);
  const days = result.fields.filter((f) => f.dataTypeID === DATE_OID).map((f) => f.name);
  return result.rows.map((row) => {
    const copy: Record<string, unknown> = { ...row };
    for (const name of numeric) if (copy[name] != null) copy[name] = Number(copy[name]);
    for (const name of dates) {
      const value = copy[name];
      if (value instanceof Date) copy[name] = value.toISOString();
    }
    // Colunas `date`: "AAAA-MM-DD", como o PostgREST.
    for (const name of days) {
      const value = copy[name];
      if (value instanceof Date) {
        const pad = (n: number) => String(n).padStart(2, "0");
        copy[name] = `${value.getUTCFullYear()}-${pad(value.getUTCMonth() + 1)}-${pad(value.getUTCDate())}`;
      }
    }
    return copy as R;
  });
}

/** Valor para uma coluna: jsonb vai como texto JSON. */
function param(table: TableName, column: string, value: unknown) {
  const type = (columnTypes[table] as Record<string, string>)[column];
  if (type === "jsonb" && value != null) return JSON.stringify(value);
  return value;
}

type Seed = (db: PGlite, user: string) => Promise<void>;

/**
 * Modo de demonstração: um Postgres inteiro no browser (PGlite), com as mesmas
 * migrações do Supabase. As funções de cálculo (score, lucro, orçamento) são
 * as mesmas da conta real; os dados não saem do browser e somem ao recarregar.
 */
export class LocalDb implements Db {
  readonly mode = "demo" as const;
  private readonly ready: Promise<PGlite>;
  private listeners = new Set<ChangeListener>();

  constructor(loadMigrations: () => Promise<string[]>, seed: Seed) {
    this.ready = (async () => {
      const { PGlite } = await import("@electric-sql/pglite");
      const db = await PGlite.create();
      await db.exec(SUPABASE_STUB);
      for (const sql of await loadMigrations()) await db.exec(sql);
      await seed(db, DEMO_USER);
      return db;
    })();
  }

  /** Corre `fn` como o utilizador da demo, com RLS (como o PostgREST). */
  private async asUser<R>(fn: (tx: Transaction) => Promise<R>): Promise<R> {
    const db = await this.ready;
    return db.transaction(async (tx) => {
      await tx.query("select set_config('request.jwt.claim.sub', $1, true)", [DEMO_USER]);
      await tx.exec("set local role authenticated");
      return fn(tx);
    });
  }

  async list<T extends TableName>(table: T): Promise<Tables[T][]> {
    assertTable(table);
    return this.asUser(async (tx) =>
      normalize<Tables[T]>(await tx.query(`select * from public.${table} where not deleted order by id`)),
    );
  }

  async insert<T extends TableName>(table: T, row: RowInput<T>): Promise<Tables[T]> {
    assertTable(table);
    const entries = Object.entries({ ...row, modified_at: now() }).filter(([, v]) => v !== undefined);
    entries.forEach(([k]) => assertIdentifier(k));
    const columns = entries.map(([k]) => k).join(", ");
    const values = entries.map((_, i) => `$${i + 1}`).join(", ");
    const [inserted] = await this.asUser(async (tx) =>
      normalize<Tables[T]>(
        await tx.query(
          `insert into public.${table} (${columns}) values (${values}) returning *`,
          entries.map(([k, v]) => param(table, k, v)),
        ),
      ),
    );
    this.emit(table);
    return inserted;
  }

  async update<T extends TableName>(table: T, id: string, patch: RowInput<T>): Promise<void> {
    assertTable(table);
    const entries = Object.entries({ ...patch, modified_at: now() }).filter(([k, v]) => v !== undefined && k !== "id");
    entries.forEach(([k]) => assertIdentifier(k));
    const sets = entries.map(([k], i) => `${k} = $${i + 1}`).join(", ");
    await this.asUser((tx) =>
      tx.query(`update public.${table} set ${sets} where id = $${entries.length + 1}`, [
        ...entries.map(([k, v]) => param(table, k, v)),
        id,
      ]),
    );
    this.emit(table);
  }

  async remove(table: TableName, ids: string[]): Promise<void> {
    assertTable(table);
    if (ids.length === 0) return;
    await this.asUser((tx) =>
      tx.query(`update public.${table} set deleted = true, modified_at = $1 where id = any($2)`, [now(), ids]),
    );
    this.emit(table);
  }

  async rpc<R>(fn: string, args: Record<string, unknown>): Promise<R[]> {
    assertIdentifier(fn);
    const entries = Object.entries(args).filter(([, v]) => v !== undefined);
    entries.forEach(([k]) => assertIdentifier(k));
    const list = entries.map(([k], i) => `${k} => $${i + 1}`).join(", ");
    return this.asUser(async (tx) =>
      normalize<R>(await tx.query(`select * from public.${fn}(${list})`, entries.map(([, v]) => v))),
    );
  }

  async invoke<R>(fn: string): Promise<R> {
    throw new Error(`"${fn}" precisa da conta (Edge Function): indisponível no modo de demonstração.`);
  }

  subscribe(listener: ChangeListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private emit(table: TableName) {
    for (const listener of this.listeners) listener(table);
  }
}
