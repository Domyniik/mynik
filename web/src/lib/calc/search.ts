/** Texto para comparar: sem acentos nem maiúsculas. */
export function searchKey(text: string) {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase().trim();
}

/**
 * Pontuação de texto, como `SearchMatcher` no iPhone: começa por (0), uma
 * palavra começa por (1), contém (2); campos secundários valem menos (+3).
 * `null` quando não há correspondência.
 */
export function rank(query: string, fields: string[]): number | null {
  const key = searchKey(query);
  if (!key) return null;
  let best: number | null = null;
  fields.forEach((field, index) => {
    const text = searchKey(field ?? "");
    if (!text) return;
    const penalty = index === 0 ? 0 : 3;
    let score: number | null = null;
    if (text.startsWith(key)) score = 0;
    else if (text.split(/[^\p{L}\p{N}]+/u).some((word) => word.startsWith(key))) score = 1;
    else if (text.includes(key)) score = 2;
    if (score != null) best = Math.min(best ?? Number.MAX_SAFE_INTEGER, score + penalty);
  });
  return best;
}

export interface SearchResult {
  id: string;
  title: string;
  subtitle: string;
  href: string;
  rank: number;
}

export const SEARCH_LIMIT = 40;

/** Junta, ordena e corta os resultados (mínimo 2 caracteres). */
export function collect(query: string, candidates: { id: string; title: string; subtitle: string; href: string; fields: string[] }[]) {
  if (query.trim().length < 2) return [];
  const results: SearchResult[] = [];
  for (const c of candidates) {
    const r = rank(query, c.fields);
    if (r != null) results.push({ id: c.id, title: c.title, subtitle: c.subtitle, href: c.href, rank: r });
  }
  return results
    .sort((a, b) => a.rank - b.rank || a.title.localeCompare(b.title, "pt"))
    .slice(0, SEARCH_LIMIT);
}
