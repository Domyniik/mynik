// Postgres em memória (PGlite) com o mínimo do Supabase para testar as migrações:
// esquema `auth` com `auth.users` e `auth.uid()`, e os papéis `anon` e `authenticated`.
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PGlite } from "@electric-sql/pglite";

const migrations = join(dirname(fileURLToPath(import.meta.url)), "..", "migrations");

export const USER_A = "11111111-1111-1111-1111-111111111111";
export const USER_B = "22222222-2222-2222-2222-222222222222";

const supabaseStub = `
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
insert into auth.users (id) values ('${USER_A}'), ('${USER_B}');
`;

/** Base de dados nova com todas as migrações aplicadas, por ordem. */
export async function freshDatabase() {
  const db = new PGlite();
  await db.exec(supabaseStub);
  for (const file of readdirSync(migrations).filter((f) => f.endsWith(".sql")).sort()) {
    await db.exec(readFileSync(join(migrations, file), "utf8"));
  }
  return db;
}

/** Corre `fn` como o utilizador `userID` (papel authenticated, como o PostgREST). */
export async function asUser(db, userID, fn) {
  return db.transaction(async (tx) => {
    await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [userID]);
    await tx.exec("set local role authenticated");
    return fn(tx);
  });
}

/** Data do iOS (segundos desde 1/1/2001) a partir de um texto ISO. */
export const iosDate = (iso) => Date.parse(iso) / 1000 - 978307200;
