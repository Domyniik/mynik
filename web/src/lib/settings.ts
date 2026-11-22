"use client";

import { useCallback, useMemo } from "react";
import { mutate, useTable } from "./db/store";

/**
 * Definições partilhadas com o iPhone (tabela `user_settings`, as mesmas chaves
 * de `SettingsKey` / `SharedSettings.swift`). Os valores por omissão são os do iPhone.
 */
export const settingDefaults = {
  brlPerEUR: 6.0,
  exchangeRateDate: "",
  storeFeePercent: 2.1,
  storeFeeFixed: 0.25,
  storeShippingCost: 4.0,
  storeMonthlyAds: 0,
  storeSaleNotifications: true,
  storeNoSaleDays: 3,
  storeProfitToFinance: true,
  googleAdsSheet: "",
  googleAdsUnattributed30d: 0,
  googleAdsTotal30d: 0,
  googleAdsLastImport: 0,
  taskLayout: "board",
  fuelProvinceID: "28",
  savingsMonthlyTarget: 0,
  autoCategorize: true,
  billRemindersEnabled: true,
  billReminderDaysBefore: 1,
  agendaRemindersEnabled: true,
  weeklyReviewReminder: true,
};

export type SettingKey = keyof typeof settingDefaults;
type Widen<T> = T extends number ? number : T extends boolean ? boolean : string;
export type Settings = { -readonly [K in SettingKey]: Widen<(typeof settingDefaults)[K]> };

export function useSettings() {
  const { rows, loading } = useTable("user_settings");
  const settings = useMemo(() => {
    const values: Record<string, unknown> = { ...settingDefaults };
    for (const row of rows) {
      const fallback = settingDefaults[row.id as SettingKey];
      if (fallback !== undefined && row.value != null && typeof row.value === typeof fallback) values[row.id] = row.value;
    }
    return values as Settings;
  }, [rows]);

  const set = useCallback(
    async <K extends SettingKey>(key: K, value: Settings[K]) => {
      const existing = rows.find((r) => r.id === key);
      if (existing) await mutate.update("user_settings", key, { value });
      else await mutate.insert("user_settings", { id: key, value });
    },
    [rows],
  );

  return { settings, set, loading };
}
