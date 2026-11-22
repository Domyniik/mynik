import { searchKey } from "./search";

/**
 * Categorização por regras (tradução de MerchantCategoryRules do iPhone):
 * 1. histórico — o último movimento com a mesma descrição ou o mesmo comerciante;
 * 2. comerciantes conhecidos em Espanha/Portugal; 3. palavras do dia a dia.
 */
export const keywords: [string, string[]][] = [
  ["Assinaturas", ["netflix", "spotify", "hbo", "disney", "prime video", "amazon prime", "apple.com/bill", "icloud", "apple music", "youtube premium", "google one", "chatgpt", "openai", "anthropic", "dazn", "movistar plus", "filmin", "adobe", "microsoft 365", "notion", "github", "patreon", "audible"]],
  ["Alimentação", ["mercadona", "lidl", "aldi", "carrefour", "dia ", "eroski", "alcampo", "consum", "hipercor", "supercor", "bonpreu", "caprabo", "ahorramas", "condis", "continente", "pingo doce", "intermarche", "minipreco", "auchan", "glovo", "just eat", "uber eats", "deliveroo", "telepizza", "mcdonald", "burger king", "kfc", "starbucks", "restaurante", "cafeteria", "panaderia", "padaria", "supermercado", "mercado", "talho", "carniceria", "fruteria", "comida", "almoco", "jantar", "cafe ", "bar "]],
  ["Carro", ["repsol", "cepsa", "moeve", "galp", "bp ", "shell", "petronor", "ballenoil", "plenoil", "petroprix", "gasolinera", "gasolina", "gasoleo", "combustivel", "combustible", "parking", "aparcamiento", "estacionamento", "telpark", "empark", "autopista", "peaje", "portagem", "itv ", "taller", "norauto", "feu vert", "midas "]],
  ["Transporte", ["renfe", "cercanias", "metro ", "emt ", "tmb ", "alsa ", "avanza", "uber", "cabify", "bolt ", "freenow", "free now", "taxi", "blablacar", "ryanair", "vueling", "iberia", "easyjet", "autocarro", "comboio", "bicimad"]],
  ["Saúde", ["farmacia", "parafarmacia", "clinica", "hospital", "dentista", "medico", "sanitas", "adeslas", "dkv ", "optica", "opticalia", "multiopticas", "fisioterapia"]],
  ["Lazer", ["cine ", "cinema", "yelmo", "cinesa", "kinepolis", "teatro", "museo", "museu", "concierto", "ticketmaster", "entradas", "steam", "playstation", "nintendo", "xbox", "booking", "airbnb", "hotel", "gimnasio", "ginasio", "basic fit", "dreamfit", "viagem"]],
  ["Compras", ["amazon", "aliexpress", "shein", "temu", "zara", "pull&bear", "bershka", "stradivarius", "massimo dutti", "primark", "h&m", "mango ", "decathlon", "ikea", "leroy merlin", "mediamarkt", "media markt", "fnac", "el corte ingles", "apple store", "pccomponentes", "roupa"]],
  ["Casa", ["iberdrola", "endesa", "naturgy", "holaluz", "edp ", "totalenergies", "canal de isabel", "movistar", "vodafone", "orange", "digi ", "masmovil", "yoigo", "pepephone", "lowi ", "renda", "alquiler", "comunidad", "luz ", "agua ", "internet", "gas natural"]],
  ["Salário", ["nomina", "salario", "ordenado", "payroll"]],
  ["Loja", ["shopify", "neloce", "stripe payout"]],
];

/** Minúsculas, sem acentos, só letras/números (e & . /) e espaços simples. */
export function normalizeTitle(text: string) {
  return searchKey(text)
    .replace(/[^\p{L}\p{N}&./]+/gu, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .join(" ");
}

const ignoredMerchant = new Set(["compra", "pago", "pagamento", "tarjeta", "cartao", "card", "apple", "pay", "en", "em", "de", "da", "do", "the", "con", "com"]);

/** Primeira palavra significativa: "COMPRA MERCADONA VALENCIA 1234" → "mercadona". */
export function merchantKey(text: string) {
  return normalizeTitle(text).split(" ").find((w) => w.length >= 3 && !ignoredMerchant.has(w) && !/^\d+$/.test(w)) ?? "";
}

const pad = (word: string) => (word.endsWith(" ") ? ` ${word.trim()} ` : ` ${word.trim()}`);

export interface HistoryEntry {
  title: string;
  categoryName: string;
  date: string;
}

export type SuggestionSource = "history" | "rules";
export const sourceLabel: Record<SuggestionSource, string> = {
  history: "Sugerida pelo histórico",
  rules: "Sugerida pelo nome do comerciante",
};

export class MerchantRules {
  private byTitle = new Map<string, { name: string; date: string }>();
  private byMerchant = new Map<string, { name: string; date: string }>();

  constructor(history: HistoryEntry[] = []) {
    for (const entry of history) {
      const key = normalizeTitle(entry.title);
      if (!key) continue;
      const known = this.byTitle.get(key);
      if (!known || known.date <= entry.date) this.byTitle.set(key, { name: entry.categoryName, date: entry.date });
      const merchant = merchantKey(entry.title);
      const knownMerchant = this.byMerchant.get(merchant);
      if (merchant && (!knownMerchant || knownMerchant.date <= entry.date)) {
        this.byMerchant.set(merchant, { name: entry.categoryName, date: entry.date });
      }
    }
  }

  private static index(names: string[]) {
    const map = new Map<string, string>();
    for (const n of names) if (!map.has(searchKey(n))) map.set(searchKey(n), n);
    return map;
  }

  historySuggestion(title: string, categoryNames: string[]) {
    const available = MerchantRules.index(categoryNames);
    const fromTitle = this.byTitle.get(normalizeTitle(title))?.name;
    if (fromTitle && available.has(searchKey(fromTitle))) return { categoryName: available.get(searchKey(fromTitle))!, source: "history" as const };
    const merchant = merchantKey(title);
    const fromMerchant = merchant ? this.byMerchant.get(merchant)?.name : undefined;
    if (fromMerchant && available.has(searchKey(fromMerchant))) return { categoryName: available.get(searchKey(fromMerchant))!, source: "history" as const };
    return null;
  }

  keywordSuggestion(title: string, categoryNames: string[]) {
    const key = normalizeTitle(title);
    if (!key) return null;
    const available = MerchantRules.index(categoryNames);
    const padded = ` ${key} `;
    for (const [category, words] of keywords) {
      const match = available.get(searchKey(category));
      if (match && words.some((w) => padded.includes(pad(w)))) return { categoryName: match, source: "rules" as const };
    }
    const direct = categoryNames.find((name) => {
      const nameKey = normalizeTitle(name);
      return nameKey.length >= 3 && padded.includes(` ${nameKey} `);
    });
    return direct ? { categoryName: direct, source: "rules" as const } : null;
  }

  suggest(title: string, categoryNames: string[]) {
    if (title.trim().length < 3) return null;
    return this.historySuggestion(title, categoryNames) ?? this.keywordSuggestion(title, categoryNames);
  }
}
