"use client";

/**
 * Ponte para a app desktop (Tauri, pasta /desktop). No browser nada disto
 * existe e a web funciona igual; dentro da app, `window.__TAURI__` dá acesso
 * aos comandos nativos (notificações, tray, iniciar com o sistema…).
 */
type Unlisten = () => void;
interface TauriGlobal {
  core: { invoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> };
  event: { listen<T>(event: string, handler: (e: { payload: T }) => void): Promise<Unlisten> };
}

function tauri(): TauriGlobal | undefined {
  return typeof window === "undefined" ? undefined : (window as unknown as { __TAURI__?: TauriGlobal }).__TAURI__;
}

export const isDesktop = () => tauri() != null;

/** Para onde o link do email volta: a app (deep link) ou a página web. */
export function authRedirectURL() {
  return isDesktop() ? "mynik://auth/callback" : `${window.location.origin}/auth/callback/`;
}

export async function setTraySales(text: string, short: string) {
  await tauri()?.core.invoke("set_tray_sales", { text, short }).catch(() => undefined);
}

export async function autostartEnabled() {
  return (await tauri()?.core.invoke<boolean>("autostart_enabled").catch(() => false)) ?? false;
}

export async function setAutostart(enabled: boolean) {
  await tauri()?.core.invoke("set_autostart", { enabled });
}

/**
 * Liga a app nativa à web: notificações e leitura do iCal pelos ganchos
 * `__MYNIK_NOTIFY__` / `__MYNIK_FETCH_TEXT__`, eventos do tray e do atalho
 * global, login por deep link e links externos no browser do sistema.
 */
export function installDesktopBridge(handlers: {
  openCommandMenu: () => void;
  navigate: (path: string) => void;
  signInWithLink: (link: string) => Promise<void>;
  onLoginError: (message: string) => void;
}): Unlisten {
  const t = tauri();
  if (!t) return () => undefined;
  const w = window as unknown as Record<string, unknown>;
  w.__MYNIK_NOTIFY__ = (title: string, body: string) => void t.core.invoke("notify", { title, body }).catch(() => undefined);
  w.__MYNIK_FETCH_TEXT__ = (url: string) => t.core.invoke<string>("fetch_text", { url });

  const used = new Set<string>();
  const login = (url: string) => {
    if (!url.startsWith("mynik://auth") || used.has(url)) return;
    used.add(url);
    handlers.signInWithLink(url).catch((e) => handlers.onLoginError(e instanceof Error ? e.message : String(e)));
  };
  const pending: Promise<Unlisten>[] = [
    t.event.listen<string>("mynik://command-menu", () => handlers.openCommandMenu()),
    t.event.listen<string>("mynik://navigate", (e) => handlers.navigate(e.payload)),
    t.event.listen<string>("mynik://deep-link", (e) => login(e.payload)),
  ];
  // A app pode ter sido aberta pelo próprio link do email (antes de esta página existir).
  void t.core.invoke<string | null>("take_pending_link").then((url) => url && login(url)).catch(() => undefined);

  // Links para fora (Shopify, Google, …) abrem no browser do sistema.
  const onClick = (event: MouseEvent) => {
    const a = (event.target as HTMLElement | null)?.closest?.("a[href]") as HTMLAnchorElement | null;
    if (!a) return;
    const href = a.href;
    if (/^(https?:|mailto:)/.test(href) && !href.startsWith(window.location.origin)) {
      event.preventDefault();
      void t.core.invoke("open_external", { url: href }).catch(() => undefined);
    }
  };
  document.addEventListener("click", onClick, true);

  return () => {
    document.removeEventListener("click", onClick, true);
    for (const p of pending) void p.then((off) => off());
  };
}
