-- Mynik — sync local-first (Fase 9)
--
-- Uma só tabela genérica: cada linha é um registo da cópia de segurança do Mynik
-- (o mesmo JSON de `BackupRecords.swift`), por isso mudar os modelos SwiftData
-- não obriga a mudar a base de dados.
--
--   entity       tipo do registo (SyncEntity.rawValue: "transaction", "bill"…)
--   key          identificador estável (uid, id da Shopify ou dia)
--   payload      registo em JSON; NULL nos tombstones
--   deleted      tombstone: o registo foi apagado
--   modified_at  hora da alteração no dispositivo → last-write-wins
--   updated_at   hora em que o servidor gravou → cursor do pull incremental

create table if not exists public.records (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    entity      text        not null,
    key         text        not null,
    payload     jsonb,
    deleted     boolean     not null default false,
    modified_at timestamptz not null,
    updated_at  timestamptz not null default now(),
    primary key (user_id, entity, key)
);

create index if not exists records_user_updated_idx on public.records (user_id, updated_at);

-- Last-write-wins no servidor: uma escrita mais antiga do que a guardada é ignorada,
-- e qualquer escrita aceite recebe a hora do servidor (para o pull incremental).
create or replace function public.records_last_write_wins()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'UPDATE' and new.modified_at < old.modified_at then
        return null;
    end if;
    new.updated_at := clock_timestamp();
    if new.deleted then
        new.payload := null;
    end if;
    return new;
end;
$$;

drop trigger if exists records_last_write_wins on public.records;
create trigger records_last_write_wins
    before insert or update on public.records
    for each row execute function public.records_last_write_wins();

-- Cada utilizador só vê e escreve as suas linhas.
alter table public.records enable row level security;

drop policy if exists "records_select_own" on public.records;
create policy "records_select_own" on public.records
    for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "records_insert_own" on public.records;
create policy "records_insert_own" on public.records
    for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "records_update_own" on public.records;
create policy "records_update_own" on public.records
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists "records_delete_own" on public.records;
create policy "records_delete_own" on public.records
    for delete to authenticated using ((select auth.uid()) = user_id);

revoke all on public.records from anon;
grant select, insert, update, delete on public.records to authenticated;
