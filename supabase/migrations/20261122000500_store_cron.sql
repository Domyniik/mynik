-- Mynik — sync agendado da loja (Fase 11)
--
-- De 30 em 30 minutos o pg_cron chama a Edge Function mynik-api (pg_net) com o
-- cabeçalho x-cron-secret; a função lê a Shopify e escreve a cache nas tabelas
-- do dono da loja, mesmo com o iPhone e o desktop fechados.
--
-- O endereço e o segredo ficam no Vault (nunca no git). Antes de aplicar:
--   select vault.create_secret('https://<projeto>.supabase.co/functions/v1/mynik-api', 'mynik_api_url');
--   select vault.create_secret('<o mesmo valor do segredo CRON_SECRET da função>', 'mynik_cron_secret');
-- Para parar: select cron.unschedule('mynik-store-sync');
--
-- Só existe no Supabase: num Postgres sem pg_cron (testes em PGlite) não faz nada.
do $$
begin
    if not exists (select 1 from pg_available_extensions where name = 'pg_cron')
       or not exists (select 1 from pg_available_extensions where name = 'pg_net') then
        return;
    end if;
    create extension if not exists pg_cron;
    create extension if not exists pg_net;
    perform cron.schedule(
        'mynik-store-sync',
        '*/30 * * * *',
        $job$
        select net.http_post(
            url := (select decrypted_secret from vault.decrypted_secrets where name = 'mynik_api_url'),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'mynik_cron_secret')
            ),
            body := '{"action": "cron-sync"}'::jsonb,
            timeout_milliseconds := 60000
        )
        where exists (select 1 from vault.decrypted_secrets where name = 'mynik_api_url');
        $job$
    );
end;
$$;
