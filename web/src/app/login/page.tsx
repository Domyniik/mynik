"use client";

import { Mail, Sparkles } from "lucide-react";
import { useRouter } from "next/navigation";
import { type FormEvent, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useSession } from "@/lib/session";
import { hasSupabase } from "@/lib/supabase";

/** Entrada por magic link (o mesmo login do iPhone) ou modo de demonstração. */
export default function LoginPage() {
  const session = useSession();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [link, setLink] = useState("");
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (session.status === "cloud" || session.status === "demo") router.replace("/hoje/");
  }, [session.status, router]);

  async function run(action: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  const send = (event: FormEvent) => {
    event.preventDefault();
    void run(async () => {
      await session.sendLink(email);
      setSentTo(email.trim());
    });
  };

  const paste = (event: FormEvent) => {
    event.preventDefault();
    void run(() => session.signInWithLink(link));
  };

  return (
    <main className="flex min-h-dvh items-center justify-center px-4">
      <div className="flex w-full max-w-sm flex-col gap-6">
        <div className="flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-xl bg-primary text-lg font-bold text-white">M</div>
          <div>
            <h1 className="m-0 text-2xl font-bold tracking-tight">Mynik</h1>
            <p className="m-0 text-muted-foreground">A tua vida num só sítio</p>
          </div>
        </div>

        {hasSupabase && (
          <section className="flex flex-col gap-4 rounded-[14px] border border-border bg-card p-5">
            {sentTo ? (
              <form onSubmit={paste} className="flex flex-col gap-3">
                <p className="m-0">
                  Enviámos um link para <strong>{sentTo}</strong>. Abre-o neste computador ou cola-o aqui.
                </p>
                <Label htmlFor="link">Link do email</Label>
                <Input id="link" value={link} onChange={(e) => setLink(e.target.value)} placeholder="https://…supabase.co/auth/v1/verify?…" />
                <Button type="submit" disabled={busy || !link.trim()}>Entrar</Button>
                <Button type="button" variant="ghost" onClick={() => setSentTo(null)}>Usar outro email</Button>
              </form>
            ) : (
              <form onSubmit={send} className="flex flex-col gap-3">
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="nome@exemplo.com" />
                <Button type="submit" disabled={busy}>
                  <Mail aria-hidden="true" /> Enviar link de entrada
                </Button>
                <p className="m-0 text-xs text-muted-foreground">A mesma conta do iPhone: os dados aparecem nos dois.</p>
              </form>
            )}
            {error && <p className="m-0 text-sm text-danger" role="alert">{error}</p>}
          </section>
        )}

        <Button variant="outline" onClick={() => session.startDemo()}>
          <Sparkles aria-hidden="true" /> Experimentar com dados de exemplo
        </Button>
      </div>
    </main>
  );
}
