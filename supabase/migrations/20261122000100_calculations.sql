-- Mynik — cálculos no servidor (Fase 11)
--
-- As contas importantes ficam aqui para que o iPhone e o desktop deem o mesmo
-- número. São a tradução fiel do código Swift (referência: docs/FEATURES.md §4):
--   store_product_scores  ← ProductPerformance + ProductScorer
--   store_profit / store_kpis ← StoreMetrics + StoreCostSettings
--   budget_overview / month_summary ← BudgetOverview + MonthSummary + CurrencyConverter
-- A paridade é testada com os mesmos dados nos dois lados:
-- MynikTests/Fixtures/parity-*.json (supabase/tests/parity.test.mjs e MynikTests/ParityTests.swift).
--
-- Todas correm com os direitos de quem chama (RLS) e leem só as linhas do utilizador.
-- Os dias contam-se no fuso p_tz (por omissão Europe/Madrid, como o iPhone).

-- Definição numérica do utilizador (user_settings), ou o valor por omissão.
create or replace function public.mynik_setting(p_key text, p_default numeric)
returns numeric
language sql
stable
security invoker
set search_path = ''
as $$
    select coalesce((
        select (s.value #>> '{}')::numeric
        from public.user_settings s
        where s.user_id = auth.uid() and s.id = p_key and not s.deleted
          and jsonb_typeof(s.value) = 'number'
    ), p_default)
$$;

create or replace function public.mynik_clamp(x double precision)
returns double precision
language sql
immutable
set search_path = ''
as $$ select least(1::double precision, greatest(0::double precision, x)) $$;

-- Valor em EUR (CurrencyConverter): BRL a dividir pela taxa "BRL por 1 EUR".
create or replace function public.to_eur(p_amount numeric, p_currency text, p_brl_per_eur numeric)
returns numeric
language sql
immutable
set search_path = ''
as $$
    select case when p_currency = 'BRL'
        then p_amount / (case when p_brl_per_eur > 0 then p_brl_per_eur else 6.0 end)
        else p_amount end
$$;

-- Meia-noite local de um dia, como timestamptz.
create or replace function public.local_midnight(p_day date, p_tz text)
returns timestamptz
language sql
immutable
set search_path = ''
as $$ select p_day::timestamp at time zone p_tz $$;

-- ============================================================
-- Loja: lucro real de um intervalo [p_from, p_to) com p_days dias de anúncios.
-- ============================================================
create or replace function public.store_profit(p_from timestamptz, p_to timestamptz, p_days integer)
returns table (
    orders bigint, units bigint,
    gross_sales numeric, vat numeric, net_revenue numeric,
    product_costs numeric, shipping_costs numeric, payment_fees numeric, ad_spend numeric,
    profit numeric, margin double precision
)
language sql
stable
security invoker
set search_path = ''
as $$
    with s as (
        select public.mynik_setting('storeFeePercent', 2.1) as fee_pct,
               public.mynik_setting('storeFeeFixed', 0.25) as fee_fixed,
               public.mynik_setting('storeShippingCost', 4) as ship,
               public.mynik_setting('storeMonthlyAds', 0) + public.mynik_setting('googleAdsUnattributed30d', 0) as monthly_ads
    ),
    products as (
        select p.id, p.unit_cost, p.ad_spend_30d
        from public.store_products p
        where p.user_id = auth.uid() and not p.deleted
    ),
    o as (
        select o.total, o.tax,
            (select coalesce(sum((l ->> 'currentQuantity')::bigint), 0) from jsonb_array_elements(o.lines) l) as unit_count,
            (select coalesce(sum(coalesce((select p.unit_cost from products p where p.id = l ->> 'productID' limit 1), 0)
                                 * (l ->> 'currentQuantity')::bigint), 0)
             from jsonb_array_elements(o.lines) l) as line_cost
        from public.store_orders o
        where o.user_id = auth.uid() and not o.deleted and o.cancelled_at is null
          and o.created_at >= p_from and o.created_at < p_to
    ),
    b as (
        select count(*) as orders,
               coalesce(sum(o.unit_count), 0)::bigint as units,
               coalesce(sum(o.total), 0) as gross,
               coalesce(sum(o.tax), 0) as vat,
               coalesce(sum(o.line_cost), 0) as product_costs,
               coalesce(sum(case when o.unit_count > 0 then s.ship else 0 end), 0) as shipping,
               coalesce(sum(case when o.total > 0 then o.total * s.fee_pct / 100 + s.fee_fixed else 0 end), 0) as fees
        from o cross join s
    ),
    ads as (
        select ((select coalesce(sum(p.ad_spend_30d), 0) from products p) + s.monthly_ads) / 30 * p_days as ad
        from s
    )
    select b.orders, b.units, b.gross, b.vat, b.gross - b.vat,
           b.product_costs, b.shipping, b.fees, ads.ad,
           b.gross - b.vat - b.product_costs - b.shipping - b.fees - ads.ad,
           case when b.gross - b.vat > 0
                then ((b.gross - b.vat - b.product_costs - b.shipping - b.fees - ads.ad) / (b.gross - b.vat))::double precision
           end
    from b cross join ads
$$;

-- KPIs de um período de p_days dias a acabar hoje e do período anterior igual.
create or replace function public.store_kpis(p_days integer, p_now timestamptz default now(), p_tz text default 'Europe/Madrid')
returns table (
    period text, starts_at timestamptz, ends_at timestamptz,
    orders bigint, units bigint,
    gross_sales numeric, vat numeric, net_revenue numeric,
    product_costs numeric, shipping_costs numeric, payment_fees numeric, ad_spend numeric,
    profit numeric, margin double precision,
    average_order_value numeric,
    sessions bigint, completed_sessions bigint, has_traffic boolean, conversion_rate double precision
)
language sql
stable
security invoker
set search_path = ''
as $$
    with today as (select (p_now at time zone p_tz)::date as d),
    periods as (
        select 'current' as period,
               public.local_midnight(t.d - (p_days - 1), p_tz) as s,
               public.local_midnight(t.d + 1, p_tz) as e
        from today t
        union all
        select 'previous',
               public.local_midnight(t.d - (p_days - 1) - p_days, p_tz),
               public.local_midnight(t.d - (p_days - 1), p_tz)
        from today t
    )
    select pe.period, pe.s, pe.e,
           pr.orders, pr.units, pr.gross_sales, pr.vat, pr.net_revenue,
           pr.product_costs, pr.shipping_costs, pr.payment_fees, pr.ad_spend, pr.profit, pr.margin,
           case when pr.orders > 0 then pr.gross_sales / pr.orders end,
           st.sessions, st.completed, st.has_traffic,
           case when st.has_traffic and st.sessions > 0 then st.completed::double precision / st.sessions end
    from periods pe
    cross join lateral public.store_profit(pe.s, pe.e, p_days) pr
    cross join lateral (
        select coalesce(sum(d.sessions), 0)::bigint as sessions,
               coalesce(sum(d.completed_sessions), 0)::bigint as completed,
               coalesce(bool_or(d.has_traffic), false) as has_traffic
        from public.daily_stats d
        where d.user_id = auth.uid() and not d.deleted and d.date >= pe.s and d.date < pe.e
    ) st
    order by pe.period
$$;

-- ============================================================
-- Loja: ranking de produtos (score 0–100, classificação e ação sugerida).
-- ============================================================
create or replace function public.store_product_scores(p_now timestamptz default now(), p_tz text default 'Europe/Madrid')
returns table (
    product_id text, title text, price numeric, unit_cost numeric,
    age_days integer, units bigint, ordered_units bigint, refunded_units bigint, revenue numeric,
    days_since_last_sale integer, ad_spend numeric, inventory bigint, tracks_inventory boolean,
    abandoned_units bigint, margin_rate double precision, refund_rate double precision,
    roas double precision, checkout_conversion double precision, days_of_stock integer,
    score integer, classification text, action text, factors jsonb
)
language sql
stable
security invoker
set search_path = ''
as $$
    with win as (
        select (p_now at time zone p_tz)::date as today,
               public.local_midnight((p_now at time zone p_tz)::date - 29, p_tz) as window_start
    ),
    prod as (
        select * from public.store_products p
        where p.user_id = auth.uid() and not p.deleted and p.status = 'ACTIVE'
    ),
    lines as (
        select o.created_at, l ->> 'productID' as pid,
               (l ->> 'quantity')::bigint as q, (l ->> 'currentQuantity')::bigint as cq,
               (l ->> 'unitPrice')::numeric as up
        from public.store_orders o cross join jsonb_array_elements(o.lines) l
        where o.user_id = auth.uid() and not o.deleted and o.cancelled_at is null
    ),
    last_sale as (
        select pid, max(created_at) as last from lines where cq > 0 group by pid
    ),
    recent as (
        select l.pid, sum(l.cq) as units, sum(l.q) as ordered, sum(greatest(0, l.q - l.cq)) as refunded,
               sum(l.up * l.cq) as revenue
        from lines l cross join win w where l.created_at >= w.window_start group by l.pid
    ),
    checkouts as (
        select exists (select 1 from public.store_checkouts c where c.user_id = auth.uid() and not c.deleted) as has_any
    ),
    abandoned as (
        select l ->> 'productID' as pid, sum((l ->> 'quantity')::bigint) as units
        from public.store_checkouts c cross join jsonb_array_elements(c.lines) l cross join win w
        where c.user_id = auth.uid() and not c.deleted and c.created_at >= w.window_start
          and coalesce(l ->> 'productID', '') <> ''
        group by 1
    ),
    perf as (
        select p.id, p.title, p.price, p.unit_cost, p.inventory, p.tracks_inventory, p.ad_spend_30d as ad_spend,
               greatest(0, w.today - (p.created_at at time zone p_tz)::date) as age_days,
               coalesce(r.units, 0) as units, coalesce(r.ordered, 0) as ordered, coalesce(r.refunded, 0) as refunded,
               coalesce(r.revenue, 0) as revenue,
               w.today - (ls.last at time zone p_tz)::date as days_since,
               case when ch.has_any then coalesce(a.units, 0) end as abandoned
        from prod p
        cross join win w
        cross join checkouts ch
        left join recent r on r.pid = p.id
        left join last_sale ls on ls.pid = p.id
        left join abandoned a on a.pid = p.id
    ),
    metrics as (
        select pf.*,
               case when pf.price > 0 then ((pf.price - pf.unit_cost) / pf.price)::double precision end as margin_rate,
               case when pf.ordered > 0 then pf.refunded::double precision / pf.ordered else 0 end as refund_rate,
               case when pf.ad_spend > 0 then (pf.revenue / pf.ad_spend)::double precision end as roas,
               case when pf.abandoned is not null and pf.ordered + pf.abandoned >= 5
                    then pf.ordered::double precision / (pf.ordered + pf.abandoned) end as conversion,
               case when pf.tracks_inventory and pf.units > 0
                    then floor(greatest(0, pf.inventory)::double precision / (pf.units::double precision / 30))::integer end as days_of_stock,
               max(pf.units) over () as best_units,
               sum(pf.revenue) over () as total_revenue
        from perf pf
    ),
    factored as (
        select m.*,
            20 * public.mynik_clamp(case when m.best_units > 0 then m.units::double precision / m.best_units else 0 end) as f_sales,
            15 * public.mynik_clamp((case when m.total_revenue > 0 then (m.revenue / m.total_revenue)::double precision else 0 end) / 0.25) as f_revenue,
            case when m.margin_rate is not null and m.unit_cost > 0
                 then 20 * public.mynik_clamp((m.margin_rate - 0.2) / 0.5) else 20 * 0.6::double precision end as f_margin,
            m.margin_rate is not null and m.unit_cost > 0 as has_margin,
            case when m.conversion is not null
                 then 10 * public.mynik_clamp((m.conversion - 0.3) / 0.5) else 10 * 0.6::double precision end as f_funnel,
            10 * (1 - public.mynik_clamp(m.refund_rate / 0.2)) as f_refunds,
            case when m.days_since is null then 0::double precision
                 else 15 * (1 - public.mynik_clamp((m.days_since - 3)::double precision / 27)) end as f_recency,
            case when m.roas is not null
                 then 10 * public.mynik_clamp((m.roas - 1) / 3) else 10 * 0.7::double precision end as f_roas
        from metrics m
    ),
    scored as (
        select f.*,
            round((f.f_sales + f.f_revenue + f.f_margin + f.f_funnel + f.f_refunds + f.f_recency + f.f_roas)::numeric)::integer as score
        from factored f
    ),
    classified as (
        select s.*,
            case
                when s.age_days < 14 then 'testing'
                when s.ordered < 3 and s.age_days < 30 then 'testing'
                when s.score >= 70 then 'winner'
                when s.score >= 45 then 'promising'
                else 'loser'
            end as class,
            (select k.kind from (values
                (1, 'sales', s.f_sales / 20, true),
                (2, 'revenue', s.f_revenue / 15, true),
                (3, 'margin', s.f_margin / 20, s.has_margin),
                (4, 'funnel', s.f_funnel / 10, s.conversion is not null),
                (5, 'refunds', s.f_refunds / 10, true),
                (6, 'recency', s.f_recency / 15, true),
                (7, 'roas', s.f_roas / 10, s.roas is not null)
             ) k(ord, kind, ratio, has_data)
             where k.has_data order by k.ratio, k.ord limit 1) as weakest
        from scored s
    )
    select c.id, c.title, c.price, c.unit_cost, c.age_days::integer, c.units, c.ordered, c.refunded, c.revenue,
           c.days_since::integer, c.ad_spend, c.inventory, c.tracks_inventory, c.abandoned,
           c.margin_rate, c.refund_rate, c.roas, c.conversion, c.days_of_stock,
           c.score, c.class,
           case c.class
               when 'winner' then
                   case when c.days_of_stock is not null and c.days_of_stock < 14
                            then 'Repor stock: ao ritmo atual só dá para ' || c.days_of_stock || ' dias.'
                        when c.roas is not null and c.roas >= 3 then 'Escalar: aumentar o orçamento de anúncios.'
                        else 'Escalar: testar anúncios e novos criativos.' end
               when 'promising' then
                   case c.weakest
                       when 'margin' then 'Rever o preço ou o fornecedor para subir a margem.'
                       when 'funnel' then 'Melhorar a página do produto: fotos, descrição e avaliações.'
                       when 'refunds' then 'Perceber o motivo das devoluções (qualidade, tamanho, descrição).'
                       when 'roas' then 'Ajustar os anúncios: público ou criativo.'
                       when 'recency' then 'Reativar com uma promoção ou um e-mail.'
                       else 'Dar mais visibilidade: destaque na loja e anúncios.' end
               when 'testing' then
                   case when 14 - c.age_days > 0
                            then 'Manter o teste mais ' || (14 - c.age_days) || ' dias antes de decidir.'
                        else 'Juntar mais dados (vendas ou anúncios) antes de decidir.' end
               else
                   case when c.ad_spend > 0 then 'Pausar os anúncios e tirar de destaque.'
                        when coalesce(c.days_since, 2147483647) >= 30 then 'Arquivar ou escoar o stock com desconto.'
                        else 'Rever a oferta (preço, fotos) ou descontinuar.' end
           end,
           jsonb_build_array(
               jsonb_build_object('kind', 'sales', 'points', c.f_sales, 'max', 20, 'hasData', true),
               jsonb_build_object('kind', 'revenue', 'points', c.f_revenue, 'max', 15, 'hasData', true),
               jsonb_build_object('kind', 'margin', 'points', c.f_margin, 'max', 20, 'hasData', c.has_margin),
               jsonb_build_object('kind', 'funnel', 'points', c.f_funnel, 'max', 10, 'hasData', c.conversion is not null),
               jsonb_build_object('kind', 'refunds', 'points', c.f_refunds, 'max', 10, 'hasData', true),
               jsonb_build_object('kind', 'recency', 'points', c.f_recency, 'max', 15, 'hasData', true),
               jsonb_build_object('kind', 'roas', 'points', c.f_roas, 'max', 10, 'hasData', c.roas is not null)
           )
    from classified c
    order by c.score desc, c.title collate "C"
$$;

-- ============================================================
-- Finanças: orçamento por categoria e resumo do mês (em EUR).
-- ============================================================
create or replace function public.budget_overview(p_month date, p_tz text default 'Europe/Madrid')
returns table (
    category_id text, name text, symbol_name text, color_name text, sort_order bigint,
    budget numeric, spent numeric, remaining numeric, has_budget boolean, over_budget boolean,
    progress double precision
)
language sql
stable
security invoker
set search_path = ''
as $$
    with m as (
        select public.local_midnight(date_trunc('month', p_month)::date, p_tz) as s,
               public.local_midnight((date_trunc('month', p_month) + interval '1 month')::date, p_tz) as e,
               public.mynik_setting('brlPerEUR', 6.0) as rate
    ),
    spent as (
        select t.category_id, sum(public.to_eur(t.amount, t.currency_code, m.rate)) as total
        from public.transactions t cross join m
        where t.user_id = auth.uid() and not t.deleted and t.kind = 'expense'
          and t.category_id is not null and t.date >= m.s and t.date < m.e
        group by t.category_id
    )
    select c.id, c.name, c.symbol_name, c.color_name, c.sort_order,
           c.monthly_budget, coalesce(sp.total, 0), c.monthly_budget - coalesce(sp.total, 0),
           c.monthly_budget > 0,
           c.monthly_budget > 0 and coalesce(sp.total, 0) > c.monthly_budget,
           case when c.monthly_budget > 0 then (coalesce(sp.total, 0) / c.monthly_budget)::double precision else 0 end
    from public.categories c
    left join spent sp on sp.category_id = c.id
    where c.user_id = auth.uid() and not c.deleted and c.kind = 'expense'
    order by c.sort_order, c.name
$$;

create or replace function public.month_summary(p_month date, p_tz text default 'Europe/Madrid')
returns table (income numeric, expenses numeric, balance numeric)
language sql
stable
security invoker
set search_path = ''
as $$
    with m as (
        select public.local_midnight(date_trunc('month', p_month)::date, p_tz) as s,
               public.local_midnight((date_trunc('month', p_month) + interval '1 month')::date, p_tz) as e,
               public.mynik_setting('brlPerEUR', 6.0) as rate
    ),
    totals as (
        select coalesce(sum(case when t.kind = 'income' then public.to_eur(t.amount, t.currency_code, m.rate) end), 0) as income,
               coalesce(sum(case when t.kind = 'expense' then public.to_eur(t.amount, t.currency_code, m.rate) end), 0) as expenses
        from public.transactions t cross join m
        where t.user_id = auth.uid() and not t.deleted and t.date >= m.s and t.date < m.e
    )
    select income, expenses, income - expenses from totals
$$;

revoke all on function public.mynik_setting(text, numeric) from public, anon;
revoke all on function public.store_profit(timestamptz, timestamptz, integer) from public, anon;
revoke all on function public.store_kpis(integer, timestamptz, text) from public, anon;
revoke all on function public.store_product_scores(timestamptz, text) from public, anon;
revoke all on function public.budget_overview(date, text) from public, anon;
revoke all on function public.month_summary(date, text) from public, anon;
grant execute on function public.mynik_setting(text, numeric) to authenticated;
grant execute on function public.store_profit(timestamptz, timestamptz, integer) to authenticated;
grant execute on function public.store_kpis(integer, timestamptz, text) to authenticated;
grant execute on function public.store_product_scores(timestamptz, text) to authenticated;
grant execute on function public.budget_overview(date, text) to authenticated;
grant execute on function public.month_summary(date, text) to authenticated;
