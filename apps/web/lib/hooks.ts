"use client";
// Data hooks: every query re-runs when the backend reports a change, so a
// mutation on one screen (or in another tab) refreshes all open screens.
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";
import { getBackend } from "./backend";
import type { Backend } from "./backend";
import type { Account } from "./types";

export function useBackend(): Backend {
  return getBackend();
}

let version = 0;
const versionListeners = new Set<() => void>();
let wired = false;
function wire() {
  if (wired || typeof window === "undefined") return;
  wired = true;
  getBackend().subscribe(() => {
    version++;
    for (const l of versionListeners) l();
  });
}

/** Increments whenever backend data changes. */
export function useDataVersion() {
  wire();
  return useSyncExternalStore(
    (cb) => {
      versionListeners.add(cb);
      return () => versionListeners.delete(cb);
    },
    () => version,
    () => 0,
  );
}

export function useAccount(): { account: Account | null; loading: boolean } {
  const v = useDataVersion();
  const [state, setState] = useState<{ account: Account | null; loading: boolean }>({ account: null, loading: true });
  useEffect(() => {
    let alive = true;
    const b = getBackend();
    b.ready().then(() => {
      if (alive) setState({ account: b.currentAccount(), loading: false });
    });
    return () => {
      alive = false;
    };
  }, [v]);
  return state;
}

export interface Query<T> {
  data: T | undefined;
  error: string | null;
  loading: boolean;
  reload: () => void;
}

export function useQuery<T>(fn: (b: Backend) => Promise<T>, deps: unknown[] = []): Query<T> {
  const v = useDataVersion();
  const [data, setData] = useState<T | undefined>(undefined);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [nonce, setNonce] = useState(0);
  const fnRef = useRef(fn);
  fnRef.current = fn;

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fnRef
      .current(getBackend())
      .then((d) => {
        if (!alive) return;
        setData(d);
        setError(null);
      })
      .catch((e: unknown) => {
        if (!alive) return;
        setError(e instanceof Error ? e.message : String(e));
      })
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [v, nonce, ...deps]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);
  return { data, error, loading: loading && data === undefined, reload };
}

/** Runs a mutation, tracking busy state and turning failures into toasts. */
export function useAction() {
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  const run = useCallback(
    async <T,>(fn: (b: Backend) => Promise<T>, success?: string): Promise<{ ok: true; value: T } | { ok: false; value?: undefined }> => {
      setBusy(true);
      // The button that started the action shows a spinner until it settles.
      const trigger = typeof document !== "undefined" && document.activeElement instanceof HTMLButtonElement ? document.activeElement : null;
      trigger?.setAttribute("aria-busy", "true");
      try {
        const value = await fn(getBackend());
        if (success) toast(success, "success");
        return { ok: true, value };
      } catch (e) {
        toast(e instanceof Error ? e.message : String(e), "error");
        return { ok: false };
      } finally {
        trigger?.removeAttribute("aria-busy");
        setBusy(false);
      }
    },
    [toast],
  );
  return { busy, run };
}

// ── Toasts ───────────────────────────────────────────────

export type ToastTone = "success" | "error" | "info";
export interface ToastItem {
  id: number;
  text: string;
  tone: ToastTone;
}
let toasts: ToastItem[] = [];
const toastListeners = new Set<() => void>();
let toastSeq = 0;

export function pushToast(text: string, tone: ToastTone = "info") {
  const id = ++toastSeq;
  toasts = [...toasts, { id, text, tone }].slice(-4);
  toastListeners.forEach((l) => l());
  setTimeout(() => {
    toasts = toasts.filter((t) => t.id !== id);
    toastListeners.forEach((l) => l());
  }, 4200);
}

export function useToast() {
  return pushToast;
}

export function useToasts() {
  return useSyncExternalStore(
    (cb) => {
      toastListeners.add(cb);
      return () => toastListeners.delete(cb);
    },
    () => toasts,
    () => toasts,
  );
}

// ── Theme ────────────────────────────────────────────────

export type ThemeChoice = "light" | "dark" | "system";
const THEME_KEY = "onestay360.theme";

export function readTheme(): ThemeChoice {
  try {
    const v = localStorage.getItem(THEME_KEY);
    return v === "light" || v === "dark" ? v : "system";
  } catch {
    return "system";
  }
}

export function applyTheme(choice: ThemeChoice) {
  const root = document.documentElement;
  if (choice === "system") root.removeAttribute("data-theme");
  else root.setAttribute("data-theme", choice);
  try {
    if (choice === "system") localStorage.removeItem(THEME_KEY);
    else localStorage.setItem(THEME_KEY, choice);
  } catch {
    // ignore
  }
}

export function effectiveDark(choice: ThemeChoice) {
  if (choice !== "system") return choice === "dark";
  return typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: dark)").matches;
}
