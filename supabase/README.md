# Supabase — base de dados do Mynik

Plano grátis do Supabase: Postgres, login por magic link e Row Level Security.
O iPhone (Swift) e o desktop (Tauri + Next.js) leem e escrevem os mesmos dados.

```
supabase/
  schema/entities.mjs   modelo de dados (fonte única: tabelas, colunas, sync)
  schema/generate.mjs   gera migrations/20261122000000_typed_tables.sql
  migrations/           SQL a aplicar, por ordem
  tests/                testes do SQL em Postgres local (PGlite)
```

## Migrações

| Ficheiro | O que faz |
|---|---|
| `20261121000000_records.sql` | Fase 9: tabela genérica `records` (já aplicada) |
| `20261122000000_typed_tables.sql` | 25 tabelas tipadas com RLS, last-write-wins e as funções `sync_push` / `sync_pull` do iPhone |
| `20261122000100_calculations.sql` | Funções de cálculo: `store_product_scores`, `store_profit`, `store_kpis`, `budget_overview`, `month_summary` |
| `20261122000200_migrate_records.sql` | Copia os dados de `records` para as tabelas tipadas (pode correr-se várias vezes) |

### Aplicar no projeto existente (SQL Editor)

1. Abre o projeto **mynik** em [supabase.com/dashboard](https://supabase.com/dashboard) → **SQL Editor** → **New query**.
2. Cola o conteúdo de `20261122000000_typed_tables.sql` e carrega em **Run**. Repete com `20261122000100_calculations.sql` e depois `20261122000200_migrate_records.sql`, por esta ordem.
3. Corre a verificação abaixo.

### Verificar a migração

Cada tipo deve ter o mesmo número de linhas nas duas colunas:

```sql
select e.entity,
       (select count(*) from public.records r where r.entity = e.entity) as em_records,
       (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from public.%I', e.table_name), false, true, '')))[1]::text::int as na_tabela
from public.sync_entities e
order by e.entity;
```

A tabela `records` só se apaga depois de o iPhone e o desktop estarem a usar as tabelas novas (uma migração própria, mais tarde).

## Testes

```bash
cd supabase && npm install && npm test
```

- `tests/sync.test.mjs`: tabelas, RLS, last-write-wins, `sync_push` / `sync_pull` e migração.
- `tests/parity.test.mjs`: as funções de cálculo com os dados de `MynikTests/Fixtures/parity-fixture.json` têm de dar `parity-expected.json`, que o iPhone também confere em `MynikTests/ParityTests.swift`.

Depois de mudar `schema/entities.mjs`: `npm run generate` (uma alteração a uma migração já aplicada vai numa migração nova).
