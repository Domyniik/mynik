import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/** Configuração pública (a mesma chave anon do iPhone). Vazia = só modo de demonstração. */
export const supabaseConfig = {
  url: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "",
};

export const hasSupabase = Boolean(supabaseConfig.url && supabaseConfig.anonKey);

let client: SupabaseClient | null = null;

export function supabase(): SupabaseClient {
  if (!hasSupabase) throw new Error("Supabase não configurado (web/.env.local)");
  client ??= createClient(supabaseConfig.url, supabaseConfig.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      // Implícito (tokens no #): o link do email também pode ser colado na app
      // desktop, como no iPhone, mesmo que tenha aberto noutro browser.
      flowType: "implicit",
      storageKey: "mynik-auth",
    },
  });
  return client;
}
