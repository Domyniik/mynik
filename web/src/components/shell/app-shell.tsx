"use client";

import { usePathname, useRouter } from "next/navigation";
import { type ReactNode, useEffect, useState } from "react";
import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { useSession } from "@/lib/session";
import { CommandMenu } from "./command-menu";
import { sectionFor, sections, settingsSection } from "./nav";
import { Sidebar } from "./sidebar";

const PUBLIC_ROUTES = ["/login", "/auth"];

/** Abre o ⌘K de qualquer sítio (botão do Hoje, atalho global do Tauri). */
export function openCommandMenu() {
  window.dispatchEvent(new CustomEvent("mynik:command-menu"));
}

/**
 * Janela da app: sidebar, conteúdo e o ⌘K. Atalhos:
 * ⌘K procurar · ⌘N novo item da secção · ⌘1–⌘9 secções · ⌘, definições.
 */
export function AppShell({ children }: { children: ReactNode }) {
  const { status } = useSession();
  const pathname = usePathname();
  const router = useRouter();
  const [commandOpen, setCommandOpen] = useState(false);
  const isPublic = PUBLIC_ROUTES.some((r) => pathname.startsWith(r));

  useEffect(() => {
    if (status === "signedOut" && !isPublic) router.replace("/login/");
  }, [status, isPublic, router]);

  useEffect(() => {
    const open = () => setCommandOpen(true);
    const onKey = (event: KeyboardEvent) => {
      const mod = event.metaKey || event.ctrlKey;
      if (!mod || event.altKey) return;
      const key = event.key.toLowerCase();
      if (key === "k") {
        event.preventDefault();
        setCommandOpen((v) => !v);
      } else if (key === "n" && !event.shiftKey) {
        event.preventDefault();
        const section = sectionFor(pathname);
        router.push(section?.newLabel ? `${section.href}?novo=1` : "/financas/?novo=gasto");
      } else if (key === ",") {
        event.preventDefault();
        router.push(settingsSection.href);
      } else if (/^[1-9]$/.test(key) && !event.shiftKey) {
        event.preventDefault();
        router.push(sections[Number(key) - 1].href);
      }
    };
    window.addEventListener("keydown", onKey);
    window.addEventListener("mynik:command-menu", open);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("mynik:command-menu", open);
    };
  }, [pathname, router]);

  if (isPublic) {
    return (
      <>
        {children}
        <Toaster theme="dark" richColors />
      </>
    );
  }

  if (status === "loading" || status === "signedOut") {
    return (
      <div className="flex h-dvh items-center justify-center text-muted-foreground" role="status">
        A abrir o Mynik…
      </div>
    );
  }

  return (
    <TooltipProvider>
      <div className="flex h-dvh overflow-hidden">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto">
          <div className="mx-auto flex max-w-[1400px] flex-col gap-6 px-9 pb-10 pt-7">{children}</div>
        </main>
      </div>
      <CommandMenu open={commandOpen} onOpenChange={setCommandOpen} />
      <Toaster theme="dark" richColors position="bottom-right" />
    </TooltipProvider>
  );
}
