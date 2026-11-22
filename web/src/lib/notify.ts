"use client";

import { toast } from "sonner";

/**
 * Notificação: nativa na app desktop (Tauri, ligada na etapa 4 por
 * `window.__MYNIK_NOTIFY__`), notificação do browser se houver permissão, e
 * sempre um aviso dentro da app.
 */
export function notify(title: string, body: string) {
  toast(title, { description: body });
  const native = (window as unknown as { __MYNIK_NOTIFY__?: (t: string, b: string) => void }).__MYNIK_NOTIFY__;
  if (native) {
    native(title, body);
    return;
  }
  if (typeof Notification !== "undefined" && Notification.permission === "granted" && document.hidden) {
    new Notification(title, { body });
  }
}
