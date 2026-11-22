#!/usr/bin/env node
// Gera a migração das tabelas tipadas a partir de `entities.mjs`.
//
//   node supabase/schema/generate.mjs
//
// Saída: supabase/migrations/20261122000000_typed_tables.sql
// Não editar o SQL gerado à mão: mudar `entities.mjs` e voltar a gerar
// (uma alteração depois de aplicada vai numa migração nova).
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { columnName, entities } from "./entities.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const output = join(here, "..", "migrations", "20261122000000_typed_tables.sql");

const sqlType = {
  text: "text",
  int: "bigint",
  double: "double precision",
  numeric: "numeric",
  bool: "boolean",
  date: "timestamptz",
  jsonb: "jsonb",
  "text[]": "text[]",
  base64: "text",
};

const typeDefault = {
  text: "''",
  int: "0",
  double: "0",
  numeric: "0",
  bool: "false",
  date: "now()",
  jsonb: "'{}'::jsonb",
  "text[]": "'{}'::text[]",
  base64: "''",
};

const quote = (text) => `'${text.replaceAll("'", "''")}'`;

function columnSQL(field) {
  const column = columnName(field);
  const type = sqlType[field.type];
  if (!type) throw new Error(`Tipo desconhecido: ${field.type}`);
  if (column === "id") return null; // a chave é comum a todas as tabelas
  if (field.optional) {
    return `    ${column} ${type}${field.default ? ` default ${field.default}` : ""}`;
  }
  return `    ${column} ${type} not null default ${field.default ?? typeDefault[field.type]}`;
}

function tableSQL(entity) {
  const idField = entity.fields.find((f) => columnName(f) === "id");
  const idDefault = idField?.default ? ` default ${idField.default}` : "";
  const columns = entity.fields.map(columnSQL).filter(Boolean);
  const t = entity.table;
  return `
-- ${entity.entity}
create table if not exists public.${t} (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null${idDefault},
${columns.join(",\n")},
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists ${t}_user_updated_idx on public.${t} (user_id, updated_at);
drop trigger if exists ${t}_last_write_wins on public.${t};
create trigger ${t}_last_write_wins before insert or update on public.${t}
    for each row execute function public.sync_last_write_wins();
alter table public.${t} enable row level security;
drop policy if exists "${t}_select_own" on public.${t};
create policy "${t}_select_own" on public.${t} for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "${t}_insert_own" on public.${t};
create policy "${t}_insert_own" on public.${t} for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "${t}_update_own" on public.${t};
create policy "${t}_update_own" on public.${t} for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "${t}_delete_own" on public.${t};
create policy "${t}_delete_own" on public.${t} for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.${t} from anon;
grant select, insert, update, delete on public.${t} to authenticated;
`;
}

const metadata = entities
  .map((e) => `    (${quote(e.entity)}, ${quote(e.table)}, ${e.keyField ? quote(e.keyField) : "null"})`)
  .join(",\n");

const fieldRows = entities
  .flatMap((e) =>
    e.fields.map(
      (f, i) =>
        `    (${quote(e.entity)}, ${i}, ${quote(f.json)}, ${quote(columnName(f))}, ${quote(f.type)}, ${f.optional ? "true" : "false"})`,
    ),
  )
  .join(",\n");

const sql = `-- Mynik — tabelas tipadas (Fase 11)
--
-- GERADO por supabase/schema/generate.mjs a partir de supabase/schema/entities.mjs.
-- Não editar à mão.
--
-- Uma tabela por tipo de registo, com as colunas do modelo do iOS em snake_case.
-- Todas têm as mesmas colunas de sync:
--   user_id      dono (RLS: cada utilizador só vê e escreve as suas linhas)
--   id           chave estável (uid, id da Shopify, dia ou nome da definição)
--   deleted      tombstone: o registo foi apagado noutro dispositivo
--   modified_at  hora da alteração no dispositivo → last-write-wins
--   updated_at   hora em que o servidor gravou → cursor do pull incremental
--
-- O iPhone sincroniza com sync_push / sync_pull (o mesmo formato JSON da cópia
-- de segurança); a app web lê e escreve as tabelas diretamente.
-- A tabela antiga \`records\` fica intacta até a migração estar confirmada.

-- Last-write-wins: uma escrita mais antiga do que a guardada é ignorada.
-- Escritas diretas (app web) sem modified_at novo contam como feitas agora; as
-- do sync (sync_apply, que marca mynik.sync) mantêm a hora do dispositivo.
create or replace function public.sync_last_write_wins()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'UPDATE' then
        if new.modified_at < old.modified_at then
            return null;
        end if;
        if new.modified_at = old.modified_at
           and coalesce(current_setting('mynik.sync', true), '') <> 'on' then
            new.modified_at := clock_timestamp();
        end if;
    end if;
    new.updated_at := clock_timestamp();
    return new;
end;
$$;
${entities.map(tableSQL).join("")}
-- Metadados do sync: que tabela e que coluna corresponde a cada campo do registo do iOS.
create table if not exists public.sync_entities (
    entity     text primary key,
    table_name text not null,
    key_field  text
);
create table if not exists public.sync_fields (
    entity      text    not null references public.sync_entities (entity) on delete cascade,
    ord         integer not null,
    json_key    text    not null,
    column_name text    not null,
    type        text    not null,
    optional    boolean not null,
    primary key (entity, json_key)
);
truncate public.sync_fields, public.sync_entities;
insert into public.sync_entities (entity, table_name, key_field) values
${metadata};
insert into public.sync_fields (entity, ord, json_key, column_name, type, optional) values
${fieldRows};
alter table public.sync_entities enable row level security;
alter table public.sync_fields enable row level security;
drop policy if exists "sync_entities_read" on public.sync_entities;
create policy "sync_entities_read" on public.sync_entities for select to authenticated using (true);
drop policy if exists "sync_fields_read" on public.sync_fields;
create policy "sync_fields_read" on public.sync_fields for select to authenticated using (true);
revoke all on public.sync_entities, public.sync_fields from anon;
grant select on public.sync_entities, public.sync_fields to authenticated;

-- Segundos desde 1/1/2001 (datas do iOS) → timestamptz, ao microssegundo.
create or replace function public.sync_date_from_ios(seconds numeric)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
    select timestamptz '1970-01-01 00:00:00+00'
        + (round((seconds + 978307200) * 1000000))::bigint * interval '1 microsecond'
$$;

-- Grava linhas no formato do iPhone: [{entity, key, payload, deleted, modified_at}]
-- como sendo de p_user. O payload é o registo da cópia de segurança; cada campo
-- vai para a sua coluna. Campos em falta (versões antigas) ficam com o valor por
-- omissão da coluna. Corre com os direitos de quem chama: pela API, a RLS só
-- deixa escrever as linhas do próprio utilizador.
create or replace function public.sync_apply(p_user uuid, p_rows jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_user uuid := p_user;
    r jsonb;
    ent public.sync_entities%rowtype;
    f public.sync_fields%rowtype;
    payload jsonb;
    data jsonb;
    cols text[];
    v jsonb;
    is_deleted boolean;
    col_list text;
    set_list text;
begin
    if v_user is null then
        raise exception 'sync_apply: sem utilizador';
    end if;
    perform set_config('mynik.sync', 'on', true);
    for r in select value from jsonb_array_elements(p_rows) loop
        select * into ent from public.sync_entities e where e.entity = r ->> 'entity';
        if not found then
            continue; -- tipo de uma versão mais recente da app: ignorado
        end if;
        is_deleted := coalesce((r ->> 'deleted')::boolean, false);
        payload := r -> 'payload';
        data := jsonb_build_object(
            'user_id', v_user,
            'id', r ->> 'key',
            'deleted', is_deleted,
            'modified_at', r ->> 'modified_at'
        );
        cols := array['user_id', 'id', 'deleted', 'modified_at'];
        if not is_deleted and jsonb_typeof(payload) = 'object' then
            for f in select * from public.sync_fields sf where sf.entity = ent.entity order by sf.ord loop
                continue when f.column_name = 'id' or not (payload ? f.json_key);
                v := payload -> f.json_key;
                if f.type = 'date' and jsonb_typeof(v) = 'number' then
                    v := to_jsonb(public.sync_date_from_ios((v #>> '{}')::numeric));
                end if;
                data := data || jsonb_build_object(f.column_name, v);
                cols := cols || f.column_name;
            end loop;
        end if;
        select string_agg(format('%I', c), ', ') into col_list from unnest(cols) c;
        select string_agg(format('%I = excluded.%I', c, c), ', ') into set_list
            from unnest(cols) c where c not in ('user_id', 'id');
        execute format(
            'insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I, $1) '
            'on conflict (user_id, id) do update set %s',
            ent.table_name, col_list, col_list, ent.table_name, set_list
        ) using data;
    end loop;
    perform set_config('mynik.sync', '', true);
end;
$$;

-- Envia linhas do iPhone para a conta com sessão iniciada.
create or replace function public.sync_push(p_rows jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if auth.uid() is null then
        raise exception 'sync_push: sem sessão';
    end if;
    perform public.sync_apply(auth.uid(), p_rows);
end;
$$;

-- Linhas alteradas desde p_since (todas, se nulo), no formato do iPhone.
create or replace function public.sync_pull(p_since timestamptz default null, p_limit integer default 1000, p_offset integer default 0)
returns table (entity text, key text, payload jsonb, deleted boolean, modified_at timestamptz, updated_at timestamptz)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
    parts text[] := '{}';
    ent public.sync_entities%rowtype;
    pairs text;
begin
    for ent in select * from public.sync_entities e order by e.entity loop
        select string_agg(
            format('%L, %s', f.json_key,
                case f.type
                    when 'date' then format('extract(epoch from t.%I) - 978307200', f.column_name)
                    else format('t.%I', f.column_name)
                end),
            ', ' order by f.ord)
        into pairs
        from public.sync_fields f where f.entity = ent.entity;
        parts := parts || format(
            'select %L::text, t.id, case when t.deleted then null else jsonb_strip_nulls(jsonb_build_object(%s)) end, '
            't.deleted, t.modified_at, t.updated_at from public.%I t '
            'where t.user_id = auth.uid() and ($1 is null or t.updated_at >= $1)',
            ent.entity, pairs, ent.table_name);
    end loop;
    return query execute
        'select * from (' || array_to_string(parts, ' union all ') || ') s(entity, key, payload, deleted, modified_at, updated_at) '
        'order by s.updated_at, s.entity, s.key limit $2 offset $3'
        using p_since, p_limit, p_offset;
end;
$$;

revoke all on function public.sync_apply(uuid, jsonb) from public, anon;
revoke all on function public.sync_push(jsonb) from public, anon;
revoke all on function public.sync_pull(timestamptz, integer, integer) from public, anon;
grant execute on function public.sync_apply(uuid, jsonb) to authenticated;
grant execute on function public.sync_push(jsonb) to authenticated;
grant execute on function public.sync_pull(timestamptz, integer, integer) to authenticated;
`;

writeFileSync(output, sql);
console.log(`Gerado ${output} (${entities.length} tabelas)`);
