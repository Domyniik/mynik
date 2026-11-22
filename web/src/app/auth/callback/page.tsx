"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { useSession } from "@/lib/session";

/** Regresso do link do email: o supabase-js lê o #access_token e a sessão abre. */
export default function AuthCallback() {
  const { status } = useSession();
  const router = useRouter();
  useEffect(() => {
    if (status === "cloud") router.replace("/hoje/");
    if (status === "signedOut") {
      const timer = setTimeout(() => router.replace("/login/"), 4000);
      return () => clearTimeout(timer);
    }
  }, [status, router]);
  return <div className="flex h-dvh items-center justify-center text-muted-foreground" role="status">A entrar…</div>;
}
