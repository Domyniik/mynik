"use client";

import type { Db } from "./db/client";

/**
 * Cópia de segurança no formato do iPhone (`BackupArchive`, format 1): o
 * mesmo ficheiro JSON abre nos dois. Usa as funções de sync do servidor, que
 * já convertem as tabelas para os registos do iPhone (datas desde 2001).
 */
const IOS_EPOCH = 978307200;
const archiveKeys: Record<string, string> = {
  category: "categories", account: "accounts", transaction: "transactions", bill: "bills",
  storeProduct: "storeProducts", storeOrder: "storeOrders", storeCheckout: "storeCheckouts", dailyStat: "dailyStats",
  project: "projects", task: "tasks", goal: "goals", note: "notes", noteBlock: "noteBlocks",
  vehicle: "vehicles", fuelEntry: "fuelEntries", maintenance: "maintenanceRecords", carDeadline: "carDeadlines",
  document: "documents", jobApplication: "jobApplications", course: "courses",
  investment: "investments", wealthSnapshot: "wealthSnapshots", habit: "habits", habitCheck: "habitChecks", setting: "settings",
};
const keyFields: Record<string, string> = { storeProduct: "shopifyID", storeOrder: "shopifyID", storeCheckout: "shopifyID", setting: "key" };
const dayKey = (ios: number) => {
  const unix = ios + IOS_EPOCH;
  return Number.isInteger(unix) ? `${unix}.0` : String(unix);
};

export async function exportBackup(db: Db) {
  const archive: Record<string, unknown> = {
    format: 1, exportedAt: Date.now() / 1000 - IOS_EPOCH, appVersion: "desktop", device: "Mynik desktop",
    ...Object.fromEntries(Object.values(archiveKeys).map((k) => [k, []])),
    documentPhotos: [],
  };
  for (let offset = 0; ; offset += 1000) {
    const rows = await db.rpc<{ entity: string; deleted: boolean; payload: unknown }>("sync_pull", { p_since: null, p_limit: 1000, p_offset: offset });
    for (const r of rows) if (!r.deleted && archiveKeys[r.entity]) (archive[archiveKeys[r.entity]] as unknown[]).push(r.payload);
    if (rows.length < 1000) break;
  }
  return archive;
}

export function backupFileName() {
  const d = new Date();
  return `Mynik-${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}.json`;
}

/** Junta a cópia aos dados (o que existe com o mesmo id é atualizado; nada é apagado). */
export async function importBackup(db: Db, archive: Record<string, unknown>) {
  if (typeof archive.format !== "number" || archive.format > 1) throw new Error("Cópia de uma versão mais recente ou ficheiro inválido.");
  const rows: unknown[] = [];
  for (const [entity, key] of Object.entries(archiveKeys)) {
    for (const payload of (archive[key] as Record<string, unknown>[] | undefined) ?? []) {
      const id = entity === "dailyStat" ? dayKey(Number(payload.date)) : entity === "wealthSnapshot" ? dayKey(Number(payload.day)) : String(payload[keyFields[entity] ?? "uid"]);
      rows.push({ entity, key: id, payload, deleted: false, modified_at: new Date().toISOString() });
    }
  }
  for (let i = 0; i < rows.length; i += 400) await db.rpc("sync_push", { p_rows: rows.slice(i, i + 400) });
  return rows.length;
}
