-- Mynik — tabelas tipadas (Fase 11)
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
-- A tabela antiga `records` fica intacta até a migração estar confirmada.

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

-- category
create table if not exists public.categories (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    name text not null default '',
    symbol_name text not null default 'tag',
    color_name text not null default 'gray',
    kind text not null default 'expense',
    sort_order bigint not null default 0,
    monthly_budget numeric not null default 0,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists categories_user_updated_idx on public.categories (user_id, updated_at);
drop trigger if exists categories_last_write_wins on public.categories;
create trigger categories_last_write_wins before insert or update on public.categories
    for each row execute function public.sync_last_write_wins();
alter table public.categories enable row level security;
drop policy if exists "categories_select_own" on public.categories;
create policy "categories_select_own" on public.categories for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "categories_insert_own" on public.categories;
create policy "categories_insert_own" on public.categories for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "categories_update_own" on public.categories;
create policy "categories_update_own" on public.categories for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "categories_delete_own" on public.categories;
create policy "categories_delete_own" on public.categories for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.categories from anon;
grant select, insert, update, delete on public.categories to authenticated;

-- account
create table if not exists public.accounts (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    name text not null default '',
    type text not null default 'checking',
    currency_code text not null default 'EUR',
    initial_balance numeric not null default 0,
    is_archived boolean not null default false,
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists accounts_user_updated_idx on public.accounts (user_id, updated_at);
drop trigger if exists accounts_last_write_wins on public.accounts;
create trigger accounts_last_write_wins before insert or update on public.accounts
    for each row execute function public.sync_last_write_wins();
alter table public.accounts enable row level security;
drop policy if exists "accounts_select_own" on public.accounts;
create policy "accounts_select_own" on public.accounts for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "accounts_insert_own" on public.accounts;
create policy "accounts_insert_own" on public.accounts for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "accounts_update_own" on public.accounts;
create policy "accounts_update_own" on public.accounts for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "accounts_delete_own" on public.accounts;
create policy "accounts_delete_own" on public.accounts for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.accounts from anon;
grant select, insert, update, delete on public.accounts to authenticated;

-- transaction
create table if not exists public.transactions (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    title text not null default '',
    amount numeric not null default 0,
    kind text not null default 'expense',
    currency_code text not null default 'EUR',
    date timestamptz not null default now(),
    notes text not null default '',
    created_at timestamptz not null default now(),
    external_id text not null default '',
    category_id text,
    account_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists transactions_user_updated_idx on public.transactions (user_id, updated_at);
drop trigger if exists transactions_last_write_wins on public.transactions;
create trigger transactions_last_write_wins before insert or update on public.transactions
    for each row execute function public.sync_last_write_wins();
alter table public.transactions enable row level security;
drop policy if exists "transactions_select_own" on public.transactions;
create policy "transactions_select_own" on public.transactions for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "transactions_insert_own" on public.transactions;
create policy "transactions_insert_own" on public.transactions for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "transactions_update_own" on public.transactions;
create policy "transactions_update_own" on public.transactions for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "transactions_delete_own" on public.transactions;
create policy "transactions_delete_own" on public.transactions for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.transactions from anon;
grant select, insert, update, delete on public.transactions to authenticated;

-- bill
create table if not exists public.bills (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    title text not null default '',
    amount numeric not null default 0,
    currency_code text not null default 'EUR',
    due_date timestamptz not null default now(),
    is_paid boolean not null default false,
    paid_at timestamptz,
    recurrence text not null default 'none',
    notes text not null default '',
    is_subscription boolean not null default false,
    created_at timestamptz not null default now(),
    category_id text,
    account_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists bills_user_updated_idx on public.bills (user_id, updated_at);
drop trigger if exists bills_last_write_wins on public.bills;
create trigger bills_last_write_wins before insert or update on public.bills
    for each row execute function public.sync_last_write_wins();
alter table public.bills enable row level security;
drop policy if exists "bills_select_own" on public.bills;
create policy "bills_select_own" on public.bills for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "bills_insert_own" on public.bills;
create policy "bills_insert_own" on public.bills for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "bills_update_own" on public.bills;
create policy "bills_update_own" on public.bills for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "bills_delete_own" on public.bills;
create policy "bills_delete_own" on public.bills for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.bills from anon;
grant select, insert, update, delete on public.bills to authenticated;

-- storeProduct
create table if not exists public.store_products (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null,
    title text not null default '',
    handle text not null default '',
    status text not null default 'ACTIVE',
    image_url text not null default '',
    price numeric not null default 0,
    unit_cost numeric not null default 0,
    unit_cost_is_manual boolean not null default false,
    inventory bigint not null default 0,
    tracks_inventory boolean not null default true,
    created_at timestamptz not null default now(),
    ad_spend_30d numeric not null default 0,
    decision text not null default '',
    decided_at timestamptz,
    decision_note text not null default '',
    synced_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists store_products_user_updated_idx on public.store_products (user_id, updated_at);
drop trigger if exists store_products_last_write_wins on public.store_products;
create trigger store_products_last_write_wins before insert or update on public.store_products
    for each row execute function public.sync_last_write_wins();
alter table public.store_products enable row level security;
drop policy if exists "store_products_select_own" on public.store_products;
create policy "store_products_select_own" on public.store_products for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "store_products_insert_own" on public.store_products;
create policy "store_products_insert_own" on public.store_products for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "store_products_update_own" on public.store_products;
create policy "store_products_update_own" on public.store_products for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "store_products_delete_own" on public.store_products;
create policy "store_products_delete_own" on public.store_products for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.store_products from anon;
grant select, insert, update, delete on public.store_products to authenticated;

-- storeOrder
create table if not exists public.store_orders (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null,
    name text not null default '',
    created_at timestamptz not null default now(),
    cancelled_at timestamptz,
    subtotal numeric not null default 0,
    shipping numeric not null default 0,
    tax numeric not null default 0,
    total numeric not null default 0,
    refunded numeric not null default 0,
    currency_code text not null default 'EUR',
    financial_status text not null default '',
    fulfillment_status text not null default '',
    lines jsonb not null default '[]'::jsonb,
    synced_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists store_orders_user_updated_idx on public.store_orders (user_id, updated_at);
drop trigger if exists store_orders_last_write_wins on public.store_orders;
create trigger store_orders_last_write_wins before insert or update on public.store_orders
    for each row execute function public.sync_last_write_wins();
alter table public.store_orders enable row level security;
drop policy if exists "store_orders_select_own" on public.store_orders;
create policy "store_orders_select_own" on public.store_orders for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "store_orders_insert_own" on public.store_orders;
create policy "store_orders_insert_own" on public.store_orders for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "store_orders_update_own" on public.store_orders;
create policy "store_orders_update_own" on public.store_orders for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "store_orders_delete_own" on public.store_orders;
create policy "store_orders_delete_own" on public.store_orders for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.store_orders from anon;
grant select, insert, update, delete on public.store_orders to authenticated;

-- storeCheckout
create table if not exists public.store_checkouts (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null,
    name text not null default '',
    created_at timestamptz not null default now(),
    total numeric not null default 0,
    recovery_url text not null default '',
    lines jsonb not null default '[]'::jsonb,
    synced_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists store_checkouts_user_updated_idx on public.store_checkouts (user_id, updated_at);
drop trigger if exists store_checkouts_last_write_wins on public.store_checkouts;
create trigger store_checkouts_last_write_wins before insert or update on public.store_checkouts
    for each row execute function public.sync_last_write_wins();
alter table public.store_checkouts enable row level security;
drop policy if exists "store_checkouts_select_own" on public.store_checkouts;
create policy "store_checkouts_select_own" on public.store_checkouts for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "store_checkouts_insert_own" on public.store_checkouts;
create policy "store_checkouts_insert_own" on public.store_checkouts for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "store_checkouts_update_own" on public.store_checkouts;
create policy "store_checkouts_update_own" on public.store_checkouts for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "store_checkouts_delete_own" on public.store_checkouts;
create policy "store_checkouts_delete_own" on public.store_checkouts for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.store_checkouts from anon;
grant select, insert, update, delete on public.store_checkouts to authenticated;

-- dailyStat
create table if not exists public.daily_stats (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null,
    date timestamptz not null default now(),
    sales numeric not null default 0,
    net_revenue numeric not null default 0,
    orders bigint not null default 0,
    units bigint not null default 0,
    refunds numeric not null default 0,
    sessions bigint not null default 0,
    cart_sessions bigint not null default 0,
    checkout_sessions bigint not null default 0,
    completed_sessions bigint not null default 0,
    has_traffic boolean not null default false,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists daily_stats_user_updated_idx on public.daily_stats (user_id, updated_at);
drop trigger if exists daily_stats_last_write_wins on public.daily_stats;
create trigger daily_stats_last_write_wins before insert or update on public.daily_stats
    for each row execute function public.sync_last_write_wins();
alter table public.daily_stats enable row level security;
drop policy if exists "daily_stats_select_own" on public.daily_stats;
create policy "daily_stats_select_own" on public.daily_stats for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "daily_stats_insert_own" on public.daily_stats;
create policy "daily_stats_insert_own" on public.daily_stats for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "daily_stats_update_own" on public.daily_stats;
create policy "daily_stats_update_own" on public.daily_stats for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "daily_stats_delete_own" on public.daily_stats;
create policy "daily_stats_delete_own" on public.daily_stats for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.daily_stats from anon;
grant select, insert, update, delete on public.daily_stats to authenticated;

-- project
create table if not exists public.projects (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    name text not null default '',
    details text not null default '',
    symbol_name text not null default 'folder',
    color_name text not null default 'blue',
    status text not null default 'active',
    due_date timestamptz,
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists projects_user_updated_idx on public.projects (user_id, updated_at);
drop trigger if exists projects_last_write_wins on public.projects;
create trigger projects_last_write_wins before insert or update on public.projects
    for each row execute function public.sync_last_write_wins();
alter table public.projects enable row level security;
drop policy if exists "projects_select_own" on public.projects;
create policy "projects_select_own" on public.projects for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "projects_insert_own" on public.projects;
create policy "projects_insert_own" on public.projects for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "projects_update_own" on public.projects;
create policy "projects_update_own" on public.projects for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "projects_delete_own" on public.projects;
create policy "projects_delete_own" on public.projects for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.projects from anon;
grant select, insert, update, delete on public.projects to authenticated;

-- task
create table if not exists public.tasks (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    title text not null default '',
    notes text not null default '',
    status text not null default 'todo',
    priority bigint not null default 1,
    due_date timestamptz,
    completed_at timestamptz,
    created_at timestamptz not null default now(),
    project_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists tasks_user_updated_idx on public.tasks (user_id, updated_at);
drop trigger if exists tasks_last_write_wins on public.tasks;
create trigger tasks_last_write_wins before insert or update on public.tasks
    for each row execute function public.sync_last_write_wins();
alter table public.tasks enable row level security;
drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own" on public.tasks for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own" on public.tasks for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own" on public.tasks for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own" on public.tasks for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.tasks from anon;
grant select, insert, update, delete on public.tasks to authenticated;

-- goal
create table if not exists public.goals (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    title text not null default '',
    target_amount numeric not null default 0,
    currency_code text not null default 'EUR',
    deadline timestamptz,
    symbol_name text not null default 'target',
    color_name text not null default 'green',
    source text not null default 'manual',
    manual_amount numeric not null default 0,
    start_date timestamptz not null default now(),
    is_archived boolean not null default false,
    created_at timestamptz not null default now(),
    account_id text,
    category_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists goals_user_updated_idx on public.goals (user_id, updated_at);
drop trigger if exists goals_last_write_wins on public.goals;
create trigger goals_last_write_wins before insert or update on public.goals
    for each row execute function public.sync_last_write_wins();
alter table public.goals enable row level security;
drop policy if exists "goals_select_own" on public.goals;
create policy "goals_select_own" on public.goals for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "goals_insert_own" on public.goals;
create policy "goals_insert_own" on public.goals for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "goals_update_own" on public.goals;
create policy "goals_update_own" on public.goals for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "goals_delete_own" on public.goals;
create policy "goals_delete_own" on public.goals for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.goals from anon;
grant select, insert, update, delete on public.goals to authenticated;

-- note
create table if not exists public.notes (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    title text not null default '',
    icon text not null default '📄',
    created_at timestamptz not null default now(),
    edited_at timestamptz not null default now(),
    sort_order bigint not null default 0,
    parent_id text,
    linked_project_ids text[] not null default '{}'::text[],
    linked_transaction_ids text[] not null default '{}'::text[],
    linked_note_ids text[] not null default '{}'::text[],
    is_favorite boolean not null default false,
    cover text not null default '',
    is_template boolean not null default false,
    is_database boolean not null default false,
    database_schema text not null default '',
    database_view text not null default 'table',
    property_values text not null default '',
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists notes_user_updated_idx on public.notes (user_id, updated_at);
drop trigger if exists notes_last_write_wins on public.notes;
create trigger notes_last_write_wins before insert or update on public.notes
    for each row execute function public.sync_last_write_wins();
alter table public.notes enable row level security;
drop policy if exists "notes_select_own" on public.notes;
create policy "notes_select_own" on public.notes for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "notes_insert_own" on public.notes;
create policy "notes_insert_own" on public.notes for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "notes_update_own" on public.notes;
create policy "notes_update_own" on public.notes for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "notes_delete_own" on public.notes;
create policy "notes_delete_own" on public.notes for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.notes from anon;
grant select, insert, update, delete on public.notes to authenticated;

-- noteBlock
create table if not exists public.note_blocks (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    kind text not null default 'text',
    text text not null default '',
    is_checked boolean not null default false,
    image_data text,
    sort_order bigint not null default 0,
    created_at timestamptz not null default now(),
    note_id text,
    emoji text not null default '💡',
    language text not null default '',
    detail text not null default '',
    is_expanded boolean not null default false,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists note_blocks_user_updated_idx on public.note_blocks (user_id, updated_at);
drop trigger if exists note_blocks_last_write_wins on public.note_blocks;
create trigger note_blocks_last_write_wins before insert or update on public.note_blocks
    for each row execute function public.sync_last_write_wins();
alter table public.note_blocks enable row level security;
drop policy if exists "note_blocks_select_own" on public.note_blocks;
create policy "note_blocks_select_own" on public.note_blocks for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "note_blocks_insert_own" on public.note_blocks;
create policy "note_blocks_insert_own" on public.note_blocks for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "note_blocks_update_own" on public.note_blocks;
create policy "note_blocks_update_own" on public.note_blocks for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "note_blocks_delete_own" on public.note_blocks;
create policy "note_blocks_delete_own" on public.note_blocks for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.note_blocks from anon;
grant select, insert, update, delete on public.note_blocks to authenticated;

-- vehicle
create table if not exists public.vehicles (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    name text not null default '',
    plate text not null default '',
    fuel_type text not null default 'gasoline95',
    initial_odometer bigint not null default 0,
    notes text not null default '',
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists vehicles_user_updated_idx on public.vehicles (user_id, updated_at);
drop trigger if exists vehicles_last_write_wins on public.vehicles;
create trigger vehicles_last_write_wins before insert or update on public.vehicles
    for each row execute function public.sync_last_write_wins();
alter table public.vehicles enable row level security;
drop policy if exists "vehicles_select_own" on public.vehicles;
create policy "vehicles_select_own" on public.vehicles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "vehicles_insert_own" on public.vehicles;
create policy "vehicles_insert_own" on public.vehicles for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "vehicles_update_own" on public.vehicles;
create policy "vehicles_update_own" on public.vehicles for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "vehicles_delete_own" on public.vehicles;
create policy "vehicles_delete_own" on public.vehicles for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.vehicles from anon;
grant select, insert, update, delete on public.vehicles to authenticated;

-- fuelEntry
create table if not exists public.fuel_entries (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    date timestamptz not null default now(),
    odometer bigint not null default 0,
    quantity double precision not null default 0,
    total_cost numeric not null default 0,
    currency_code text not null default 'EUR',
    is_full_tank boolean not null default true,
    station text not null default '',
    notes text not null default '',
    transaction_id text not null default '',
    created_at timestamptz not null default now(),
    vehicle_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists fuel_entries_user_updated_idx on public.fuel_entries (user_id, updated_at);
drop trigger if exists fuel_entries_last_write_wins on public.fuel_entries;
create trigger fuel_entries_last_write_wins before insert or update on public.fuel_entries
    for each row execute function public.sync_last_write_wins();
alter table public.fuel_entries enable row level security;
drop policy if exists "fuel_entries_select_own" on public.fuel_entries;
create policy "fuel_entries_select_own" on public.fuel_entries for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "fuel_entries_insert_own" on public.fuel_entries;
create policy "fuel_entries_insert_own" on public.fuel_entries for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "fuel_entries_update_own" on public.fuel_entries;
create policy "fuel_entries_update_own" on public.fuel_entries for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "fuel_entries_delete_own" on public.fuel_entries;
create policy "fuel_entries_delete_own" on public.fuel_entries for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.fuel_entries from anon;
grant select, insert, update, delete on public.fuel_entries to authenticated;

-- maintenance
create table if not exists public.maintenance_records (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    kind text not null default 'service',
    title text not null default '',
    date timestamptz not null default now(),
    odometer bigint not null default 0,
    cost numeric not null default 0,
    currency_code text not null default 'EUR',
    workshop text not null default '',
    notes text not null default '',
    next_due_date timestamptz,
    next_due_odometer bigint not null default 0,
    transaction_id text not null default '',
    created_at timestamptz not null default now(),
    vehicle_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists maintenance_records_user_updated_idx on public.maintenance_records (user_id, updated_at);
drop trigger if exists maintenance_records_last_write_wins on public.maintenance_records;
create trigger maintenance_records_last_write_wins before insert or update on public.maintenance_records
    for each row execute function public.sync_last_write_wins();
alter table public.maintenance_records enable row level security;
drop policy if exists "maintenance_records_select_own" on public.maintenance_records;
create policy "maintenance_records_select_own" on public.maintenance_records for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "maintenance_records_insert_own" on public.maintenance_records;
create policy "maintenance_records_insert_own" on public.maintenance_records for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "maintenance_records_update_own" on public.maintenance_records;
create policy "maintenance_records_update_own" on public.maintenance_records for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "maintenance_records_delete_own" on public.maintenance_records;
create policy "maintenance_records_delete_own" on public.maintenance_records for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.maintenance_records from anon;
grant select, insert, update, delete on public.maintenance_records to authenticated;

-- carDeadline
create table if not exists public.car_deadlines (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    kind text not null default 'inspection',
    title text not null default '',
    due_date timestamptz not null default now(),
    amount numeric not null default 0,
    currency_code text not null default 'EUR',
    renewal_months bigint not null default 12,
    notes text not null default '',
    last_done_at timestamptz,
    created_at timestamptz not null default now(),
    vehicle_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists car_deadlines_user_updated_idx on public.car_deadlines (user_id, updated_at);
drop trigger if exists car_deadlines_last_write_wins on public.car_deadlines;
create trigger car_deadlines_last_write_wins before insert or update on public.car_deadlines
    for each row execute function public.sync_last_write_wins();
alter table public.car_deadlines enable row level security;
drop policy if exists "car_deadlines_select_own" on public.car_deadlines;
create policy "car_deadlines_select_own" on public.car_deadlines for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "car_deadlines_insert_own" on public.car_deadlines;
create policy "car_deadlines_insert_own" on public.car_deadlines for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "car_deadlines_update_own" on public.car_deadlines;
create policy "car_deadlines_update_own" on public.car_deadlines for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "car_deadlines_delete_own" on public.car_deadlines;
create policy "car_deadlines_delete_own" on public.car_deadlines for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.car_deadlines from anon;
grant select, insert, update, delete on public.car_deadlines to authenticated;

-- document
create table if not exists public.documents (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    title text not null default '',
    kind text not null default 'idCard',
    number text not null default '',
    issuer text not null default '',
    expiry_date timestamptz,
    remind_days_before bigint not null default 60,
    notes text not null default '',
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists documents_user_updated_idx on public.documents (user_id, updated_at);
drop trigger if exists documents_last_write_wins on public.documents;
create trigger documents_last_write_wins before insert or update on public.documents
    for each row execute function public.sync_last_write_wins();
alter table public.documents enable row level security;
drop policy if exists "documents_select_own" on public.documents;
create policy "documents_select_own" on public.documents for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "documents_insert_own" on public.documents;
create policy "documents_insert_own" on public.documents for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "documents_update_own" on public.documents;
create policy "documents_update_own" on public.documents for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "documents_delete_own" on public.documents;
create policy "documents_delete_own" on public.documents for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.documents from anon;
grant select, insert, update, delete on public.documents to authenticated;

-- jobApplication
create table if not exists public.job_applications (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    company text not null default '',
    role text not null default '',
    applied_at timestamptz not null default now(),
    status text not null default 'applied',
    status_changed_at timestamptz not null default now(),
    follow_up_date timestamptz,
    location text not null default '',
    link text not null default '',
    salary text not null default '',
    contact text not null default '',
    notes text not null default '',
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists job_applications_user_updated_idx on public.job_applications (user_id, updated_at);
drop trigger if exists job_applications_last_write_wins on public.job_applications;
create trigger job_applications_last_write_wins before insert or update on public.job_applications
    for each row execute function public.sync_last_write_wins();
alter table public.job_applications enable row level security;
drop policy if exists "job_applications_select_own" on public.job_applications;
create policy "job_applications_select_own" on public.job_applications for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "job_applications_insert_own" on public.job_applications;
create policy "job_applications_insert_own" on public.job_applications for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "job_applications_update_own" on public.job_applications;
create policy "job_applications_update_own" on public.job_applications for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "job_applications_delete_own" on public.job_applications;
create policy "job_applications_delete_own" on public.job_applications for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.job_applications from anon;
grant select, insert, update, delete on public.job_applications to authenticated;

-- course
create table if not exists public.courses (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    title text not null default '',
    provider text not null default '',
    status text not null default 'planned',
    progress double precision not null default 0,
    completed_at timestamptz,
    link text not null default '',
    credential_id text not null default '',
    expires_at timestamptz,
    notes text not null default '',
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists courses_user_updated_idx on public.courses (user_id, updated_at);
drop trigger if exists courses_last_write_wins on public.courses;
create trigger courses_last_write_wins before insert or update on public.courses
    for each row execute function public.sync_last_write_wins();
alter table public.courses enable row level security;
drop policy if exists "courses_select_own" on public.courses;
create policy "courses_select_own" on public.courses for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "courses_insert_own" on public.courses;
create policy "courses_insert_own" on public.courses for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "courses_update_own" on public.courses;
create policy "courses_update_own" on public.courses for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "courses_delete_own" on public.courses;
create policy "courses_delete_own" on public.courses for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.courses from anon;
grant select, insert, update, delete on public.courses to authenticated;

-- investment
create table if not exists public.investments (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    name text not null default '',
    ticker text not null default '',
    kind text not null default 'etf',
    currency_code text not null default 'EUR',
    units double precision not null default 0,
    invested_amount numeric not null default 0,
    unit_price numeric not null default 0,
    price_updated_at timestamptz,
    manual_value numeric not null default 0,
    is_archived boolean not null default false,
    notes text not null default '',
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists investments_user_updated_idx on public.investments (user_id, updated_at);
drop trigger if exists investments_last_write_wins on public.investments;
create trigger investments_last_write_wins before insert or update on public.investments
    for each row execute function public.sync_last_write_wins();
alter table public.investments enable row level security;
drop policy if exists "investments_select_own" on public.investments;
create policy "investments_select_own" on public.investments for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "investments_insert_own" on public.investments;
create policy "investments_insert_own" on public.investments for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "investments_update_own" on public.investments;
create policy "investments_update_own" on public.investments for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "investments_delete_own" on public.investments;
create policy "investments_delete_own" on public.investments for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.investments from anon;
grant select, insert, update, delete on public.investments to authenticated;

-- wealthSnapshot
create table if not exists public.wealth_snapshots (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null,
    day timestamptz not null default now(),
    cash numeric not null default 0,
    invested numeric not null default 0,
    investments_value numeric not null default 0,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists wealth_snapshots_user_updated_idx on public.wealth_snapshots (user_id, updated_at);
drop trigger if exists wealth_snapshots_last_write_wins on public.wealth_snapshots;
create trigger wealth_snapshots_last_write_wins before insert or update on public.wealth_snapshots
    for each row execute function public.sync_last_write_wins();
alter table public.wealth_snapshots enable row level security;
drop policy if exists "wealth_snapshots_select_own" on public.wealth_snapshots;
create policy "wealth_snapshots_select_own" on public.wealth_snapshots for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "wealth_snapshots_insert_own" on public.wealth_snapshots;
create policy "wealth_snapshots_insert_own" on public.wealth_snapshots for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "wealth_snapshots_update_own" on public.wealth_snapshots;
create policy "wealth_snapshots_update_own" on public.wealth_snapshots for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "wealth_snapshots_delete_own" on public.wealth_snapshots;
create policy "wealth_snapshots_delete_own" on public.wealth_snapshots for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.wealth_snapshots from anon;
grant select, insert, update, delete on public.wealth_snapshots to authenticated;

-- habit
create table if not exists public.habits (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    name text not null default '',
    symbol_name text not null default 'checkmark.circle',
    color_name text not null default 'green',
    target_per_week bigint not null default 7,
    sort_order bigint not null default 0,
    is_archived boolean not null default false,
    created_at timestamptz not null default now(),
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists habits_user_updated_idx on public.habits (user_id, updated_at);
drop trigger if exists habits_last_write_wins on public.habits;
create trigger habits_last_write_wins before insert or update on public.habits
    for each row execute function public.sync_last_write_wins();
alter table public.habits enable row level security;
drop policy if exists "habits_select_own" on public.habits;
create policy "habits_select_own" on public.habits for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "habits_insert_own" on public.habits;
create policy "habits_insert_own" on public.habits for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "habits_update_own" on public.habits;
create policy "habits_update_own" on public.habits for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "habits_delete_own" on public.habits;
create policy "habits_delete_own" on public.habits for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.habits from anon;
grant select, insert, update, delete on public.habits to authenticated;

-- habitCheck
create table if not exists public.habit_checks (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null default upper(gen_random_uuid()::text),
    day timestamptz not null default now(),
    created_at timestamptz not null default now(),
    habit_id text,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists habit_checks_user_updated_idx on public.habit_checks (user_id, updated_at);
drop trigger if exists habit_checks_last_write_wins on public.habit_checks;
create trigger habit_checks_last_write_wins before insert or update on public.habit_checks
    for each row execute function public.sync_last_write_wins();
alter table public.habit_checks enable row level security;
drop policy if exists "habit_checks_select_own" on public.habit_checks;
create policy "habit_checks_select_own" on public.habit_checks for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "habit_checks_insert_own" on public.habit_checks;
create policy "habit_checks_insert_own" on public.habit_checks for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "habit_checks_update_own" on public.habit_checks;
create policy "habit_checks_update_own" on public.habit_checks for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "habit_checks_delete_own" on public.habit_checks;
create policy "habit_checks_delete_own" on public.habit_checks for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.habit_checks from anon;
grant select, insert, update, delete on public.habit_checks to authenticated;

-- setting
create table if not exists public.user_settings (
    user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
    id          text        not null,
    value jsonb,
    deleted     boolean     not null default false,
    modified_at timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    primary key (user_id, id)
);
create index if not exists user_settings_user_updated_idx on public.user_settings (user_id, updated_at);
drop trigger if exists user_settings_last_write_wins on public.user_settings;
create trigger user_settings_last_write_wins before insert or update on public.user_settings
    for each row execute function public.sync_last_write_wins();
alter table public.user_settings enable row level security;
drop policy if exists "user_settings_select_own" on public.user_settings;
create policy "user_settings_select_own" on public.user_settings for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "user_settings_insert_own" on public.user_settings;
create policy "user_settings_insert_own" on public.user_settings for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "user_settings_update_own" on public.user_settings;
create policy "user_settings_update_own" on public.user_settings for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "user_settings_delete_own" on public.user_settings;
create policy "user_settings_delete_own" on public.user_settings for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.user_settings from anon;
grant select, insert, update, delete on public.user_settings to authenticated;

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
    ('category', 'categories', 'uid'),
    ('account', 'accounts', 'uid'),
    ('transaction', 'transactions', 'uid'),
    ('bill', 'bills', 'uid'),
    ('storeProduct', 'store_products', 'shopifyID'),
    ('storeOrder', 'store_orders', 'shopifyID'),
    ('storeCheckout', 'store_checkouts', 'shopifyID'),
    ('dailyStat', 'daily_stats', null),
    ('project', 'projects', 'uid'),
    ('task', 'tasks', 'uid'),
    ('goal', 'goals', 'uid'),
    ('note', 'notes', 'uid'),
    ('noteBlock', 'note_blocks', 'uid'),
    ('vehicle', 'vehicles', 'uid'),
    ('fuelEntry', 'fuel_entries', 'uid'),
    ('maintenance', 'maintenance_records', 'uid'),
    ('carDeadline', 'car_deadlines', 'uid'),
    ('document', 'documents', 'uid'),
    ('jobApplication', 'job_applications', 'uid'),
    ('course', 'courses', 'uid'),
    ('investment', 'investments', 'uid'),
    ('wealthSnapshot', 'wealth_snapshots', null),
    ('habit', 'habits', 'uid'),
    ('habitCheck', 'habit_checks', 'uid'),
    ('setting', 'user_settings', 'key');
insert into public.sync_fields (entity, ord, json_key, column_name, type, optional) values
    ('category', 0, 'uid', 'id', 'text', false),
    ('category', 1, 'name', 'name', 'text', false),
    ('category', 2, 'symbolName', 'symbol_name', 'text', false),
    ('category', 3, 'colorName', 'color_name', 'text', false),
    ('category', 4, 'kindRaw', 'kind', 'text', false),
    ('category', 5, 'sortOrder', 'sort_order', 'int', false),
    ('category', 6, 'monthlyBudget', 'monthly_budget', 'numeric', false),
    ('account', 0, 'uid', 'id', 'text', false),
    ('account', 1, 'name', 'name', 'text', false),
    ('account', 2, 'typeRaw', 'type', 'text', false),
    ('account', 3, 'currencyCode', 'currency_code', 'text', false),
    ('account', 4, 'initialBalance', 'initial_balance', 'numeric', false),
    ('account', 5, 'isArchived', 'is_archived', 'bool', false),
    ('account', 6, 'createdAt', 'created_at', 'date', false),
    ('transaction', 0, 'uid', 'id', 'text', false),
    ('transaction', 1, 'title', 'title', 'text', false),
    ('transaction', 2, 'amount', 'amount', 'numeric', false),
    ('transaction', 3, 'kindRaw', 'kind', 'text', false),
    ('transaction', 4, 'currencyCode', 'currency_code', 'text', false),
    ('transaction', 5, 'date', 'date', 'date', false),
    ('transaction', 6, 'notes', 'notes', 'text', false),
    ('transaction', 7, 'createdAt', 'created_at', 'date', false),
    ('transaction', 8, 'externalID', 'external_id', 'text', false),
    ('transaction', 9, 'categoryUID', 'category_id', 'text', true),
    ('transaction', 10, 'accountUID', 'account_id', 'text', true),
    ('bill', 0, 'uid', 'id', 'text', false),
    ('bill', 1, 'title', 'title', 'text', false),
    ('bill', 2, 'amount', 'amount', 'numeric', false),
    ('bill', 3, 'currencyCode', 'currency_code', 'text', false),
    ('bill', 4, 'dueDate', 'due_date', 'date', false),
    ('bill', 5, 'isPaid', 'is_paid', 'bool', false),
    ('bill', 6, 'paidAt', 'paid_at', 'date', true),
    ('bill', 7, 'recurrenceRaw', 'recurrence', 'text', false),
    ('bill', 8, 'notes', 'notes', 'text', false),
    ('bill', 9, 'isSubscription', 'is_subscription', 'bool', false),
    ('bill', 10, 'createdAt', 'created_at', 'date', false),
    ('bill', 11, 'categoryUID', 'category_id', 'text', true),
    ('bill', 12, 'accountUID', 'account_id', 'text', true),
    ('storeProduct', 0, 'shopifyID', 'id', 'text', false),
    ('storeProduct', 1, 'title', 'title', 'text', false),
    ('storeProduct', 2, 'handle', 'handle', 'text', false),
    ('storeProduct', 3, 'statusRaw', 'status', 'text', false),
    ('storeProduct', 4, 'imageURLString', 'image_url', 'text', false),
    ('storeProduct', 5, 'price', 'price', 'numeric', false),
    ('storeProduct', 6, 'unitCost', 'unit_cost', 'numeric', false),
    ('storeProduct', 7, 'unitCostIsManual', 'unit_cost_is_manual', 'bool', false),
    ('storeProduct', 8, 'inventory', 'inventory', 'int', false),
    ('storeProduct', 9, 'tracksInventory', 'tracks_inventory', 'bool', false),
    ('storeProduct', 10, 'createdAt', 'created_at', 'date', false),
    ('storeProduct', 11, 'adSpend30d', 'ad_spend_30d', 'numeric', false),
    ('storeProduct', 12, 'decisionRaw', 'decision', 'text', false),
    ('storeProduct', 13, 'decidedAt', 'decided_at', 'date', true),
    ('storeProduct', 14, 'decisionNote', 'decision_note', 'text', false),
    ('storeProduct', 15, 'syncedAt', 'synced_at', 'date', false),
    ('storeOrder', 0, 'shopifyID', 'id', 'text', false),
    ('storeOrder', 1, 'name', 'name', 'text', false),
    ('storeOrder', 2, 'createdAt', 'created_at', 'date', false),
    ('storeOrder', 3, 'cancelledAt', 'cancelled_at', 'date', true),
    ('storeOrder', 4, 'subtotal', 'subtotal', 'numeric', false),
    ('storeOrder', 5, 'shipping', 'shipping', 'numeric', false),
    ('storeOrder', 6, 'tax', 'tax', 'numeric', false),
    ('storeOrder', 7, 'total', 'total', 'numeric', false),
    ('storeOrder', 8, 'refunded', 'refunded', 'numeric', false),
    ('storeOrder', 9, 'currencyCode', 'currency_code', 'text', false),
    ('storeOrder', 10, 'financialStatusRaw', 'financial_status', 'text', false),
    ('storeOrder', 11, 'fulfillmentStatusRaw', 'fulfillment_status', 'text', false),
    ('storeOrder', 12, 'lines', 'lines', 'jsonb', false),
    ('storeOrder', 13, 'syncedAt', 'synced_at', 'date', false),
    ('storeCheckout', 0, 'shopifyID', 'id', 'text', false),
    ('storeCheckout', 1, 'name', 'name', 'text', false),
    ('storeCheckout', 2, 'createdAt', 'created_at', 'date', false),
    ('storeCheckout', 3, 'total', 'total', 'numeric', false),
    ('storeCheckout', 4, 'recoveryURLString', 'recovery_url', 'text', false),
    ('storeCheckout', 5, 'lines', 'lines', 'jsonb', false),
    ('storeCheckout', 6, 'syncedAt', 'synced_at', 'date', false),
    ('dailyStat', 0, 'date', 'date', 'date', false),
    ('dailyStat', 1, 'sales', 'sales', 'numeric', false),
    ('dailyStat', 2, 'netRevenue', 'net_revenue', 'numeric', false),
    ('dailyStat', 3, 'orders', 'orders', 'int', false),
    ('dailyStat', 4, 'units', 'units', 'int', false),
    ('dailyStat', 5, 'refunds', 'refunds', 'numeric', false),
    ('dailyStat', 6, 'sessions', 'sessions', 'int', false),
    ('dailyStat', 7, 'cartSessions', 'cart_sessions', 'int', false),
    ('dailyStat', 8, 'checkoutSessions', 'checkout_sessions', 'int', false),
    ('dailyStat', 9, 'completedSessions', 'completed_sessions', 'int', false),
    ('dailyStat', 10, 'hasTraffic', 'has_traffic', 'bool', false),
    ('project', 0, 'uid', 'id', 'text', false),
    ('project', 1, 'name', 'name', 'text', false),
    ('project', 2, 'details', 'details', 'text', false),
    ('project', 3, 'symbolName', 'symbol_name', 'text', false),
    ('project', 4, 'colorName', 'color_name', 'text', false),
    ('project', 5, 'statusRaw', 'status', 'text', false),
    ('project', 6, 'dueDate', 'due_date', 'date', true),
    ('project', 7, 'createdAt', 'created_at', 'date', false),
    ('task', 0, 'uid', 'id', 'text', false),
    ('task', 1, 'title', 'title', 'text', false),
    ('task', 2, 'notes', 'notes', 'text', false),
    ('task', 3, 'statusRaw', 'status', 'text', false),
    ('task', 4, 'priorityRaw', 'priority', 'int', false),
    ('task', 5, 'dueDate', 'due_date', 'date', true),
    ('task', 6, 'completedAt', 'completed_at', 'date', true),
    ('task', 7, 'createdAt', 'created_at', 'date', false),
    ('task', 8, 'projectUID', 'project_id', 'text', true),
    ('goal', 0, 'uid', 'id', 'text', false),
    ('goal', 1, 'title', 'title', 'text', false),
    ('goal', 2, 'targetAmount', 'target_amount', 'numeric', false),
    ('goal', 3, 'currencyCode', 'currency_code', 'text', false),
    ('goal', 4, 'deadline', 'deadline', 'date', true),
    ('goal', 5, 'symbolName', 'symbol_name', 'text', false),
    ('goal', 6, 'colorName', 'color_name', 'text', false),
    ('goal', 7, 'sourceRaw', 'source', 'text', false),
    ('goal', 8, 'manualAmount', 'manual_amount', 'numeric', false),
    ('goal', 9, 'startDate', 'start_date', 'date', false),
    ('goal', 10, 'isArchived', 'is_archived', 'bool', false),
    ('goal', 11, 'createdAt', 'created_at', 'date', false),
    ('goal', 12, 'accountUID', 'account_id', 'text', true),
    ('goal', 13, 'categoryUID', 'category_id', 'text', true),
    ('note', 0, 'uid', 'id', 'text', false),
    ('note', 1, 'title', 'title', 'text', false),
    ('note', 2, 'icon', 'icon', 'text', false),
    ('note', 3, 'createdAt', 'created_at', 'date', false),
    ('note', 4, 'updatedAt', 'edited_at', 'date', false),
    ('note', 5, 'sortOrder', 'sort_order', 'int', false),
    ('note', 6, 'parentUID', 'parent_id', 'text', true),
    ('note', 7, 'linkedProjectUIDs', 'linked_project_ids', 'text[]', false),
    ('note', 8, 'linkedTransactionUIDs', 'linked_transaction_ids', 'text[]', false),
    ('note', 9, 'linkedNoteUIDs', 'linked_note_ids', 'text[]', false),
    ('note', 10, 'isFavorite', 'is_favorite', 'bool', false),
    ('note', 11, 'coverRaw', 'cover', 'text', false),
    ('note', 12, 'isTemplate', 'is_template', 'bool', false),
    ('note', 13, 'isDatabase', 'is_database', 'bool', false),
    ('note', 14, 'databaseSchemaJSON', 'database_schema', 'text', false),
    ('note', 15, 'databaseViewRaw', 'database_view', 'text', false),
    ('note', 16, 'propertyValuesJSON', 'property_values', 'text', false),
    ('noteBlock', 0, 'uid', 'id', 'text', false),
    ('noteBlock', 1, 'kindRaw', 'kind', 'text', false),
    ('noteBlock', 2, 'text', 'text', 'text', false),
    ('noteBlock', 3, 'isChecked', 'is_checked', 'bool', false),
    ('noteBlock', 4, 'imageData', 'image_data', 'base64', true),
    ('noteBlock', 5, 'sortOrder', 'sort_order', 'int', false),
    ('noteBlock', 6, 'createdAt', 'created_at', 'date', false),
    ('noteBlock', 7, 'noteUID', 'note_id', 'text', true),
    ('noteBlock', 8, 'emoji', 'emoji', 'text', false),
    ('noteBlock', 9, 'language', 'language', 'text', false),
    ('noteBlock', 10, 'detail', 'detail', 'text', false),
    ('noteBlock', 11, 'isExpanded', 'is_expanded', 'bool', false),
    ('vehicle', 0, 'uid', 'id', 'text', false),
    ('vehicle', 1, 'name', 'name', 'text', false),
    ('vehicle', 2, 'plate', 'plate', 'text', false),
    ('vehicle', 3, 'fuelTypeRaw', 'fuel_type', 'text', false),
    ('vehicle', 4, 'initialOdometer', 'initial_odometer', 'int', false),
    ('vehicle', 5, 'notes', 'notes', 'text', false),
    ('vehicle', 6, 'createdAt', 'created_at', 'date', false),
    ('fuelEntry', 0, 'uid', 'id', 'text', false),
    ('fuelEntry', 1, 'date', 'date', 'date', false),
    ('fuelEntry', 2, 'odometer', 'odometer', 'int', false),
    ('fuelEntry', 3, 'quantity', 'quantity', 'double', false),
    ('fuelEntry', 4, 'totalCost', 'total_cost', 'numeric', false),
    ('fuelEntry', 5, 'currencyCode', 'currency_code', 'text', false),
    ('fuelEntry', 6, 'isFullTank', 'is_full_tank', 'bool', false),
    ('fuelEntry', 7, 'station', 'station', 'text', false),
    ('fuelEntry', 8, 'notes', 'notes', 'text', false),
    ('fuelEntry', 9, 'transactionID', 'transaction_id', 'text', false),
    ('fuelEntry', 10, 'createdAt', 'created_at', 'date', false),
    ('fuelEntry', 11, 'vehicleUID', 'vehicle_id', 'text', true),
    ('maintenance', 0, 'uid', 'id', 'text', false),
    ('maintenance', 1, 'kindRaw', 'kind', 'text', false),
    ('maintenance', 2, 'title', 'title', 'text', false),
    ('maintenance', 3, 'date', 'date', 'date', false),
    ('maintenance', 4, 'odometer', 'odometer', 'int', false),
    ('maintenance', 5, 'cost', 'cost', 'numeric', false),
    ('maintenance', 6, 'currencyCode', 'currency_code', 'text', false),
    ('maintenance', 7, 'workshop', 'workshop', 'text', false),
    ('maintenance', 8, 'notes', 'notes', 'text', false),
    ('maintenance', 9, 'nextDueDate', 'next_due_date', 'date', true),
    ('maintenance', 10, 'nextDueOdometer', 'next_due_odometer', 'int', false),
    ('maintenance', 11, 'transactionID', 'transaction_id', 'text', false),
    ('maintenance', 12, 'createdAt', 'created_at', 'date', false),
    ('maintenance', 13, 'vehicleUID', 'vehicle_id', 'text', true),
    ('carDeadline', 0, 'uid', 'id', 'text', false),
    ('carDeadline', 1, 'kindRaw', 'kind', 'text', false),
    ('carDeadline', 2, 'title', 'title', 'text', false),
    ('carDeadline', 3, 'dueDate', 'due_date', 'date', false),
    ('carDeadline', 4, 'amount', 'amount', 'numeric', false),
    ('carDeadline', 5, 'currencyCode', 'currency_code', 'text', false),
    ('carDeadline', 6, 'renewalMonths', 'renewal_months', 'int', false),
    ('carDeadline', 7, 'notes', 'notes', 'text', false),
    ('carDeadline', 8, 'lastDoneAt', 'last_done_at', 'date', true),
    ('carDeadline', 9, 'createdAt', 'created_at', 'date', false),
    ('carDeadline', 10, 'vehicleUID', 'vehicle_id', 'text', true),
    ('document', 0, 'uid', 'id', 'text', false),
    ('document', 1, 'title', 'title', 'text', false),
    ('document', 2, 'kindRaw', 'kind', 'text', false),
    ('document', 3, 'number', 'number', 'text', false),
    ('document', 4, 'issuer', 'issuer', 'text', false),
    ('document', 5, 'expiryDate', 'expiry_date', 'date', true),
    ('document', 6, 'remindDaysBefore', 'remind_days_before', 'int', false),
    ('document', 7, 'notes', 'notes', 'text', false),
    ('document', 8, 'createdAt', 'created_at', 'date', false),
    ('jobApplication', 0, 'uid', 'id', 'text', false),
    ('jobApplication', 1, 'company', 'company', 'text', false),
    ('jobApplication', 2, 'role', 'role', 'text', false),
    ('jobApplication', 3, 'appliedAt', 'applied_at', 'date', false),
    ('jobApplication', 4, 'statusRaw', 'status', 'text', false),
    ('jobApplication', 5, 'statusChangedAt', 'status_changed_at', 'date', false),
    ('jobApplication', 6, 'followUpDate', 'follow_up_date', 'date', true),
    ('jobApplication', 7, 'location', 'location', 'text', false),
    ('jobApplication', 8, 'link', 'link', 'text', false),
    ('jobApplication', 9, 'salary', 'salary', 'text', false),
    ('jobApplication', 10, 'contact', 'contact', 'text', false),
    ('jobApplication', 11, 'notes', 'notes', 'text', false),
    ('jobApplication', 12, 'createdAt', 'created_at', 'date', false),
    ('course', 0, 'uid', 'id', 'text', false),
    ('course', 1, 'title', 'title', 'text', false),
    ('course', 2, 'provider', 'provider', 'text', false),
    ('course', 3, 'statusRaw', 'status', 'text', false),
    ('course', 4, 'progress', 'progress', 'double', false),
    ('course', 5, 'completedAt', 'completed_at', 'date', true),
    ('course', 6, 'link', 'link', 'text', false),
    ('course', 7, 'credentialID', 'credential_id', 'text', false),
    ('course', 8, 'expiresAt', 'expires_at', 'date', true),
    ('course', 9, 'notes', 'notes', 'text', false),
    ('course', 10, 'createdAt', 'created_at', 'date', false),
    ('investment', 0, 'uid', 'id', 'text', false),
    ('investment', 1, 'name', 'name', 'text', false),
    ('investment', 2, 'ticker', 'ticker', 'text', false),
    ('investment', 3, 'kindRaw', 'kind', 'text', false),
    ('investment', 4, 'currencyCode', 'currency_code', 'text', false),
    ('investment', 5, 'units', 'units', 'double', false),
    ('investment', 6, 'investedAmount', 'invested_amount', 'numeric', false),
    ('investment', 7, 'unitPrice', 'unit_price', 'numeric', false),
    ('investment', 8, 'priceUpdatedAt', 'price_updated_at', 'date', true),
    ('investment', 9, 'manualValue', 'manual_value', 'numeric', false),
    ('investment', 10, 'isArchived', 'is_archived', 'bool', false),
    ('investment', 11, 'notes', 'notes', 'text', false),
    ('investment', 12, 'createdAt', 'created_at', 'date', false),
    ('wealthSnapshot', 0, 'day', 'day', 'date', false),
    ('wealthSnapshot', 1, 'cash', 'cash', 'numeric', false),
    ('wealthSnapshot', 2, 'invested', 'invested', 'numeric', false),
    ('wealthSnapshot', 3, 'investmentsValue', 'investments_value', 'numeric', false),
    ('habit', 0, 'uid', 'id', 'text', false),
    ('habit', 1, 'name', 'name', 'text', false),
    ('habit', 2, 'symbolName', 'symbol_name', 'text', false),
    ('habit', 3, 'colorName', 'color_name', 'text', false),
    ('habit', 4, 'targetPerWeek', 'target_per_week', 'int', false),
    ('habit', 5, 'sortOrder', 'sort_order', 'int', false),
    ('habit', 6, 'isArchived', 'is_archived', 'bool', false),
    ('habit', 7, 'createdAt', 'created_at', 'date', false),
    ('habitCheck', 0, 'uid', 'id', 'text', false),
    ('habitCheck', 1, 'day', 'day', 'date', false),
    ('habitCheck', 2, 'createdAt', 'created_at', 'date', false),
    ('habitCheck', 3, 'habitUID', 'habit_id', 'text', true),
    ('setting', 0, 'key', 'id', 'text', false),
    ('setting', 1, 'value', 'value', 'jsonb', true);
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
