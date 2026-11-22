#!/usr/bin/env node
// Gera src/lib/db/schema.ts a partir de supabase/schema/entities.mjs
// (a mesma fonte das tabelas SQL e do sync do iPhone).
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { columnName, entities } from "../../supabase/schema/entities.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const output = join(here, "..", "src", "lib", "db", "schema.ts");

const tsType = {
  text: "string",
  int: "number",
  double: "number",
  numeric: "number",
  bool: "boolean",
  date: "string",
  jsonb: "unknown",
  "text[]": "string[]",
  base64: "string",
};
const pascal = (name) => name[0].toUpperCase() + name.slice(1);

const interfaces = entities.map((e) => {
  const cols = e.fields
    .filter((f) => columnName(f) !== "id")
    .map((f) => `  ${columnName(f)}: ${tsType[f.type]}${f.optional ? " | null" : ""};`);
  return `/** Tabela \`${e.table}\` (registo \`${e.entity}\` do iPhone). */
export interface ${pascal(e.entity)}Row extends SyncColumns {
${cols.join("\n")}
}`;
});

const tableMap = entities.map((e) => `  ${e.table}: ${pascal(e.entity)}Row;`).join("\n");
const columnTypes = entities
  .map((e) => `  ${e.table}: { ${e.fields.filter((f) => columnName(f) !== "id").map((f) => `${columnName(f)}: "${f.type}"`).join(", ")} },`)
  .join("\n");

const source = `// GERADO por web/scripts/generate-types.mjs a partir de supabase/schema/entities.mjs.
// Não editar à mão: \`npm run types\`.

/** Colunas comuns a todas as tabelas (sync e RLS). */
export interface SyncColumns {
  user_id: string;
  id: string;
  deleted: boolean;
  modified_at: string;
  updated_at: string;
}

${interfaces.join("\n\n")}

export interface Tables {
${tableMap}
}

export type TableName = keyof Tables;

/** Tipo de cada coluna (para converter valores e preencher formulários). */
export const columnTypes = {
${columnTypes}
} as const satisfies Record<TableName, Record<string, string>>;

export const tableNames = Object.keys(columnTypes) as TableName[];
`;

writeFileSync(output, source);
console.log(`Gerado ${output}`);
