-- Mynik — migração dos dados de `records` para as tabelas tipadas (Fase 11)
--
-- Copia cada linha da tabela genérica (Fase 9) para a tabela do seu tipo,
-- utilizador a utilizador, mantendo o modified_at original (last-write-wins).
-- Pode correr-se mais do que uma vez sem duplicar nada.
-- A tabela `records` NÃO é apagada: fica como cópia até confirmares que está
-- tudo certo (supabase/README.md, "Verificar a migração").
do $$
declare
    v_user uuid;
begin
    if to_regclass('public.records') is null then
        return;
    end if;
    for v_user in select distinct r.user_id from public.records r loop
        perform public.sync_apply(v_user, (
            select jsonb_agg(jsonb_build_object(
                'entity', r.entity,
                'key', r.key,
                'payload', r.payload,
                'deleted', r.deleted,
                'modified_at', r.modified_at
            ) order by r.modified_at)
            from public.records r
            where r.user_id = v_user
        ));
    end loop;
end;
$$;
