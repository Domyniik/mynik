// Edge Function do Mynik: tudo o que precisa de servidor (segredos ou APIs sem CORS).
//   shopify-status  ligação à loja (nome)          shopify-sync  produtos, pedidos, checkouts, tráfego → tabelas
//   google-ads      gasto da folha (Google Sheets)   quote        cotação (Yahoo) + câmbio (BCE)
//   fuel            postos de uma província (ES)     rate         EUR→BRL do dia (BCE)
// Só com sessão iniciada: as escritas usam o JWT do utilizador (RLS).
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.119.0";
import { credentials, ShopifyError, shopInfo, syncStore } from "./shopify.ts";
import { addDays, localDayKey } from "./time.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function rate(from: string, to: string) {
  if (from === to) return 1;
  const response = await fetch(`https://api.frankfurter.dev/v1/latest?base=${encodeURIComponent(from)}&symbols=${encodeURIComponent(to)}`);
  if (!response.ok) throw new Error("Sem câmbio do BCE");
  const data = await response.json();
  const value = data.rates?.[to];
  if (!value) throw new Error(`Sem câmbio ${from}→${to}`);
  return Number(value);
}

/** Cotação gratuita (Yahoo Finance, sem chave): só o ticker sai, nunca valores. */
async function quote(symbol: string, target: string) {
  const response = await fetch(`https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol.trim().toUpperCase())}?range=1d&interval=1d`, {
    headers: { "User-Agent": "Mozilla/5.0 (Macintosh) Mynik" },
  });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error("Cotações indisponíveis");
  const meta = (await response.json()).chart?.result?.[0]?.meta;
  if (!meta?.regularMarketPrice || !meta.currency) return null;
  let price = Number(meta.regularMarketPrice);
  let currency = String(meta.currency);
  if (currency === "GBp" || currency === "GBX") {
    price /= 100;
    currency = "GBP";
  }
  currency = currency.toUpperCase();
  const converted = currency === target ? price : price * (await rate(currency, target));
  return { price: converted, currency: target, sourceCurrency: currency, name: meta.shortName ?? meta.longName ?? null };
}

/** Preços de combustível de uma província (API pública do Ministerio, Espanha). */
async function fuel(province: string) {
  const id = province.replace(/\D/g, "").padStart(2, "0");
  const response = await fetch(`https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/FiltroProvincia/${id}`);
  if (!response.ok) throw new Error("Preços indisponíveis");
  const data = await response.json();
  const fields: Record<string, string> = {
    gasoline95: "Precio Gasolina 95 E5", gasoline98: "Precio Gasolina 98 E5", diesel: "Precio Gasoleo A",
    dieselPremium: "Precio Gasoleo Premium", lpg: "Precio Gases licuados del petróleo",
  };
  const num = (text?: string) => (text && text.trim() ? Number(text.replace(",", ".")) : null);
  const title = (text = "") => text.toLowerCase().replace(/(^|\s)\p{L}/gu, (c) => c.toUpperCase());
  const stations = (data.ListaEESSPrecio ?? []).flatMap((row: Record<string, string>) => {
    const latitude = num(row["Latitud"]);
    const longitude = num(row["Longitud (WGS84)"]);
    if (latitude == null || longitude == null) return [];
    const prices: Record<string, number> = {};
    for (const [fuelType, field] of Object.entries(fields)) {
      const price = num(row[field]);
      if (price && price > 0) prices[fuelType] = price;
    }
    if (Object.keys(prices).length === 0) return [];
    return [{ id: row["IDEESS"], brand: title(row["Rótulo"]), address: title(row["Dirección"]), town: title(row["Localidad"]), latitude, longitude, prices }];
  });
  return { provinceID: id, publishedAt: data.Fecha ?? null, stations };
}

/** Gasto do Google Ads de uma folha partilhada (colunas date,campaign,cost,currency,final_url). */
// deno-lint-ignore no-explicit-any
async function googleAds(sheet: string, db: SupabaseClient<any, any, any>) {
  const id = sheet.match(/\/d\/([A-Za-z0-9_-]{20,})/)?.[1] ?? (/^[A-Za-z0-9_-]{20,}$/.test(sheet.trim()) ? sheet.trim() : null);
  if (!id) throw new Error("Não reconheço a folha: cola o URL do Google Sheets.");
  const response = await fetch(`https://docs.google.com/spreadsheets/d/${id}/export?format=csv`, { redirect: "follow" });
  const text = await response.text();
  if (!response.ok || text.trimStart().startsWith("<")) throw new Error("A folha não está partilhada como \"qualquer pessoa com o link pode ver\".");
  const records = parseCSV(text);
  const header = (records.shift() ?? []).map((h) => h.trim().toLowerCase());
  const col = (name: string) => header.indexOf(name);
  const [iDate, iCost, iCurrency, iURL] = [col("date"), col("cost"), col("currency"), col("final_url")];
  if (iDate < 0 || iCost < 0) throw new Error("A folha precisa das colunas date e cost.");
  const today = localDayKey(new Date());
  const from = addDays(today, -29);
  const perHandle = new Map<string, number>();
  let unattributed = 0;
  const brl = await rate("EUR", "BRL").catch(() => 6);
  for (const r of records) {
    const day = (r[iDate] ?? "").trim();
    const cost = Number((r[iCost] ?? "").replace(",", "."));
    if (!day || !Number.isFinite(cost) || day < from || day > today) continue;
    const currency = (r[iCurrency] ?? "EUR").trim().toUpperCase() || "EUR";
    const eur = currency === "BRL" ? cost / brl : cost;
    const handle = (r[iURL] ?? "").match(/\/products\/([^/?#]+)/)?.[1]?.toLowerCase();
    if (handle) perHandle.set(handle, (perHandle.get(handle) ?? 0) + eur);
    else unattributed += eur;
  }
  const stamp = new Date().toISOString();
  const { data: products } = await db.from("store_products").select("id, handle").eq("deleted", false);
  for (const p of products ?? []) {
    await db.from("store_products").update({ ad_spend_30d: Math.round((perHandle.get(String(p.handle).toLowerCase()) ?? 0) * 100) / 100, modified_at: stamp }).eq("id", p.id);
  }
  const total = unattributed + [...perHandle.values()].reduce((a, b) => a + b, 0);
  const settings = [
    { id: "googleAdsUnattributed30d", value: Math.round(unattributed * 100) / 100 },
    { id: "googleAdsTotal30d", value: Math.round(total * 100) / 100 },
    { id: "googleAdsLastImport", value: Date.now() / 1000 },
  ].map((s) => ({ ...s, modified_at: stamp, deleted: false }));
  await db.from("user_settings").upsert(settings, { onConflict: "user_id,id" });
  return { total, unattributed, products: perHandle.size };
}

function parseCSV(text: string) {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i += 1; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i += 1;
      row.push(field); field = "";
      if (row.some((f) => f !== "")) rows.push(row);
      row = [];
    } else field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  return rows;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  const authorization = request.headers.get("Authorization") ?? "";
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: user } = await db.auth.getUser();
  if (!user?.user) return json({ error: "Sem sessão" }, 401);

  try {
    const body = await request.json().catch(() => ({}));
    switch (body.action) {
      case "shopify-status": {
        const c = credentials();
        if (!c) return json({ configured: false });
        return json({ configured: true, domain: c.domain, shop: await shopInfo(c) });
      }
      case "shopify-sync": {
        const c = credentials();
        if (!c) return json({ error: "A loja não está ligada: faltam os segredos SHOPIFY_* na Edge Function." }, 400);
        return json(await syncStore(c, db));
      }
      case "google-ads":
        return json(await googleAds(String(body.sheet ?? ""), db));
      case "quote":
        return json({ quote: await quote(String(body.symbol ?? ""), String(body.currency ?? "EUR")) });
      case "fuel":
        return json(await fuel(String(body.province ?? "28")));
      case "rate":
        return json({ rate: await rate(String(body.from ?? "EUR"), String(body.to ?? "BRL")), date: localDayKey(new Date()) });
      default:
        return json({ error: `Ação desconhecida: ${body.action}` }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, error instanceof ShopifyError ? 502 : 500);
  }
});
