"use client";
// Shared building blocks: brand, theme switch, modal, toasts, states, badges,
// form fields. Pages compose these instead of styling one-off variants.
import Link from "next/link";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { AlertTriangle, CheckCircle2, Info, Moon, RotateCcw, Search, Sun, X, type LucideIcon } from "lucide-react";
import { applyTheme, effectiveDark, readTheme, useToasts, type ThemeChoice } from "@/lib/hooks";
import { cls } from "@/lib/format";

function BrandMark() {
  return (
    <span className="brand-mark">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/brand/mark-96.png" alt="" width={22} height={28} />
    </span>
  );
}

export function Brand({ href = "/", asLink = true }: { href?: string; asLink?: boolean }) {
  const inner = (
    <>
      <BrandMark />
      <span>
        OneStay<b>360</b>
      </span>
    </>
  );
  if (!asLink) return <span className="brand">{inner}</span>;
  return (
    <Link href={href} className="brand" aria-label="OneStay360 home">
      {inner}
    </Link>
  );
}

export function Aurora() {
  return (
    <div className="aurora" aria-hidden>
      <span />
      <span />
    </div>
  );
}

function useTheme() {
  const [choice, setChoice] = useState<ThemeChoice>("system");
  const [dark, setDark] = useState(false);
  useEffect(() => {
    const c = readTheme();
    setChoice(c);
    setDark(effectiveDark(c));
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setDark(effectiveDark(readTheme()));
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);
  const set = (c: ThemeChoice) => {
    applyTheme(c);
    setChoice(c);
    setDark(effectiveDark(c));
  };
  return { choice, dark, set };
}

/** One click switches between light and dark; the label says which you'll get. */
export function ThemeToggle({ withLabel = false }: { withLabel?: boolean }) {
  const { dark, set } = useTheme();
  const label = dark ? "Switch to light theme" : "Switch to dark theme";
  const Icon = dark ? Sun : Moon;
  if (withLabel) {
    return (
      <button className="btn btn-ghost btn-sm" onClick={() => set(dark ? "light" : "dark")}>
        <Icon size={17} aria-hidden /> {dark ? "Light theme" : "Dark theme"}
      </button>
    );
  }
  return (
    <button className="icon-btn" onClick={() => set(dark ? "light" : "dark")} aria-label={label} title={label}>
      <Icon size={18} />
    </button>
  );
}

/** Explicit Light / Dark / Match device choice, for settings screens. */
export function ThemePicker() {
  const { choice, set } = useTheme();
  return (
    <Segmented<ThemeChoice>
      label="Theme"
      value={choice}
      onChange={set}
      options={[
        { value: "light", label: "Light" },
        { value: "dark", label: "Dark" },
        { value: "system", label: "Match device" },
      ]}
    />
  );
}

export function Modal({ title, subtitle, onClose, children, footer, wide }: { title: string; subtitle?: ReactNode; onClose: () => void; children: ReactNode; footer?: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const opener = document.activeElement as HTMLElement | null;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      // Only the top-most modal closes.
      const all = document.querySelectorAll(".modal");
      if (all[all.length - 1] === ref.current) onClose();
    };
    document.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    ref.current?.querySelector<HTMLElement>("input, select, textarea, button:not(.modal-x)")?.focus();
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
      opener?.focus?.();
    };
  }, [onClose]);
  return (
    <div className="modal-scrim" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div ref={ref} className={cls("modal", wide && "wide")} role="dialog" aria-modal="true" aria-label={title}>
        <div className="modal-head">
          <div>
            <h2>{title}</h2>
            {subtitle && <p className="muted" style={{ marginTop: 6 }}>{subtitle}</p>}
          </div>
          <button className="icon-btn modal-x" onClick={onClose} aria-label="Close dialog">
            <X size={18} />
          </button>
        </div>
        {children}
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>
  );
}

export function Toasts() {
  const items = useToasts();
  return (
    <div className="toasts" role="status" aria-live="polite">
      {items.map((t) => (
        <div key={t.id} className={cls("toast", t.tone)}>
          {t.tone === "success" ? <CheckCircle2 size={18} /> : t.tone === "error" ? <AlertTriangle size={18} /> : <Info size={18} />}
          <span>{t.text}</span>
        </div>
      ))}
    </div>
  );
}

export function Empty({ icon: Icon, title, body, action }: { icon: LucideIcon; title: string; body?: ReactNode; action?: ReactNode }) {
  return (
    <div className="empty">
      <span className="tile-ic grey">
        <Icon size={26} />
      </span>
      <b>{title}</b>
      {body && <p>{body}</p>}
      {action && <div style={{ marginTop: 4 }}>{action}</div>}
    </div>
  );
}

export function Loading({ rows = 3, label = "Loading" }: { rows?: number; label?: string }) {
  return (
    <div className="stack" role="status" aria-busy="true" aria-label={label}>
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="skeleton" style={{ height: 64 }} />
      ))}
      <span className="sr-only">{label}…</span>
    </div>
  );
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="alert alert-red row-between wrap" role="alert">
      <span className="row" style={{ gap: 10 }}>
        <AlertTriangle size={18} /> <span>{message}</span>
      </span>
      {onRetry && (
        <button className="btn btn-sm btn-ghost" onClick={onRetry}>
          <RotateCcw size={15} aria-hidden /> Try again
        </button>
      )}
    </div>
  );
}

type Tone = "green" | "amber" | "red" | "blue" | "grey";
export function Badge({ tone, children }: { tone: Tone; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

const statusTones: Record<string, [Tone, string]> = {
  paid: ["green", "Paid"],
  unpaid: ["blue", "Due"],
  overdue: ["red", "Overdue"],
  pending: ["amber", "Pending"],
  rejected: ["red", "Rejected"],
  approved: ["blue", "Approved"],
  bill_sent: ["blue", "Bill sent"],
  payment_submitted: ["amber", "Payment to verify"],
  confirmed: ["green", "Confirmed"],
  open: ["amber", "Open"],
  in_progress: ["blue", "In progress"],
  resolved: ["green", "Resolved"],
  cancelled: ["grey", "Cancelled"],
  active: ["green", "Active"],
  vacated: ["grey", "Vacated"],
  invited: ["amber", "Invite sent"],
  accepted: ["green", "Accepted"],
  payment_due: ["amber", "Not activated"],
  grace: ["amber", "Grace period"],
  past_due: ["red", "Past due"],
  suspended: ["red", "Suspended"],
  inactive: ["grey", "Hidden from Explore"],
  due: ["amber", "Due"],
  not_started: ["grey", "Not started"],
  submitted: ["amber", "In review"],
  verified: ["green", "Verified"],
};

export function StatusBadge({ status }: { status: string }) {
  const [tone, label] = statusTones[status] ?? ["grey", status];
  return <Badge tone={tone}>{label}</Badge>;
}

export function Kpi({ icon: Icon, label, value, hint, tone }: { icon: LucideIcon; label: string; value: ReactNode; hint?: ReactNode; tone?: "amber" | "red" | "blue" }) {
  return (
    <div className="glass kpi">
      <div className="label">
        <span className={cls("tile-ic", tone)} style={{ width: 32, height: 32, borderRadius: 9 }} aria-hidden>
          <Icon size={17} />
        </span>
        {label}
      </div>
      <div className="value num">{value}</div>
      {hint && <div className="hint">{hint}</div>}
    </div>
  );
}

/** A labelled control. The label stays visible above the input; hints and
 *  errors sit right under it. */
export function Field({ label, hint, error, required, children, full }: { label: string; hint?: ReactNode; error?: string | null; required?: boolean; children: ReactNode; full?: boolean }) {
  return (
    <label className={cls("field", full && "full")}>
      <span className="field-label">
        {label}
        {required && <span className="req">Required</span>}
      </span>
      {children}
      {error ? (
        <span className="field-error" role="alert">
          {error}
        </span>
      ) : (
        hint && <span className="field-hint">{hint}</span>
      )}
    </label>
  );
}

/** A labelled group of non-input controls (chips, choice cards). */
export function FieldGroup({ label, hint, children, full }: { label: string; hint?: ReactNode; children: ReactNode; full?: boolean }) {
  return (
    <div className={cls("field", full && "full")} role="group" aria-label={label}>
      <span className="field-label">{label}</span>
      {children}
      {hint && <span className="field-hint">{hint}</span>}
    </div>
  );
}

export function Segmented<T extends string>({ value, onChange, options, label }: { value: T; onChange: (v: T) => void; options: { value: T; label: ReactNode }[]; label?: string }) {
  return (
    <div className="seg" role="tablist" aria-label={label}>
      {options.map((o) => (
        <button key={o.value} role="tab" aria-selected={value === o.value} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Adds .in to .reveal elements as they scroll into view. */
export function useReveal() {
  useEffect(() => {
    const els = document.querySelectorAll(".reveal:not(.in)");
    if (!("IntersectionObserver" in window) || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      els.forEach((e) => e.classList.add("in"));
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        for (const en of entries) {
          if (en.isIntersecting) {
            en.target.classList.add("in");
            io.unobserve(en.target);
          }
        }
      },
      { threshold: 0.08, rootMargin: "0px 0px -40px 0px" },
    );
    els.forEach((e) => io.observe(e));
    return () => io.disconnect();
  });
}

export function Confirm({ title, body, confirmLabel, danger, onConfirm, onClose, busy, children }: { title: string; body?: ReactNode; confirmLabel: string; danger?: boolean; onConfirm: () => void; onClose: () => void; busy?: boolean; children?: ReactNode }) {
  return (
    <Modal
      title={title}
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          <button className={cls("btn", danger ? "btn-danger" : "btn-primary")} onClick={onConfirm} disabled={busy}>
            {confirmLabel}
          </button>
        </>
      }
    >
      <div className="stack">
        {body && <p className="muted">{body}</p>}
        {children}
      </div>
    </Modal>
  );
}

/** A labelled search box with a leading icon. */
export function SearchField({ label, value, onChange, placeholder }: { label: string; value: string; onChange: (v: string) => void; placeholder?: string }) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      <span style={{ position: "relative", display: "block" }}>
        <Search size={17} aria-hidden style={{ position: "absolute", left: 14, top: 15, color: "var(--ink-faint)" }} />
        <input className="input" type="search" value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} style={{ paddingLeft: 42 }} />
      </span>
    </label>
  );
}
