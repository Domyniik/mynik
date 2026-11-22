import type { PGlite } from "@electric-sql/pglite";

/** Segundos entre 1/1/1970 e 1/1/2001 (datas do iPhone). */
const IOS_EPOCH = 978307200;
const DAY = 86_400;

type Payload = Record<string, unknown>;
type Row = { entity: string; key: string; payload: Payload };

export interface Fixture {
  now: number;
  settings: Record<string, number>;
  archive: Record<string, Payload[]>;
}

/** Data do iPhone a partir de "há N dias, à hora H" (fuso local do browser). */
function ago(days: number, hour = 12, minute = 0) {
  const d = new Date();
  d.setHours(hour, minute, 0, 0);
  d.setDate(d.getDate() - days);
  return d.getTime() / 1000 - IOS_EPOCH;
}
const inDays = (days: number, hour = 9) => ago(-days, hour);

function dayKey(iosSeconds: number) {
  const unix = iosSeconds + IOS_EPOCH;
  return Number.isInteger(unix) ? `${unix}.0` : String(unix);
}

const archiveEntities: [string, string, (p: Payload) => string][] = [
  ["categories", "category", (p) => String(p.uid)],
  ["transactions", "transaction", (p) => String(p.uid)],
  ["storeProducts", "storeProduct", (p) => String(p.shopifyID)],
  ["storeOrders", "storeOrder", (p) => String(p.shopifyID)],
  ["storeCheckouts", "storeCheckout", (p) => String(p.shopifyID)],
  ["dailyStats", "dailyStat", (p) => dayKey(Number(p.date))],
];

/**
 * Dados de exemplo da demo. A loja e as finanças vêm do teste de paridade
 * (os mesmos números que o iPhone), deslocados para que "hoje" seja hoje;
 * os outros módulos têm um conjunto pequeno e realista.
 */
export async function seedDemo(db: PGlite, user: string, fixture: Fixture) {
  const dateKeys = new Map<string, Set<string>>();
  const meta = await db.query<{ entity: string; json_key: string }>(
    "select entity, json_key from public.sync_fields where type = 'date'",
  );
  for (const { entity, json_key } of meta.rows) {
    if (!dateKeys.has(entity)) dateKeys.set(entity, new Set());
    dateKeys.get(entity)!.add(json_key);
  }

  // Desloca a loja inventada para hoje (em dias inteiros, mantendo as horas).
  const midnight = (ms: number) => {
    const d = new Date(ms);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  };
  const fixtureMs = (fixture.now + IOS_EPOCH) * 1000;
  const shift = Math.round((midnight(Date.now()) - midnight(fixtureMs)) / 86_400_000) * DAY;
  const shifted = (entity: string, payload: Payload): Payload => {
    const keys = dateKeys.get(entity) ?? new Set();
    return Object.fromEntries(
      Object.entries(payload).map(([k, v]) => [k, keys.has(k) && typeof v === "number" ? v + shift : v]),
    );
  };

  const rows: Row[] = [];
  for (const [list, entity, key] of archiveEntities) {
    for (const payload of fixture.archive[list] ?? []) {
      const moved = shifted(entity, payload);
      rows.push({ entity, key: key(moved), payload: moved });
    }
  }
  for (const [key, value] of Object.entries({ ...fixture.settings, savingsMonthlyTarget: 400 })) {
    rows.push({ entity: "setting", key, payload: { key, value } });
  }
  rows.push(...lifeRows());

  const stamped = rows.map((r) => ({ ...r, deleted: false, modified_at: new Date().toISOString() }));
  await db.query("select public.sync_apply($1::uuid, $2::jsonb)", [user, JSON.stringify(stamped)]);
}

/** Contas, contas a pagar, projetos, metas, hábitos, carro, documentos, carreira, investimentos e notas. */
function lifeRows(): Row[] {
  const rows: Row[] = [];
  const add = (entity: string, payload: Payload, key?: string) =>
    rows.push({ entity, key: key ?? String(payload.uid), payload });
  const created = ago(120);

  // Finanças
  for (const [uid, name, symbolName, colorName, kindRaw, sortOrder, monthlyBudget] of [
    ["CAT-SUBS", "Assinaturas", "repeat", "purple", "expense", 4, 60],
    ["CAT-TRANSPORT", "Transporte", "bus", "teal", "expense", 5, 40],
    ["CAT-INVEST", "Investimentos", "chart.line.uptrend.xyaxis", "indigo", "expense", 6, 0],
    ["CAT-STORE", "Loja", "storefront", "orange", "income", 11, 0],
  ] as const) {
    add("category", { uid, name, symbolName, colorName, kindRaw, sortOrder, monthlyBudget });
  }
  add("account", { uid: "ACC-MAIN", name: "Conta principal", typeRaw: "checking", currencyCode: "EUR", initialBalance: 1240, isArchived: false, createdAt: created });
  add("account", { uid: "ACC-SAVE", name: "Poupança", typeRaw: "savings", currencyCode: "EUR", initialBalance: 3100, isArchived: false, createdAt: created });
  add("account", { uid: "ACC-BR", name: "Nubank", typeRaw: "card", currencyCode: "BRL", initialBalance: 850, isArchived: false, createdAt: created });
  const bill = (uid: string, title: string, amount: number, due: number, recurrenceRaw: string, isSubscription: boolean, categoryUID: string) =>
    add("bill", { uid, title, amount, currencyCode: "EUR", dueDate: due, isPaid: false, recurrenceRaw, notes: "", isSubscription, createdAt: created, categoryUID, accountUID: "ACC-MAIN" });
  bill("BILL-RENT", "Renda", 750, inDays(3), "monthly", false, "CAT-HOME");
  bill("BILL-SPOTIFY", "Spotify", 10.99, inDays(1), "monthly", true, "CAT-SUBS");
  bill("BILL-NET", "Internet", 35, inDays(10), "monthly", true, "CAT-HOME");
  bill("BILL-SHOPIFY", "Shopify Basic", 37, inDays(12), "monthly", true, "CAT-SUBS");
  bill("BILL-GYM", "Ginásio", 29.9, ago(2), "monthly", true, "CAT-FUN");
  bill("BILL-INSURANCE", "Seguro do Golf", 380, inDays(5), "yearly", false, "CAT-CAR");

  // Projetos e tarefas
  const project = (uid: string, name: string, details: string, symbolName: string, colorName: string, statusRaw: string, due?: number) =>
    add("project", { uid, name, details, symbolName, colorName, statusRaw, ...(due ? { dueDate: due } : {}), createdAt: created });
  project("PRJ-DESKTOP", "Mynik desktop", "Next.js + Tauri, paridade com o iPhone", "laptopcomputer", "indigo", "active", inDays(20));
  project("PRJ-WINTER", "Neloce — coleção de inverno", "Fotos, fichas e anúncios", "sparkles", "orange", "active", inDays(14));
  project("PRJ-MOVE", "Mudança de casa", "", "house", "teal", "paused");
  const task = (uid: string, title: string, statusRaw: string, priorityRaw: number, projectUID: string | null, due?: number) =>
    add("task", { uid, title, notes: "", statusRaw, priorityRaw, ...(due != null ? { dueDate: due } : {}), ...(statusRaw === "done" ? { completedAt: ago(1) } : {}), createdAt: ago(10), ...(projectUID ? { projectUID } : {}) });
  task("TSK-1", "Ranking de produtos no desktop", "doing", 2, "PRJ-DESKTOP", inDays(2));
  task("TSK-2", "Kanban com arrastar e largar", "todo", 1, "PRJ-DESKTOP", inDays(5));
  task("TSK-3", "Instaladores .dmg e .exe", "todo", 1, "PRJ-DESKTOP");
  task("TSK-4", "Tabelas tipadas no Supabase", "done", 2, "PRJ-DESKTOP");
  task("TSK-5", "Fotografar 12 peças novas", "todo", 2, "PRJ-WINTER", ago(1));
  task("TSK-6", "Enviar pedido #1043", "todo", 2, "PRJ-WINTER", inDays(0, 18));
  task("TSK-7", "Pedir orçamentos de mudança", "todo", 0, "PRJ-MOVE");
  task("TSK-8", "Pagar Spotify", "todo", 1, null, inDays(1));

  // Metas
  add("goal", { uid: "GOAL-EMERGENCY", title: "Fundo de emergência", targetAmount: 6000, currencyCode: "EUR", symbolName: "shield", colorName: "green", sourceRaw: "account", manualAmount: 0, startDate: ago(200), isArchived: false, createdAt: ago(200), accountUID: "ACC-SAVE" });
  add("goal", { uid: "GOAL-GOLF", title: "Suspensão do Golf", targetAmount: 800, currencyCode: "EUR", deadline: inDays(75), symbolName: "car", colorName: "orange", sourceRaw: "manual", manualAmount: 520, startDate: ago(60), isArchived: false, createdAt: ago(60) });
  add("goal", { uid: "GOAL-BRAZIL", title: "Viagem ao Brasil", targetAmount: 1500, currencyCode: "EUR", deadline: inDays(200), symbolName: "airplane", colorName: "blue", sourceRaw: "manual", manualAmount: 310, startDate: ago(30), isArchived: false, createdAt: ago(30) });

  // Hábitos
  const habits = [
    ["HAB-GYM", "Ginásio", "figure.run", "orange", 4, [0, 2, 3, 5, 7, 9]],
    ["HAB-READ", "Ler 20 minutos", "book", "blue", 7, [0, 1, 2, 3, 4, 6, 7, 8]],
    ["HAB-WATER", "2 L de água", "drop", "teal", 7, [1, 2, 4, 5]],
  ] as const;
  habits.forEach(([uid, name, symbolName, colorName, targetPerWeek, days], sortOrder) => {
    add("habit", { uid, name, symbolName, colorName, targetPerWeek, sortOrder, isArchived: false, createdAt: ago(40) });
    for (const d of days) add("habitCheck", { uid: `${uid}-${d}`, day: ago(d, 0), createdAt: ago(d, 21), habitUID: uid });
  });

  // Carro
  add("vehicle", { uid: "CAR-GOLF", name: "Golf", plate: "1234 LMN", fuelTypeRaw: "gasoline95", initialOdometer: 152000, notes: "", createdAt: ago(300) });
  const fills = [[60, 152400, 42.1, 66.5, true], [44, 153080, 40.3, 63.2, true], [30, 153560, 20.0, 31.6, false], [21, 153790, 21.4, 33.9, true], [6, 154420, 39.8, 62.4, true]] as const;
  fills.forEach(([d, odometer, quantity, totalCost, isFullTank], i) =>
    add("fuelEntry", { uid: `FUEL-${i}`, date: ago(d, 19), odometer, quantity, totalCost, currencyCode: "EUR", isFullTank, station: i % 2 ? "Repsol Getafe" : "Ballenoil Leganés", notes: "", transactionID: "", createdAt: ago(d, 19), vehicleUID: "CAR-GOLF" }),
  );
  add("maintenance", { uid: "MNT-OIL", kindRaw: "oil", title: "", date: ago(90), odometer: 151900, cost: 89, currencyCode: "EUR", workshop: "Midas", notes: "", nextDueOdometer: 161900, transactionID: "", createdAt: ago(90), vehicleUID: "CAR-GOLF" });
  add("maintenance", { uid: "MNT-TYRES", kindRaw: "tyres", title: "Pneus da frente", date: ago(200), odometer: 148000, cost: 210, currencyCode: "EUR", workshop: "Norauto", notes: "", nextDueDate: inDays(160), nextDueOdometer: 0, transactionID: "", createdAt: ago(200), vehicleUID: "CAR-GOLF" });
  add("carDeadline", { uid: "DL-ITV", kindRaw: "inspection", title: "", dueDate: inDays(25), amount: 45, currencyCode: "EUR", renewalMonths: 12, notes: "", createdAt: created, vehicleUID: "CAR-GOLF" });
  add("carDeadline", { uid: "DL-INS", kindRaw: "insurance", title: "", dueDate: inDays(5), amount: 380, currencyCode: "EUR", renewalMonths: 12, notes: "Mapfre", createdAt: created, vehicleUID: "CAR-GOLF" });
  add("carDeadline", { uid: "DL-TAX", kindRaw: "tax", title: "IVTM", dueDate: inDays(140), amount: 68, currencyCode: "EUR", renewalMonths: 12, notes: "", createdAt: created, vehicleUID: "CAR-GOLF" });

  // Documentos
  add("document", { uid: "DOC-CC", title: "", kindRaw: "idCard", number: "12345678 9 ZX4", issuer: "República Portuguesa", expiryDate: inDays(820), remindDaysBefore: 60, notes: "", createdAt: created });
  add("document", { uid: "DOC-TIE", title: "", kindRaw: "residence", number: "Y1234567Z", issuer: "Policía Nacional", expiryDate: inDays(40), remindDaysBefore: 60, notes: "Renovar com cita previa", createdAt: created });
  add("document", { uid: "DOC-PASS", title: "", kindRaw: "passport", number: "FZ123456", issuer: "Brasil", expiryDate: ago(12), remindDaysBefore: 90, notes: "", createdAt: created });

  // Carreira
  const job = (uid: string, company: string, role: string, appliedDays: number, statusRaw: string, followUp?: number) =>
    add("jobApplication", { uid, company, role, appliedAt: ago(appliedDays), statusRaw, statusChangedAt: ago(Math.max(0, appliedDays - 3)), ...(followUp != null ? { followUpDate: followUp } : {}), location: "Madrid (híbrido)", link: "", salary: "", contact: "", notes: "", createdAt: ago(appliedDays) });
  job("JOB-1", "Glovo", "iOS Developer", 12, "interviewing", inDays(1));
  job("JOB-2", "Cabify", "Mobile Engineer", 20, "applied", ago(1));
  job("JOB-3", "Idealista", "Frontend Developer", 35, "rejected");
  job("JOB-4", "Wallapop", "iOS Engineer", 6, "applied", inDays(1));
  add("course", { uid: "CRS-1", title: "AWS Cloud Practitioner", provider: "AWS", statusRaw: "completed", progress: 1, completedAt: ago(100), link: "", credentialID: "AWS-CP-123", expiresAt: inDays(50), notes: "", createdAt: ago(160) });
  add("course", { uid: "CRS-2", title: "SwiftUI avançado", provider: "Hacking with Swift", statusRaw: "inProgress", progress: 0.6, link: "", credentialID: "", notes: "", createdAt: ago(40) });

  // Investimentos
  add("investment", { uid: "INV-VWCE", name: "Vanguard FTSE All-World", ticker: "VWCE.DE", kindRaw: "etf", currencyCode: "EUR", units: 18.4, investedAmount: 2150, unitPrice: 132.6, priceUpdatedAt: ago(0, 9), manualValue: 0, isArchived: false, notes: "Trade Republic", createdAt: ago(400) });
  add("investment", { uid: "INV-BTC", name: "Bitcoin", ticker: "BTC-EUR", kindRaw: "crypto", currencyCode: "EUR", units: 0.012, investedAmount: 600, unitPrice: 81200, priceUpdatedAt: ago(0, 9), manualValue: 0, isArchived: false, notes: "", createdAt: ago(300) });
  add("investment", { uid: "INV-DEP", name: "Depósito a prazo", ticker: "", kindRaw: "deposit", currencyCode: "EUR", units: 0, investedAmount: 1000, unitPrice: 0, manualValue: 1018, isArchived: false, notes: "2,5 % TAE", createdAt: ago(180) });
  for (let m = 6; m >= 0; m -= 1) {
    const day = ago(m * 30, 0);
    add("wealthSnapshot", { day, cash: 4300 + (6 - m) * 180, invested: 3300 + (6 - m) * 75, investmentsValue: 3350 + (6 - m) * 105 }, dayKey(day));
  }

  // Notas
  const note = (uid: string, title: string, icon: string, extra: Payload = {}) =>
    add("note", { uid, title, icon, createdAt: ago(20), updatedAt: ago(1), sortOrder: 0, linkedProjectUIDs: [], linkedTransactionUIDs: [], linkedNoteUIDs: [], ...extra });
  const block = (uid: string, noteUID: string, sortOrder: number, kindRaw: string, text: string, extra: Payload = {}) =>
    add("noteBlock", { uid, kindRaw, text, isChecked: false, sortOrder, createdAt: ago(20), noteUID, ...extra });
  note("NOTE-WELCOME", "Bem-vindo ao Mynik", "👋", { isFavorite: true, coverRaw: "aurora" });
  block("B-1", "NOTE-WELCOME", 0, "heading", "Tudo num só sítio");
  block("B-2", "NOTE-WELCOME", 1, "text", "Finanças, loja, projetos, carro e documentos — no iPhone e no computador.");
  block("B-3", "NOTE-WELCOME", 2, "checklist", "Ligar a loja Shopify", { isChecked: true });
  block("B-4", "NOTE-WELCOME", 3, "checklist", "Importar o extrato do banco (arrasta o CSV para Finanças)");
  block("B-5", "NOTE-WELCOME", 4, "callout", "Carrega em ⌘K para procurar em tudo.", { emoji: "💡" });
  block("B-6", "NOTE-WELCOME", 5, "code", "const lucro = vendas - custos - frete - taxas - ads", { language: "ts" });
  note("NOTE-DESKTOP", "Mynik desktop — decisões", "🧭", { linkedProjectUIDs: ["PRJ-DESKTOP"], parentUID: "NOTE-WELCOME" });
  block("B-7", "NOTE-DESKTOP", 0, "bulleted", "Tauri v2 a empacotar o Next.js estático");
  block("B-8", "NOTE-DESKTOP", 1, "bulleted", "Cálculos em SQL: o iPhone e o desktop dão o mesmo número");
  block("B-9", "NOTE-DESKTOP", 2, "quote", "Faz uma coisa de cada vez, mas acaba-a.");
  const schema = JSON.stringify([
    { id: "author", name: "Autor", type: "text" },
    { id: "status", name: "Estado", type: "select", options: ["Quero ler", "A ler", "Lido"] },
    { id: "rating", name: "Nota", type: "number" },
  ]);
  note("NOTE-BOOKS", "Leituras", "📚", { isDatabase: true, databaseSchemaJSON: schema, databaseViewRaw: "board" });
  for (const [i, [title, author, status, rating]] of ([
    ["Hábitos Atómicos", "James Clear", "Lido", 5],
    ["O Investidor Inteligente", "Benjamin Graham", "A ler", null],
    ["Deep Work", "Cal Newport", "Quero ler", null],
  ] as const).entries()) {
    note(`NOTE-BOOK-${i}`, title, "📖", {
      parentUID: "NOTE-BOOKS",
      sortOrder: i,
      propertyValuesJSON: JSON.stringify({ author, status, ...(rating != null ? { rating: String(rating) } : {}) }),
    });
  }
  return rows;
}
