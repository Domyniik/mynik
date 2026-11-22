#!/usr/bin/env node
// Prepara o modo de demonstração: copia as migrações do Supabase e os dados de
// exemplo (os do teste de paridade) para public/demo, servidos com a app.
// Corre sozinho antes de `npm run dev` e `npm run build`.
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const web = join(dirname(fileURLToPath(import.meta.url)), "..");
const root = join(web, "..");
const out = join(web, "public", "demo");
mkdirSync(out, { recursive: true });

const folder = join(root, "supabase", "migrations");
const migrations = readdirSync(folder)
  .filter((f) => f.endsWith(".sql"))
  .sort()
  .map((name) => readFileSync(join(folder, name), "utf8"));
writeFileSync(join(out, "migrations.json"), JSON.stringify(migrations));

const fixture = readFileSync(join(root, "MynikTests", "Fixtures", "parity-fixture.json"), "utf8");
writeFileSync(join(out, "fixture.json"), fixture);

console.log(`Demo: ${migrations.length} migrações e dados de exemplo em public/demo`);
