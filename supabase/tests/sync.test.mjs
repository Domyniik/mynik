import assert from "node:assert/strict";
import { test } from "node:test";
import { asUser, freshDatabase, iosDate, USER_A, USER_B } from "./helpers.mjs";

const push = (tx, rows) => tx.query("select public.sync_push($1::jsonb)", [JSON.stringify(rows)]);
const pull = async (tx, since = null) =>
  (await tx.query("select * from public.sync_pull($1)", [since])).rows;

const transaction = {
  uid: "TX-1",
  title: "Mercadona",
  amount: 12.3,
  kindRaw: "expense",
  currencyCode: "EUR",
  date: iosDate("2026-11-20T10:30:00.250Z"),
  notes: "",
  createdAt: iosDate("2026-11-20T10:31:00Z"),
  externalID: "",
  categoryUID: "CAT-1",
};

test("um registo do iPhone vai para a tabela certa e volta igual", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    await push(tx, [{ entity: "transaction", key: "TX-1", payload: transaction, deleted: false, modified_at: "2026-11-20T10:31:00Z" }]);
    const row = (await tx.query("select * from public.transactions")).rows[0];
    assert.equal(row.id, "TX-1");
    assert.equal(row.title, "Mercadona");
    assert.equal(row.amount, "12.3");
    assert.equal(row.category_id, "CAT-1");
    assert.equal(row.account_id, null);
    assert.equal(row.date.toISOString(), "2026-11-20T10:30:00.250Z");

    const [pulled] = await pull(tx);
    assert.equal(pulled.entity, "transaction");
    assert.equal(pulled.key, "TX-1");
    assert.equal(pulled.deleted, false);
    assert.deepEqual(pulled.payload, transaction);
  });
});

test("campos em falta ficam com o valor por omissão e opcionais nulos não voltam", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    // Nota antiga (antes do esquema V7): sem isFavorite, coverRaw…
    const note = { uid: "N-1", title: "Ideias", icon: "💡", createdAt: 0, updatedAt: 10, sortOrder: 0 };
    await push(tx, [{ entity: "note", key: "N-1", payload: note, deleted: false, modified_at: "2026-11-20T10:00:00Z" }]);
    const row = (await tx.query("select * from public.notes")).rows[0];
    assert.equal(row.is_favorite, false);
    assert.equal(row.database_view, "table");
    assert.deepEqual(row.linked_project_ids, []);
    const [pulled] = await pull(tx);
    assert.equal(pulled.payload.isFavorite, false);
    assert.deepEqual(pulled.payload.linkedNoteUIDs, []);
    assert.equal("parentUID" in pulled.payload, false);
  });
});

test("last-write-wins: uma escrita mais antiga é ignorada", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    await push(tx, [{ entity: "transaction", key: "TX-1", payload: transaction, deleted: false, modified_at: "2026-11-20T12:00:00Z" }]);
    await push(tx, [{ entity: "transaction", key: "TX-1", payload: { ...transaction, title: "Antigo" }, deleted: false, modified_at: "2026-11-20T11:00:00Z" }]);
    assert.equal((await tx.query("select title from public.transactions")).rows[0].title, "Mercadona");
    await push(tx, [{ entity: "transaction", key: "TX-1", payload: { ...transaction, title: "Novo" }, deleted: false, modified_at: "2026-11-20T13:00:00Z" }]);
    assert.equal((await tx.query("select title from public.transactions")).rows[0].title, "Novo");
  });
});

test("tombstone apaga e mantém os dados para o pull", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    await push(tx, [{ entity: "transaction", key: "TX-1", payload: transaction, deleted: false, modified_at: "2026-11-20T12:00:00Z" }]);
    await push(tx, [{ entity: "transaction", key: "TX-1", payload: null, deleted: true, modified_at: "2026-11-20T13:00:00Z" }]);
    const row = (await tx.query("select deleted, title from public.transactions")).rows[0];
    assert.equal(row.deleted, true);
    const [pulled] = await pull(tx);
    assert.equal(pulled.deleted, true);
    assert.equal(pulled.payload, null);
  });
});

test("RLS: cada utilizador só vê as suas linhas", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, (tx) =>
    push(tx, [{ entity: "transaction", key: "TX-1", payload: transaction, deleted: false, modified_at: "2026-11-20T12:00:00Z" }]),
  );
  await asUser(db, USER_B, async (tx) => {
    assert.equal((await pull(tx)).length, 0);
    assert.equal((await tx.query("select * from public.transactions")).rows.length, 0);
  });
  await assert.rejects(
    asUser(db, USER_B, (tx) =>
      tx.query(`insert into public.transactions (user_id, id, title) values ('${USER_A}', 'X', 'intruso')`),
    ),
    /row-level security/,
  );
});

test("a app web escreve direto na tabela e o iPhone recebe no pull", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    await tx.query(
      "insert into public.bills (title, amount, due_date, recurrence) values ('Internet', 35, '2026-12-01T00:00:00Z', 'monthly')",
    );
    const [pulled] = await pull(tx);
    assert.equal(pulled.entity, "bill");
    assert.match(pulled.key, /^[0-9A-F-]{36}$/);
    assert.equal(pulled.payload.uid, pulled.key);
    assert.equal(pulled.payload.recurrenceRaw, "monthly");
    assert.equal(pulled.payload.dueDate, iosDate("2026-12-01T00:00:00Z"));
    assert.equal(pulled.payload.amount, 35);
    // Uma edição na web sem modified_at conta como mais recente.
    const before = pulled.modified_at;
    await tx.query("update public.bills set title = 'Fibra'");
    const [edited] = await pull(tx);
    assert.ok(edited.modified_at > before);
  });
});

test("pull incremental: só o que mudou desde o cursor", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    await push(tx, [{ entity: "transaction", key: "TX-1", payload: transaction, deleted: false, modified_at: "2026-11-20T12:00:00Z" }]);
    const [first] = await pull(tx);
    await push(tx, [
      { entity: "category", key: "CAT-1", payload: { uid: "CAT-1", name: "Alimentação", symbolName: "cart", colorName: "green", kindRaw: "expense", sortOrder: 0, monthlyBudget: 250 }, deleted: false, modified_at: "2026-11-20T12:05:00Z" },
    ]);
    const since = new Date(first.updated_at.getTime() + 1);
    const rows = await pull(tx, since.toISOString());
    assert.deepEqual(rows.map((r) => r.key), ["CAT-1"]);
  });
});

test("tipos desconhecidos (versão mais recente da app) são ignorados", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    await push(tx, [{ entity: "futureThing", key: "X", payload: {}, deleted: false, modified_at: "2026-11-20T12:00:00Z" }]);
    assert.equal((await pull(tx)).length, 0);
  });
});

test("dados da loja e linhas em JSON mantêm os decimais", async () => {
  const db = await freshDatabase();
  await asUser(db, USER_A, async (tx) => {
    const order = {
      shopifyID: "gid://shopify/Order/1", name: "#1001", createdAt: iosDate("2026-11-20T09:00:00Z"),
      subtotal: 24.99, shipping: 3.9, tax: 5.4, total: 28.89, refunded: 0, currencyCode: "EUR",
      financialStatusRaw: "PAID", fulfillmentStatusRaw: "UNFULFILLED", syncedAt: iosDate("2026-11-20T09:05:00Z"),
      lines: [{ productID: "gid://shopify/Product/1", title: "Anel", quantity: 2, currentQuantity: 2, unitPrice: 12.495 }],
    };
    await push(tx, [{ entity: "storeOrder", key: order.shopifyID, payload: order, deleted: false, modified_at: "2026-11-20T09:05:00Z" }]);
    const [pulled] = await pull(tx);
    assert.deepEqual(pulled.payload, order);
  });
});
