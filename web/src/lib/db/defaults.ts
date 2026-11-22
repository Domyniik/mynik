import { type Db, newID, now } from "./client";

/** As mesmas categorias e conta que o iPhone cria (DefaultDataSeeder). */
const categories: [string, string, string, "expense" | "income"][] = [
  ["Alimentação", "cart", "orange", "expense"], ["Casa", "house", "brown", "expense"],
  ["Transporte", "tram", "blue", "expense"], ["Carro", "car", "indigo", "expense"],
  ["Saúde", "cross.case", "red", "expense"], ["Lazer", "gamecontroller", "purple", "expense"],
  ["Compras", "bag", "pink", "expense"], ["Assinaturas", "repeat", "teal", "expense"],
  ["Outros", "ellipsis.circle", "gray", "expense"], ["Salário", "briefcase", "green", "income"],
  ["Loja", "storefront", "mint", "income"], ["Outras receitas", "plus.circle", "gray", "income"],
];

/**
 * Só numa conta sem nenhum registo (nem apagado): se o iPhone já sincronizou,
 * as categorias dele chegam por aí e não se duplicam.
 */
let running: Promise<void> | null = null;

export function seedDefaultsIfEmpty(db: Db) {
  running ??= seed(db).finally(() => { running = null; });
  return running;
}

async function seed(db: Db) {
  const any = await db.rpc("sync_pull", { p_since: null, p_limit: 1, p_offset: 0 });
  if (any.length > 0) return;
  for (const [index, [name, symbol, color, kind]] of categories.entries()) {
    await db.insert("categories", { id: newID(), name, symbol_name: symbol, color_name: color, kind, sort_order: index, modified_at: now() });
  }
  await db.insert("accounts", { id: newID(), name: "Conta principal", type: "checking", currency_code: "EUR", initial_balance: 0, is_archived: false, created_at: now(), modified_at: now() });
}
