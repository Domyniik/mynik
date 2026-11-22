"use client";

import { Lock } from "lucide-react";
import { type FormEvent, type ReactNode, useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { appLockEnabled, checkPin, GRACE_MS } from "@/lib/lock";

/** Bloqueio da app por PIN (o "Pedir Face ID ao abrir" do iPhone). Volta a bloquear depois de 5 min fora. */
export function LockGate({ children }: { children: ReactNode }) {
  const [locked, setLocked] = useState(false);
  const [pin, setPin] = useState("");
  const [error, setError] = useState(false);
  const hiddenAt = useRef<number | null>(null);
  useEffect(() => {
    setLocked(appLockEnabled());
    const onVisibility = () => {
      if (document.hidden) hiddenAt.current = Date.now();
      else if (hiddenAt.current && Date.now() - hiddenAt.current > GRACE_MS && appLockEnabled()) setLocked(true);
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, []);
  if (!locked) return <>{children}</>;
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (await checkPin(pin)) {
      setLocked(false);
      setPin("");
    } else setError(true);
  };
  return (
    <main className="flex h-dvh items-center justify-center">
      <form onSubmit={submit} className="flex w-72 flex-col items-center gap-4">
        <Lock size={32} aria-hidden="true" className="text-muted-foreground" />
        <h1 className="m-0 text-xl font-semibold">Mynik bloqueado</h1>
        <Input type="password" inputMode="numeric" autoFocus aria-label="PIN" value={pin} onChange={(e) => { setPin(e.target.value); setError(false); }} />
        {error && <p className="m-0 text-sm text-danger" role="alert">PIN errado</p>}
        <Button type="submit" className="w-full">Desbloquear</Button>
      </form>
    </main>
  );
}
