"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { ArrowRight, Briefcase, Home } from "lucide-react";
import { AuthShell, nextPath } from "@/components/auth-shell";
import { Field } from "@/components/ui";
import { useBackend } from "@/lib/hooks";

export default function SignUpPage() {
  const backend = useBackend();
  const router = useRouter();
  const [kind, setKind] = useState<"business" | "tenant">("business");
  const [form, setForm] = useState({ name: "", email: "", phone: "", password: "" });
  const [agree, setAgree] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const k = new URLSearchParams(window.location.search).get("kind");
    if (k === "tenant" || k === "business") setKind(k);
  }, []);

  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) => setForm((f) => ({ ...f, [k]: e.target.value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!agree) {
      setError("Please accept the terms to continue.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await backend.signUp({ kind, ...form });
      router.replace(nextPath());
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setBusy(false);
    }
  };

  return (
    <AuthShell>
      <h1 style={{ fontSize: 26, fontWeight: 800, letterSpacing: "-0.02em" }}>Create your account</h1>
      <p className="muted" style={{ marginTop: 6, marginBottom: 20 }}>
        It takes less than a minute.
      </p>
      <div className="role-pick" role="radiogroup" aria-label="Account type" style={{ marginBottom: 18 }}>
        <button type="button" role="radio" aria-pressed={kind === "business"} aria-checked={kind === "business"} onClick={() => setKind("business")}>
          <Briefcase size={20} color="var(--brand)" />
          <b>I own or manage a PG</b>
          <small>Properties, tenants, rent</small>
        </button>
        <button type="button" role="radio" aria-pressed={kind === "tenant"} aria-checked={kind === "tenant"} onClick={() => setKind("tenant")}>
          <Home size={20} color="var(--brand)" />
          <b>I&apos;m a tenant</b>
          <small>Find a PG, pay rent</small>
        </button>
      </div>
      <form className="stack" onSubmit={submit}>
        <Field label="Full name">
          <input className="input" required autoComplete="name" value={form.name} onChange={set("name")} placeholder="Your name" />
        </Field>
        <Field label="Email">
          <input className="input" type="email" required autoComplete="email" value={form.email} onChange={set("email")} placeholder="you@example.com" />
        </Field>
        <Field label="Mobile number" hint={kind === "tenant" ? "Owners invite you by this number." : "Team invites are matched to this number."}>
          <input className="input" type="tel" required inputMode="numeric" autoComplete="tel" value={form.phone} onChange={set("phone")} placeholder="98765 43210" />
        </Field>
        <Field label="Password" hint="At least 6 characters.">
          <input className="input" type="password" required minLength={6} autoComplete="new-password" value={form.password} onChange={set("password")} placeholder="••••••••" />
        </Field>
        <label className="check" style={{ fontSize: 13 }}>
          <input type="checkbox" checked={agree} onChange={(e) => setAgree(e.target.checked)} />
          <span className="muted">I agree to the Terms of Service and Privacy Policy.</span>
        </label>
        {error && <div className="alert alert-red">{error}</div>}
        <button className="btn btn-primary btn-block btn-lg" disabled={busy}>
          {busy ? "Creating account…" : kind === "business" ? "Create owner account" : "Create tenant account"} <ArrowRight size={18} />
        </button>
      </form>
      <p className="muted" style={{ marginTop: 20, fontSize: 14, textAlign: "center" }}>
        Already have an account?{" "}
        <Link href="/signin/" style={{ color: "var(--brand)", fontWeight: 650 }}>
          Sign in
        </Link>
      </p>
    </AuthShell>
  );
}
