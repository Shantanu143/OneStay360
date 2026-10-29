"use client";
// Shared building blocks: brand, theme toggle, modal, toasts, states, badges.
import Link from "next/link";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { AlertTriangle, CheckCircle2, Info, Monitor, Moon, Sun, X, type LucideIcon } from "lucide-react";
import { applyTheme, effectiveDark, readTheme, useToasts, type ThemeChoice } from "@/lib/hooks";
import { cls } from "@/lib/format";

export function Brand({ href = "/", compact = false }: { href?: string; compact?: boolean }) {
  return (
    <Link href={href} className="brand" aria-label="OneStay360 home">
      <span className="brand-mark">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/mark.png" alt="" width={24} height={28} />
      </span>
      {!compact && (
        <span>
          OneStay<b>360</b>
        </span>
      )}
    </Link>
  );
}

export function Aurora() {
  return (
    <div className="aurora" aria-hidden>
      <span />
      <span />
      <span />
    </div>
  );
}

export function ThemeToggle({ withLabel = false }: { withLabel?: boolean }) {
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
  const next = () => {
    // Cycle: system → the opposite of what system shows → back to system.
    const order: ThemeChoice[] = dark ? ["system", "light", "dark"] : ["system", "dark", "light"];
    const n = order[(order.indexOf(choice) + 1) % order.length]!;
    applyTheme(n);
    setChoice(n);
    setDark(effectiveDark(n));
  };
  const Icon = choice === "system" ? Monitor : dark ? Moon : Sun;
  const label = choice === "system" ? "System theme" : dark ? "Dark theme" : "Light theme";
  if (withLabel) {
    return (
      <button className="btn btn-ghost btn-sm" onClick={next} aria-label={`${label}. Switch theme`}>
        <Icon size={16} /> {label}
      </button>
    );
  }
  return (
    <button className="icon-btn" onClick={next} aria-label={`${label}. Switch theme`} title={label}>
      <Icon size={18} />
    </button>
  );
}

export function Modal({ title, subtitle, onClose, children, footer, wide }: { title: string; subtitle?: ReactNode; onClose: () => void; children: ReactNode; footer?: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
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
    };
  }, [onClose]);
  return (
    <div className="modal-scrim" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div ref={ref} className={cls("modal glass", wide && "wide")} role="dialog" aria-modal="true" aria-label={title}>
        <div className="modal-head">
          <div>
            <h3>{title}</h3>
            {subtitle && <p className="muted" style={{ fontSize: 14, marginTop: 4 }}>{subtitle}</p>}
          </div>
          <button className="icon-btn modal-x" onClick={onClose} aria-label="Close">
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
        <div key={t.id} className={cls("toast glass", t.tone)}>
          {t.tone === "success" ? <CheckCircle2 size={18} /> : t.tone === "error" ? <AlertTriangle size={18} /> : <Info size={18} />}
          {t.text}
        </div>
      ))}
    </div>
  );
}

export function Empty({ icon: Icon, title, body, action }: { icon: LucideIcon; title: string; body?: ReactNode; action?: ReactNode }) {
  return (
    <div className="empty">
      <span className="tile-ic grey">
        <Icon size={24} />
      </span>
      <b style={{ color: "var(--ink)" }}>{title}</b>
      {body && <p style={{ maxWidth: 380, fontSize: 14 }}>{body}</p>}
      {action}
    </div>
  );
}

export function Loading({ rows = 3 }: { rows?: number }) {
  return (
    <div className="stack" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="skeleton" style={{ height: 56 }} />
      ))}
    </div>
  );
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="alert alert-red row-between">
      <span>{message}</span>
      {onRetry && (
        <button className="btn btn-sm btn-ghost" onClick={onRetry}>
          Retry
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
  invited: ["amber", "Invited"],
  accepted: ["green", "Accepted"],
  payment_due: ["amber", "Payment due"],
  grace: ["amber", "Grace period"],
  past_due: ["red", "Past due"],
  suspended: ["red", "Suspended"],
  inactive: ["grey", "Hidden"],
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
        <span className={cls("tile-ic", tone)} style={{ width: 30, height: 30, borderRadius: 9 }}>
          <Icon size={16} />
        </span>
        {label}
      </div>
      <div className="value num">{value}</div>
      {hint && <div className="hint">{hint}</div>}
    </div>
  );
}

export function Field({ label, hint, children, full }: { label: string; hint?: ReactNode; children: ReactNode; full?: boolean }) {
  return (
    <label className={cls("field", full && "full")}>
      <span>{label}</span>
      {children}
      {hint && <small>{hint}</small>}
    </label>
  );
}

export function Segmented<T extends string>({ value, onChange, options }: { value: T; onChange: (v: T) => void; options: { value: T; label: ReactNode }[] }) {
  return (
    <div className="seg" role="tablist">
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
    if (!("IntersectionObserver" in window)) {
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
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" },
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
      {body && <p className="muted">{body}</p>}
      {children}
    </Modal>
  );
}
