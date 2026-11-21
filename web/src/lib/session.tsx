"use client";

import { createContext, type ReactNode, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { LocalDb } from "./db/local-db";
import { setDb } from "./db/store";
import { SupabaseDb } from "./db/supabase-db";
import { type Fixture, seedDemo } from "./demo/seed";
import { hasSupabase, supabase } from "./supabase";

type Status = "loading" | "signedOut" | "cloud" | "demo";

interface Session {
  status: Status;
  email: string | null;
  /** Envia o email de entrada (cria a conta se não existir). */
  sendLink(email: string): Promise<void>;
  /** Entra com o link do email colado (ou o regresso do link a esta app). */
  signInWithLink(link: string): Promise<void>;
  signOut(): Promise<void>;
  startDemo(): void;
  leaveDemo(): void;
}

const SessionContext = createContext<Session | null>(null);
const MODE_KEY = "mynik.mode";

const asset = (path: string) => fetch(path).then((r) => {
  if (!r.ok) throw new Error(`Não foi possível carregar ${path}`);
  return r.json();
});

function makeDemoDb() {
  return new LocalDb(
    () => asset("/demo/migrations.json") as Promise<string[]>,
    async (db, user) => seedDemo(db, user, (await asset("/demo/fixture.json")) as Fixture),
  );
}

function readMode() {
  try {
    return localStorage.getItem(MODE_KEY);
  } catch {
    return null;
  }
}

function writeMode(mode: string | null) {
  try {
    if (mode) localStorage.setItem(MODE_KEY, mode);
    else localStorage.removeItem(MODE_KEY);
  } catch {
    // Sem armazenamento (janela privada): a escolha dura só esta sessão.
  }
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<Status>("loading");
  const [email, setEmail] = useState<string | null>(null);

  const enterDemo = useCallback(() => {
    setDb(makeDemoDb());
    setEmail(null);
    setStatus("demo");
  }, []);

  useEffect(() => {
    if (!hasSupabase || readMode() === "demo") {
      enterDemo();
      if (!hasSupabase) return;
    }
    const client = supabase();
    let active = true;
    void client.auth.getSession().then(({ data }) => {
      if (!active || readMode() === "demo") return;
      if (data.session) {
        setDb(new SupabaseDb(client));
        setEmail(data.session.user.email ?? null);
        setStatus("cloud");
      } else {
        setDb(null);
        setStatus("signedOut");
      }
    });
    const { data } = client.auth.onAuthStateChange((event, session) => {
      if (readMode() === "demo") return;
      if (event === "SIGNED_IN" && session) {
        setDb(new SupabaseDb(client));
        setEmail(session.user.email ?? null);
        setStatus("cloud");
      } else if (event === "SIGNED_OUT") {
        setDb(null);
        setEmail(null);
        setStatus("signedOut");
      }
    });
    return () => {
      active = false;
      data.subscription.unsubscribe();
    };
  }, [enterDemo]);

  const value = useMemo<Session>(
    () => ({
      status,
      email,
      async sendLink(address) {
        const { error } = await supabase().auth.signInWithOtp({
          email: address.trim(),
          options: { emailRedirectTo: `${window.location.origin}/auth/callback/` },
        });
        if (error) throw error;
      },
      async signInWithLink(link) {
        const client = supabase();
        const url = new URL(link.trim());
        const hash = new URLSearchParams(url.hash.replace(/^#/, ""));
        const accessToken = hash.get("access_token");
        const refreshToken = hash.get("refresh_token");
        if (accessToken && refreshToken) {
          const { error } = await client.auth.setSession({ access_token: accessToken, refresh_token: refreshToken });
          if (error) throw error;
          return;
        }
        // O próprio link do email: …/auth/v1/verify?token=…&type=magiclink
        const token = url.searchParams.get("token_hash") ?? url.searchParams.get("token");
        const type = (url.searchParams.get("type") ?? "magiclink") as "magiclink" | "email" | "signup";
        if (token) {
          const { error } = await client.auth.verifyOtp({ token_hash: token, type });
          if (error) throw error;
          return;
        }
        throw new Error("Este link não tem os dados de entrada. Copia o link completo do email.");
      },
      async signOut() {
        writeMode(null);
        if (hasSupabase) await supabase().auth.signOut();
        setDb(null);
        setStatus(hasSupabase ? "signedOut" : "demo");
        if (!hasSupabase) enterDemo();
      },
      startDemo() {
        writeMode("demo");
        enterDemo();
      },
      leaveDemo() {
        writeMode(null);
        setDb(null);
        if (!hasSupabase) return;
        void supabase()
          .auth.getSession()
          .then(({ data }) => {
            if (data.session) {
              setDb(new SupabaseDb(supabase()));
              setEmail(data.session.user.email ?? null);
              setStatus("cloud");
            } else {
              setStatus("signedOut");
            }
          });
      },
    }),
    [status, email, enterDemo],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession() {
  const session = useContext(SessionContext);
  if (!session) throw new Error("useSession fora do SessionProvider");
  return session;
}
