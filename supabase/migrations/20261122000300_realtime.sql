-- Mynik — Realtime nas tabelas tipadas (Fase 11)
--
-- A app desktop subscreve as alterações (postgres_changes) para mostrar logo o
-- que muda no iPhone. Só existe no Supabase: noutro Postgres não faz nada.
do $$
declare
    t text;
begin
    if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        return;
    end if;
    foreach t in array array[
            'categories', 'accounts', 'transactions', 'bills', 'store_products', 'store_orders', 'store_checkouts', 'daily_stats', 'projects', 'tasks', 'goals', 'notes', 'note_blocks', 'vehicles', 'fuel_entries', 'maintenance_records', 'car_deadlines', 'documents', 'job_applications', 'courses', 'investments', 'wealth_snapshots', 'habits', 'habit_checks', 'user_settings'
        ] loop
        if not exists (
            select 1 from pg_publication_tables
            where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
        ) then
            execute format('alter publication supabase_realtime add table public.%I', t);
        end if;
    end loop;
end;
$$;
