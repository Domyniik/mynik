// Esquema dos dados do Mynik: uma tabela por tipo de registo.
//
// É a fonte única de verdade do modelo de dados partilhado entre o iPhone e o
// desktop. `node supabase/schema/generate.mjs` gera a partir daqui a migração
// das tabelas (com RLS, last-write-wins e os metadados do sync) e os tipos
// TypeScript da app web.
//
// Cada entidade corresponde a um registo da cópia de segurança do iOS
// (`BackupRecords.swift`): `json` é o nome do campo no registo, `column` o da
// coluna. As datas do iOS vêm em segundos desde 1/1/2001 e são convertidas
// para `timestamptz` pelas funções `sync_push` / `sync_pull`.
//
// Tipos: text, int, double, numeric, bool, date, jsonb, text[], base64 (Data em base64, guardado como texto).

/** @typedef {{ json: string, column?: string, type: string, optional?: boolean, default?: string }} Field */
/** @typedef {{ entity: string, table: string, keyField: string | null, fields: Field[] }} Entity */

const uid = { json: "uid", column: "id", type: "text", default: "upper(gen_random_uuid()::text)" };
const shopifyID = { json: "shopifyID", column: "id", type: "text" };
const createdAt = { json: "createdAt", type: "date" };
const currency = { json: "currencyCode", type: "text", default: "'EUR'" };
const notes = { json: "notes", type: "text" };

/** @type {Entity[]} */
export const entities = [
  {
    entity: "category", table: "categories", keyField: "uid", fields: [
      uid,
      { json: "name", type: "text" },
      { json: "symbolName", type: "text", default: "'tag'" },
      { json: "colorName", type: "text", default: "'gray'" },
      { json: "kindRaw", column: "kind", type: "text", default: "'expense'" },
      { json: "sortOrder", type: "int" },
      { json: "monthlyBudget", type: "numeric" },
    ],
  },
  {
    entity: "account", table: "accounts", keyField: "uid", fields: [
      uid,
      { json: "name", type: "text" },
      { json: "typeRaw", column: "type", type: "text", default: "'checking'" },
      currency,
      { json: "initialBalance", type: "numeric" },
      { json: "isArchived", type: "bool" },
      createdAt,
    ],
  },
  {
    entity: "transaction", table: "transactions", keyField: "uid", fields: [
      uid,
      { json: "title", type: "text" },
      { json: "amount", type: "numeric" },
      { json: "kindRaw", column: "kind", type: "text", default: "'expense'" },
      currency,
      { json: "date", type: "date" },
      notes,
      createdAt,
      { json: "externalID", column: "external_id", type: "text" },
      { json: "categoryUID", column: "category_id", type: "text", optional: true },
      { json: "accountUID", column: "account_id", type: "text", optional: true },
    ],
  },
  {
    entity: "bill", table: "bills", keyField: "uid", fields: [
      uid,
      { json: "title", type: "text" },
      { json: "amount", type: "numeric" },
      currency,
      { json: "dueDate", type: "date" },
      { json: "isPaid", type: "bool" },
      { json: "paidAt", type: "date", optional: true },
      { json: "recurrenceRaw", column: "recurrence", type: "text", default: "'none'" },
      notes,
      { json: "isSubscription", type: "bool" },
      createdAt,
      { json: "categoryUID", column: "category_id", type: "text", optional: true },
      { json: "accountUID", column: "account_id", type: "text", optional: true },
    ],
  },
  {
    entity: "storeProduct", table: "store_products", keyField: "shopifyID", fields: [
      shopifyID,
      { json: "title", type: "text" },
      { json: "handle", type: "text" },
      { json: "statusRaw", column: "status", type: "text", default: "'ACTIVE'" },
      { json: "imageURLString", column: "image_url", type: "text" },
      { json: "price", type: "numeric" },
      { json: "unitCost", type: "numeric" },
      { json: "unitCostIsManual", type: "bool" },
      { json: "inventory", type: "int" },
      { json: "tracksInventory", type: "bool", default: "true" },
      createdAt,
      { json: "adSpend30d", column: "ad_spend_30d", type: "numeric" },
      { json: "decisionRaw", column: "decision", type: "text" },
      { json: "decidedAt", type: "date", optional: true },
      { json: "decisionNote", type: "text" },
      { json: "syncedAt", type: "date" },
    ],
  },
  {
    entity: "storeOrder", table: "store_orders", keyField: "shopifyID", fields: [
      shopifyID,
      { json: "name", type: "text" },
      createdAt,
      { json: "cancelledAt", type: "date", optional: true },
      { json: "subtotal", type: "numeric" },
      { json: "shipping", type: "numeric" },
      { json: "tax", type: "numeric" },
      { json: "total", type: "numeric" },
      { json: "refunded", type: "numeric" },
      currency,
      { json: "financialStatusRaw", column: "financial_status", type: "text" },
      { json: "fulfillmentStatusRaw", column: "fulfillment_status", type: "text" },
      // [{productID, title, quantity, currentQuantity, unitPrice}]
      { json: "lines", type: "jsonb", default: "'[]'::jsonb" },
      { json: "syncedAt", type: "date" },
    ],
  },
  {
    entity: "storeCheckout", table: "store_checkouts", keyField: "shopifyID", fields: [
      shopifyID,
      { json: "name", type: "text" },
      createdAt,
      { json: "total", type: "numeric" },
      { json: "recoveryURLString", column: "recovery_url", type: "text" },
      // [{productID, title, quantity}]
      { json: "lines", type: "jsonb", default: "'[]'::jsonb" },
      { json: "syncedAt", type: "date" },
    ],
  },
  {
    // Chave: o início do dia em segundos desde 1970 ("1763679600.0").
    entity: "dailyStat", table: "daily_stats", keyField: null, fields: [
      { json: "date", type: "date" },
      { json: "sales", type: "numeric" },
      { json: "netRevenue", type: "numeric" },
      { json: "orders", type: "int" },
      { json: "units", type: "int" },
      { json: "refunds", type: "numeric" },
      { json: "sessions", type: "int" },
      { json: "cartSessions", type: "int" },
      { json: "checkoutSessions", type: "int" },
      { json: "completedSessions", type: "int" },
      { json: "hasTraffic", type: "bool" },
    ],
  },
  {
    entity: "project", table: "projects", keyField: "uid", fields: [
      uid,
      { json: "name", type: "text" },
      { json: "details", type: "text" },
      { json: "symbolName", type: "text", default: "'folder'" },
      { json: "colorName", type: "text", default: "'blue'" },
      { json: "statusRaw", column: "status", type: "text", default: "'active'" },
      { json: "dueDate", type: "date", optional: true },
      createdAt,
    ],
  },
  {
    entity: "task", table: "tasks", keyField: "uid", fields: [
      uid,
      { json: "title", type: "text" },
      notes,
      { json: "statusRaw", column: "status", type: "text", default: "'todo'" },
      { json: "priorityRaw", column: "priority", type: "int", default: "1" },
      { json: "dueDate", type: "date", optional: true },
      { json: "completedAt", type: "date", optional: true },
      createdAt,
      { json: "projectUID", column: "project_id", type: "text", optional: true },
    ],
  },
  {
    entity: "goal", table: "goals", keyField: "uid", fields: [
      uid,
      { json: "title", type: "text" },
      { json: "targetAmount", type: "numeric" },
      currency,
      { json: "deadline", type: "date", optional: true },
      { json: "symbolName", type: "text", default: "'target'" },
      { json: "colorName", type: "text", default: "'green'" },
      { json: "sourceRaw", column: "source", type: "text", default: "'manual'" },
      { json: "manualAmount", type: "numeric" },
      { json: "startDate", type: "date" },
      { json: "isArchived", type: "bool" },
      createdAt,
      { json: "accountUID", column: "account_id", type: "text", optional: true },
      { json: "categoryUID", column: "category_id", type: "text", optional: true },
    ],
  },
  {
    entity: "note", table: "notes", keyField: "uid", fields: [
      uid,
      { json: "title", type: "text" },
      { json: "icon", type: "text", default: "'📄'" },
      createdAt,
      { json: "updatedAt", column: "edited_at", type: "date" },
      { json: "sortOrder", type: "int" },
      { json: "parentUID", column: "parent_id", type: "text", optional: true },
      { json: "linkedProjectUIDs", column: "linked_project_ids", type: "text[]" },
      { json: "linkedTransactionUIDs", column: "linked_transaction_ids", type: "text[]" },
      { json: "linkedNoteUIDs", column: "linked_note_ids", type: "text[]" },
      { json: "isFavorite", type: "bool" },
      { json: "coverRaw", column: "cover", type: "text" },
      { json: "isTemplate", type: "bool" },
      { json: "isDatabase", type: "bool" },
      { json: "databaseSchemaJSON", column: "database_schema", type: "text" },
      { json: "databaseViewRaw", column: "database_view", type: "text", default: "'table'" },
      { json: "propertyValuesJSON", column: "property_values", type: "text" },
    ],
  },
  {
    entity: "noteBlock", table: "note_blocks", keyField: "uid", fields: [
      uid,
      { json: "kindRaw", column: "kind", type: "text", default: "'text'" },
      { json: "text", type: "text" },
      { json: "isChecked", type: "bool" },
      { json: "imageData", column: "image_data", type: "base64", optional: true },
      { json: "sortOrder", type: "int" },
      createdAt,
      { json: "noteUID", column: "note_id", type: "text", optional: true },
      { json: "emoji", type: "text", default: "'💡'" },
      { json: "language", type: "text" },
      { json: "detail", type: "text" },
      { json: "isExpanded", type: "bool" },
    ],
  },
  {
    entity: "vehicle", table: "vehicles", keyField: "uid", fields: [
      uid,
      { json: "name", type: "text" },
      { json: "plate", type: "text" },
      { json: "fuelTypeRaw", column: "fuel_type", type: "text", default: "'gasoline95'" },
      { json: "initialOdometer", type: "int" },
      notes,
      createdAt,
    ],
  },
  {
    entity: "fuelEntry", table: "fuel_entries", keyField: "uid", fields: [
      uid,
      { json: "date", type: "date" },
      { json: "odometer", type: "int" },
      { json: "quantity", type: "double" },
      { json: "totalCost", type: "numeric" },
      currency,
      { json: "isFullTank", type: "bool", default: "true" },
      { json: "station", type: "text" },
      notes,
      { json: "transactionID", column: "transaction_id", type: "text" },
      createdAt,
      { json: "vehicleUID", column: "vehicle_id", type: "text", optional: true },
    ],
  },
  {
    entity: "maintenance", table: "maintenance_records", keyField: "uid", fields: [
      uid,
      { json: "kindRaw", column: "kind", type: "text", default: "'service'" },
      { json: "title", type: "text" },
      { json: "date", type: "date" },
      { json: "odometer", type: "int" },
      { json: "cost", type: "numeric" },
      currency,
      { json: "workshop", type: "text" },
      notes,
      { json: "nextDueDate", type: "date", optional: true },
      { json: "nextDueOdometer", type: "int" },
      { json: "transactionID", column: "transaction_id", type: "text" },
      createdAt,
      { json: "vehicleUID", column: "vehicle_id", type: "text", optional: true },
    ],
  },
  {
    entity: "carDeadline", table: "car_deadlines", keyField: "uid", fields: [
      uid,
      { json: "kindRaw", column: "kind", type: "text", default: "'inspection'" },
      { json: "title", type: "text" },
      { json: "dueDate", type: "date" },
      { json: "amount", type: "numeric" },
      currency,
      { json: "renewalMonths", type: "int", default: "12" },
      notes,
      { json: "lastDoneAt", type: "date", optional: true },
      createdAt,
      { json: "vehicleUID", column: "vehicle_id", type: "text", optional: true },
    ],
  },
  {
    entity: "document", table: "documents", keyField: "uid", fields: [
      uid,
      { json: "title", type: "text" },
      { json: "kindRaw", column: "kind", type: "text", default: "'idCard'" },
      { json: "number", type: "text" },
      { json: "issuer", type: "text" },
      { json: "expiryDate", type: "date", optional: true },
      { json: "remindDaysBefore", type: "int", default: "60" },
      notes,
      createdAt,
    ],
  },
  {
    entity: "jobApplication", table: "job_applications", keyField: "uid", fields: [
      uid,
      { json: "company", type: "text" },
      { json: "role", type: "text" },
      { json: "appliedAt", type: "date" },
      { json: "statusRaw", column: "status", type: "text", default: "'applied'" },
      { json: "statusChangedAt", type: "date" },
      { json: "followUpDate", type: "date", optional: true },
      { json: "location", type: "text" },
      { json: "link", type: "text" },
      { json: "salary", type: "text" },
      { json: "contact", type: "text" },
      notes,
      createdAt,
    ],
  },
  {
    entity: "course", table: "courses", keyField: "uid", fields: [
      uid,
      { json: "title", type: "text" },
      { json: "provider", type: "text" },
      { json: "statusRaw", column: "status", type: "text", default: "'planned'" },
      { json: "progress", type: "double" },
      { json: "completedAt", type: "date", optional: true },
      { json: "link", type: "text" },
      { json: "credentialID", column: "credential_id", type: "text" },
      { json: "expiresAt", type: "date", optional: true },
      notes,
      createdAt,
    ],
  },
  {
    entity: "investment", table: "investments", keyField: "uid", fields: [
      uid,
      { json: "name", type: "text" },
      { json: "ticker", type: "text" },
      { json: "kindRaw", column: "kind", type: "text", default: "'etf'" },
      currency,
      { json: "units", type: "double" },
      { json: "investedAmount", type: "numeric" },
      { json: "unitPrice", type: "numeric" },
      { json: "priceUpdatedAt", type: "date", optional: true },
      { json: "manualValue", type: "numeric" },
      { json: "isArchived", type: "bool" },
      notes,
      createdAt,
    ],
  },
  {
    // Chave: o dia em segundos desde 1970.
    entity: "wealthSnapshot", table: "wealth_snapshots", keyField: null, fields: [
      { json: "day", type: "date" },
      { json: "cash", type: "numeric" },
      { json: "invested", type: "numeric" },
      { json: "investmentsValue", type: "numeric" },
    ],
  },
  {
    entity: "habit", table: "habits", keyField: "uid", fields: [
      uid,
      { json: "name", type: "text" },
      { json: "symbolName", type: "text", default: "'checkmark.circle'" },
      { json: "colorName", type: "text", default: "'green'" },
      { json: "targetPerWeek", type: "int", default: "7" },
      { json: "sortOrder", type: "int" },
      { json: "isArchived", type: "bool" },
      createdAt,
    ],
  },
  {
    entity: "habitCheck", table: "habit_checks", keyField: "uid", fields: [
      uid,
      { json: "day", type: "date" },
      createdAt,
      { json: "habitUID", column: "habit_id", type: "text", optional: true },
    ],
  },
  {
    // Definições partilhadas entre dispositivos (custos da loja, taxa BRL, meta de poupança…).
    entity: "setting", table: "user_settings", keyField: "key", fields: [
      { json: "key", column: "id", type: "text" },
      { json: "value", type: "jsonb", optional: true },
    ],
  },
];

/** camelCase → snake_case ("symbolName" → "symbol_name"; usa `column` para nomes especiais). */
export function columnName(field) {
  if (field.column) return field.column;
  return field.json.replace(/([a-z0-9])([A-Z])/g, "$1_$2").replace(/([A-Z])([A-Z][a-z])/g, "$1_$2").toLowerCase();
}
