"use client";

/**
 * Bloqueio local por PIN (o Face ID do iPhone no desktop): protege os números
 * e as fotos dos documentos e, se ligado, a abertura da app. O PIN só existe
 * neste computador, guardado como hash SHA-256 com sal.
 */
const PIN_KEY = "mynik.pin";
const APP_LOCK_KEY = "mynik.appLock";
export const GRACE_MS = 5 * 60_000;

async function hash(pin: string, salt: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${salt}:${pin}`));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function read(key: string) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

export const hasPin = () => Boolean(read(PIN_KEY));
export const appLockEnabled = () => read(APP_LOCK_KEY) === "1" && hasPin();

export async function setPin(pin: string) {
  const salt = crypto.randomUUID();
  localStorage.setItem(PIN_KEY, JSON.stringify({ salt, hash: await hash(pin, salt) }));
}

export function removePin() {
  localStorage.removeItem(PIN_KEY);
  localStorage.removeItem(APP_LOCK_KEY);
}

export function setAppLock(enabled: boolean) {
  localStorage.setItem(APP_LOCK_KEY, enabled ? "1" : "0");
}

export async function checkPin(pin: string) {
  const stored = read(PIN_KEY);
  if (!stored) return true;
  const { salt, hash: expected } = JSON.parse(stored) as { salt: string; hash: string };
  return (await hash(pin, salt)) === expected;
}

// ---------- Fotos dos documentos (só neste computador, IndexedDB) ----------
const DB_NAME = "mynik-documents";

function openPhotos(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => request.result.createObjectStore("photos", { keyPath: "id" }).createIndex("document", "documentID");
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export interface LocalPhoto {
  id: string;
  documentID: string;
  blob: Blob;
  createdAt: number;
}

export async function listPhotos(documentID: string): Promise<LocalPhoto[]> {
  const db = await openPhotos();
  return new Promise((resolve, reject) => {
    const request = db.transaction("photos").objectStore("photos").index("document").getAll(documentID);
    request.onsuccess = () => resolve((request.result as LocalPhoto[]).sort((a, b) => a.createdAt - b.createdAt));
    request.onerror = () => reject(request.error);
  });
}

export async function addPhoto(documentID: string, blob: Blob) {
  const db = await openPhotos();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction("photos", "readwrite");
    tx.objectStore("photos").put({ id: crypto.randomUUID(), documentID, blob, createdAt: Date.now() });
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export async function deletePhoto(id: string) {
  const db = await openPhotos();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction("photos", "readwrite");
    tx.objectStore("photos").delete(id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}
