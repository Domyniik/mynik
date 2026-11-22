-- Mynik — vendas e lucro de cada dia (gráfico da loja), com o mesmo cálculo
-- de store_profit (StoreMetrics.dailyPoints no iPhone).
create or replace function public.store_daily_points(p_days integer default 30, p_now timestamptz default now(), p_tz text default 'Europe/Madrid')
returns table (day date, sales numeric, profit numeric, orders bigint)
language sql
stable
security invoker
set search_path = ''
as $$
    select d::date, pr.gross_sales, pr.profit, pr.orders
    from generate_series((p_now at time zone p_tz)::date - (p_days - 1), (p_now at time zone p_tz)::date, interval '1 day') d
    cross join lateral public.store_profit(
        public.local_midnight(d::date, p_tz), public.local_midnight(d::date + 1, p_tz), 1
    ) pr
    order by 1
$$;

revoke all on function public.store_daily_points(integer, timestamptz, text) from public, anon;
grant execute on function public.store_daily_points(integer, timestamptz, text) to authenticated;
