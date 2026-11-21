// GERADO por web/scripts/generate-types.mjs a partir de supabase/schema/entities.mjs.
// Não editar à mão: `npm run types`.

/** Colunas comuns a todas as tabelas (sync e RLS). */
export interface SyncColumns {
  user_id: string;
  id: string;
  deleted: boolean;
  modified_at: string;
  updated_at: string;
}

/** Tabela `categories` (registo `category` do iPhone). */
export interface CategoryRow extends SyncColumns {
  name: string;
  symbol_name: string;
  color_name: string;
  kind: string;
  sort_order: number;
  monthly_budget: number;
}

/** Tabela `accounts` (registo `account` do iPhone). */
export interface AccountRow extends SyncColumns {
  name: string;
  type: string;
  currency_code: string;
  initial_balance: number;
  is_archived: boolean;
  created_at: string;
}

/** Tabela `transactions` (registo `transaction` do iPhone). */
export interface TransactionRow extends SyncColumns {
  title: string;
  amount: number;
  kind: string;
  currency_code: string;
  date: string;
  notes: string;
  created_at: string;
  external_id: string;
  category_id: string | null;
  account_id: string | null;
}

/** Tabela `bills` (registo `bill` do iPhone). */
export interface BillRow extends SyncColumns {
  title: string;
  amount: number;
  currency_code: string;
  due_date: string;
  is_paid: boolean;
  paid_at: string | null;
  recurrence: string;
  notes: string;
  is_subscription: boolean;
  created_at: string;
  category_id: string | null;
  account_id: string | null;
}

/** Tabela `store_products` (registo `storeProduct` do iPhone). */
export interface StoreProductRow extends SyncColumns {
  title: string;
  handle: string;
  status: string;
  image_url: string;
  price: number;
  unit_cost: number;
  unit_cost_is_manual: boolean;
  inventory: number;
  tracks_inventory: boolean;
  created_at: string;
  ad_spend_30d: number;
  decision: string;
  decided_at: string | null;
  decision_note: string;
  synced_at: string;
}

/** Tabela `store_orders` (registo `storeOrder` do iPhone). */
export interface StoreOrderRow extends SyncColumns {
  name: string;
  created_at: string;
  cancelled_at: string | null;
  subtotal: number;
  shipping: number;
  tax: number;
  total: number;
  refunded: number;
  currency_code: string;
  financial_status: string;
  fulfillment_status: string;
  lines: unknown;
  synced_at: string;
}

/** Tabela `store_checkouts` (registo `storeCheckout` do iPhone). */
export interface StoreCheckoutRow extends SyncColumns {
  name: string;
  created_at: string;
  total: number;
  recovery_url: string;
  lines: unknown;
  synced_at: string;
}

/** Tabela `daily_stats` (registo `dailyStat` do iPhone). */
export interface DailyStatRow extends SyncColumns {
  date: string;
  sales: number;
  net_revenue: number;
  orders: number;
  units: number;
  refunds: number;
  sessions: number;
  cart_sessions: number;
  checkout_sessions: number;
  completed_sessions: number;
  has_traffic: boolean;
}

/** Tabela `projects` (registo `project` do iPhone). */
export interface ProjectRow extends SyncColumns {
  name: string;
  details: string;
  symbol_name: string;
  color_name: string;
  status: string;
  due_date: string | null;
  created_at: string;
}

/** Tabela `tasks` (registo `task` do iPhone). */
export interface TaskRow extends SyncColumns {
  title: string;
  notes: string;
  status: string;
  priority: number;
  due_date: string | null;
  completed_at: string | null;
  created_at: string;
  project_id: string | null;
}

/** Tabela `goals` (registo `goal` do iPhone). */
export interface GoalRow extends SyncColumns {
  title: string;
  target_amount: number;
  currency_code: string;
  deadline: string | null;
  symbol_name: string;
  color_name: string;
  source: string;
  manual_amount: number;
  start_date: string;
  is_archived: boolean;
  created_at: string;
  account_id: string | null;
  category_id: string | null;
}

/** Tabela `notes` (registo `note` do iPhone). */
export interface NoteRow extends SyncColumns {
  title: string;
  icon: string;
  created_at: string;
  edited_at: string;
  sort_order: number;
  parent_id: string | null;
  linked_project_ids: string[];
  linked_transaction_ids: string[];
  linked_note_ids: string[];
  is_favorite: boolean;
  cover: string;
  is_template: boolean;
  is_database: boolean;
  database_schema: string;
  database_view: string;
  property_values: string;
}

/** Tabela `note_blocks` (registo `noteBlock` do iPhone). */
export interface NoteBlockRow extends SyncColumns {
  kind: string;
  text: string;
  is_checked: boolean;
  image_data: string | null;
  sort_order: number;
  created_at: string;
  note_id: string | null;
  emoji: string;
  language: string;
  detail: string;
  is_expanded: boolean;
}

/** Tabela `vehicles` (registo `vehicle` do iPhone). */
export interface VehicleRow extends SyncColumns {
  name: string;
  plate: string;
  fuel_type: string;
  initial_odometer: number;
  notes: string;
  created_at: string;
}

/** Tabela `fuel_entries` (registo `fuelEntry` do iPhone). */
export interface FuelEntryRow extends SyncColumns {
  date: string;
  odometer: number;
  quantity: number;
  total_cost: number;
  currency_code: string;
  is_full_tank: boolean;
  station: string;
  notes: string;
  transaction_id: string;
  created_at: string;
  vehicle_id: string | null;
}

/** Tabela `maintenance_records` (registo `maintenance` do iPhone). */
export interface MaintenanceRow extends SyncColumns {
  kind: string;
  title: string;
  date: string;
  odometer: number;
  cost: number;
  currency_code: string;
  workshop: string;
  notes: string;
  next_due_date: string | null;
  next_due_odometer: number;
  transaction_id: string;
  created_at: string;
  vehicle_id: string | null;
}

/** Tabela `car_deadlines` (registo `carDeadline` do iPhone). */
export interface CarDeadlineRow extends SyncColumns {
  kind: string;
  title: string;
  due_date: string;
  amount: number;
  currency_code: string;
  renewal_months: number;
  notes: string;
  last_done_at: string | null;
  created_at: string;
  vehicle_id: string | null;
}

/** Tabela `documents` (registo `document` do iPhone). */
export interface DocumentRow extends SyncColumns {
  title: string;
  kind: string;
  number: string;
  issuer: string;
  expiry_date: string | null;
  remind_days_before: number;
  notes: string;
  created_at: string;
}

/** Tabela `job_applications` (registo `jobApplication` do iPhone). */
export interface JobApplicationRow extends SyncColumns {
  company: string;
  role: string;
  applied_at: string;
  status: string;
  status_changed_at: string;
  follow_up_date: string | null;
  location: string;
  link: string;
  salary: string;
  contact: string;
  notes: string;
  created_at: string;
}

/** Tabela `courses` (registo `course` do iPhone). */
export interface CourseRow extends SyncColumns {
  title: string;
  provider: string;
  status: string;
  progress: number;
  completed_at: string | null;
  link: string;
  credential_id: string;
  expires_at: string | null;
  notes: string;
  created_at: string;
}

/** Tabela `investments` (registo `investment` do iPhone). */
export interface InvestmentRow extends SyncColumns {
  name: string;
  ticker: string;
  kind: string;
  currency_code: string;
  units: number;
  invested_amount: number;
  unit_price: number;
  price_updated_at: string | null;
  manual_value: number;
  is_archived: boolean;
  notes: string;
  created_at: string;
}

/** Tabela `wealth_snapshots` (registo `wealthSnapshot` do iPhone). */
export interface WealthSnapshotRow extends SyncColumns {
  day: string;
  cash: number;
  invested: number;
  investments_value: number;
}

/** Tabela `habits` (registo `habit` do iPhone). */
export interface HabitRow extends SyncColumns {
  name: string;
  symbol_name: string;
  color_name: string;
  target_per_week: number;
  sort_order: number;
  is_archived: boolean;
  created_at: string;
}

/** Tabela `habit_checks` (registo `habitCheck` do iPhone). */
export interface HabitCheckRow extends SyncColumns {
  day: string;
  created_at: string;
  habit_id: string | null;
}

/** Tabela `user_settings` (registo `setting` do iPhone). */
export interface SettingRow extends SyncColumns {
  value: unknown | null;
}

export interface Tables {
  categories: CategoryRow;
  accounts: AccountRow;
  transactions: TransactionRow;
  bills: BillRow;
  store_products: StoreProductRow;
  store_orders: StoreOrderRow;
  store_checkouts: StoreCheckoutRow;
  daily_stats: DailyStatRow;
  projects: ProjectRow;
  tasks: TaskRow;
  goals: GoalRow;
  notes: NoteRow;
  note_blocks: NoteBlockRow;
  vehicles: VehicleRow;
  fuel_entries: FuelEntryRow;
  maintenance_records: MaintenanceRow;
  car_deadlines: CarDeadlineRow;
  documents: DocumentRow;
  job_applications: JobApplicationRow;
  courses: CourseRow;
  investments: InvestmentRow;
  wealth_snapshots: WealthSnapshotRow;
  habits: HabitRow;
  habit_checks: HabitCheckRow;
  user_settings: SettingRow;
}

export type TableName = keyof Tables;

/** Tipo de cada coluna (para converter valores e preencher formulários). */
export const columnTypes = {
  categories: { name: "text", symbol_name: "text", color_name: "text", kind: "text", sort_order: "int", monthly_budget: "numeric" },
  accounts: { name: "text", type: "text", currency_code: "text", initial_balance: "numeric", is_archived: "bool", created_at: "date" },
  transactions: { title: "text", amount: "numeric", kind: "text", currency_code: "text", date: "date", notes: "text", created_at: "date", external_id: "text", category_id: "text", account_id: "text" },
  bills: { title: "text", amount: "numeric", currency_code: "text", due_date: "date", is_paid: "bool", paid_at: "date", recurrence: "text", notes: "text", is_subscription: "bool", created_at: "date", category_id: "text", account_id: "text" },
  store_products: { title: "text", handle: "text", status: "text", image_url: "text", price: "numeric", unit_cost: "numeric", unit_cost_is_manual: "bool", inventory: "int", tracks_inventory: "bool", created_at: "date", ad_spend_30d: "numeric", decision: "text", decided_at: "date", decision_note: "text", synced_at: "date" },
  store_orders: { name: "text", created_at: "date", cancelled_at: "date", subtotal: "numeric", shipping: "numeric", tax: "numeric", total: "numeric", refunded: "numeric", currency_code: "text", financial_status: "text", fulfillment_status: "text", lines: "jsonb", synced_at: "date" },
  store_checkouts: { name: "text", created_at: "date", total: "numeric", recovery_url: "text", lines: "jsonb", synced_at: "date" },
  daily_stats: { date: "date", sales: "numeric", net_revenue: "numeric", orders: "int", units: "int", refunds: "numeric", sessions: "int", cart_sessions: "int", checkout_sessions: "int", completed_sessions: "int", has_traffic: "bool" },
  projects: { name: "text", details: "text", symbol_name: "text", color_name: "text", status: "text", due_date: "date", created_at: "date" },
  tasks: { title: "text", notes: "text", status: "text", priority: "int", due_date: "date", completed_at: "date", created_at: "date", project_id: "text" },
  goals: { title: "text", target_amount: "numeric", currency_code: "text", deadline: "date", symbol_name: "text", color_name: "text", source: "text", manual_amount: "numeric", start_date: "date", is_archived: "bool", created_at: "date", account_id: "text", category_id: "text" },
  notes: { title: "text", icon: "text", created_at: "date", edited_at: "date", sort_order: "int", parent_id: "text", linked_project_ids: "text[]", linked_transaction_ids: "text[]", linked_note_ids: "text[]", is_favorite: "bool", cover: "text", is_template: "bool", is_database: "bool", database_schema: "text", database_view: "text", property_values: "text" },
  note_blocks: { kind: "text", text: "text", is_checked: "bool", image_data: "base64", sort_order: "int", created_at: "date", note_id: "text", emoji: "text", language: "text", detail: "text", is_expanded: "bool" },
  vehicles: { name: "text", plate: "text", fuel_type: "text", initial_odometer: "int", notes: "text", created_at: "date" },
  fuel_entries: { date: "date", odometer: "int", quantity: "double", total_cost: "numeric", currency_code: "text", is_full_tank: "bool", station: "text", notes: "text", transaction_id: "text", created_at: "date", vehicle_id: "text" },
  maintenance_records: { kind: "text", title: "text", date: "date", odometer: "int", cost: "numeric", currency_code: "text", workshop: "text", notes: "text", next_due_date: "date", next_due_odometer: "int", transaction_id: "text", created_at: "date", vehicle_id: "text" },
  car_deadlines: { kind: "text", title: "text", due_date: "date", amount: "numeric", currency_code: "text", renewal_months: "int", notes: "text", last_done_at: "date", created_at: "date", vehicle_id: "text" },
  documents: { title: "text", kind: "text", number: "text", issuer: "text", expiry_date: "date", remind_days_before: "int", notes: "text", created_at: "date" },
  job_applications: { company: "text", role: "text", applied_at: "date", status: "text", status_changed_at: "date", follow_up_date: "date", location: "text", link: "text", salary: "text", contact: "text", notes: "text", created_at: "date" },
  courses: { title: "text", provider: "text", status: "text", progress: "double", completed_at: "date", link: "text", credential_id: "text", expires_at: "date", notes: "text", created_at: "date" },
  investments: { name: "text", ticker: "text", kind: "text", currency_code: "text", units: "double", invested_amount: "numeric", unit_price: "numeric", price_updated_at: "date", manual_value: "numeric", is_archived: "bool", notes: "text", created_at: "date" },
  wealth_snapshots: { day: "date", cash: "numeric", invested: "numeric", investments_value: "numeric" },
  habits: { name: "text", symbol_name: "text", color_name: "text", target_per_week: "int", sort_order: "int", is_archived: "bool", created_at: "date" },
  habit_checks: { day: "date", created_at: "date", habit_id: "text" },
  user_settings: { value: "jsonb" },
} as const satisfies Record<TableName, Record<string, string>>;

export const tableNames = Object.keys(columnTypes) as TableName[];
