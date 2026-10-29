// Formatting helpers: INR, dates, months, initials.

const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 });
const inrCompact = new Intl.NumberFormat("en-IN", { notation: "compact", maximumFractionDigits: 1 });

export const money = (n: number) => inr.format(Math.round(n || 0));
export const moneyCompact = (n: number) => "₹" + inrCompact.format(Math.round(n || 0));

export const DAY = 86_400_000;

export function date(ms?: number) {
  if (!ms) return "—";
  return new Date(ms).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
}

export function dateShort(ms?: number) {
  if (!ms) return "—";
  return new Date(ms).toLocaleDateString("en-IN", { day: "numeric", month: "short" });
}

export function dateTime(ms?: number) {
  if (!ms) return "—";
  return new Date(ms).toLocaleString("en-IN", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit" });
}

export function ago(ms: number) {
  const s = Math.max(1, Math.round((Date.now() - ms) / 1000));
  if (s < 60) return "just now";
  const m = Math.round(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.round(h / 24);
  if (d < 30) return `${d}d ago`;
  return dateShort(ms);
}

/** "March 2026" — the month label rent payments are matched on. */
export function monthLabel(d: Date) {
  return d.toLocaleDateString("en-US", { month: "long", year: "numeric" });
}

/** "2026-03" */
export function periodOf(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

export function monthShort(period: string) {
  const [y, m] = period.split("-").map(Number);
  return new Date(y, m - 1, 1).toLocaleDateString("en-US", { month: "short" });
}

export function initials(name: string) {
  return (
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((p) => p[0]!.toUpperCase())
      .join("") || "?"
  );
}

export function toInputDate(ms: number) {
  const d = new Date(ms);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function fromInputDate(v: string) {
  const [y, m, d] = v.split("-").map(Number);
  return new Date(y, (m || 1) - 1, d || 1).getTime();
}

export function startOfDay(ms: number) {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** Rent for the days between move-in and the first billing day. */
export function proratedRent(monthlyRent: number, moveIn: number, billingDay: number) {
  const start = new Date(startOfDay(moveIn));
  if (start.getDate() === billingDay) return 0;
  const next = new Date(start.getFullYear(), start.getMonth() + (start.getDate() > billingDay ? 1 : 0), billingDay);
  const days = Math.round((next.getTime() - start.getTime()) / DAY);
  const daysInMonth = new Date(start.getFullYear(), start.getMonth() + 1, 0).getDate();
  return Math.round((monthlyRent * days) / daysInMonth);
}

export function cls(...parts: (string | false | null | undefined)[]) {
  return parts.filter(Boolean).join(" ");
}

export function sharingLabel(n: number) {
  return n === 1 ? "Single" : n === 2 ? "Double sharing" : n === 3 ? "Triple sharing" : `${n} sharing`;
}

export function phoneDigits(p: string) {
  return p.replace(/\D/g, "").slice(-10);
}
