"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { Briefcase, Eye, EyeOff, Home, UserCog } from "lucide-react";
import { AuthShell, nextPath } from "@/components/auth-shell";
import { Field } from "@/components/ui";
import { useBackend } from "@/lib/hooks";
import { DEMO_ACCOUNTS, DEMO_PASSWORD } from "@/lib/backend/demo/seed";

const demos = [
  { key: "owner", icon: Briefcase, label: "Owner", sub: "Asha · Sunrise Stays", email: DEMO_ACCOUNTS.owner },
  { key: "manager", icon: UserCog, label: "Manager", sub: "Vikram · 1 property", email: DEMO_ACCOUNTS.manager },
  { key: "tenant", icon: Home, label: "Tenant", sub: "Rahul · Room 101", email: DEMO_ACCOUNTS.tenant },
] as const;

export default function SignInPage() {
  const backend = useBackend();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const autoRan = useRef(false);

  const go = async (e: string, p: string) => {
    setBusy(true);
    setError(null);
    try {
      await backend.signIn(e, p);
      router.replace(nextPath());
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setBusy(false);
    }
  };

  useEffect(() => {
    if (autoRan.current) return;
    autoRan.current = true;
    const demo = new URLSearchParams(window.location.search).get("demo");
    const match = demos.find((d) => d.key === demo);
    if (match && backend.mode === "demo") {
      setEmail(match.email);
      setPassword(DEMO_PASSWORD);
      void go(match.email, DEMO_PASSWORD);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const [fieldErr, setFieldErr] = useState<{ email?: string; password?: string }>({});
  const submit = (e: FormEvent) => {
    e.preventDefault();
    const errs = {
      email: !email.trim() ? "Enter your email address." : !/^\S+@\S+\.\S+$/.test(email.trim()) ? "Enter a valid email, like name@example.com." : undefined,
      password: !password ? "Enter your password." : undefined,
    };
    setFieldErr(errs);
    if (errs.email || errs.password) return;
    void go(email, password);
  };

  return (
    <AuthShell>
      <h1 style={{ fontSize: 30, fontWeight: 800, letterSpacing: "-0.02em", lineHeight: 1.2 }}>Welcome back</h1>
      <p className="muted" style={{ marginTop: 8, marginBottom: 28 }}>
        Sign in to manage your PG or your stay.
      </p>
      <form className="stack" style={{ gap: 20 }} onSubmit={submit} noValidate>
        <Field label="Email address" required error={fieldErr.email}>
          <input className="input" type="email" autoComplete="email" required aria-invalid={!!fieldErr.email} value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" />
        </Field>
        <Field label="Password" required error={fieldErr.password}>
          <div style={{ position: "relative" }}>
            <input className="input" type={show ? "text" : "password"} autoComplete="current-password" required aria-invalid={!!fieldErr.password} value={password} onChange={(e) => setPassword(e.target.value)} style={{ paddingRight: 52 }} />
            <button type="button" onClick={() => setShow((s) => !s)} aria-label={show ? "Hide password" : "Show password"} aria-pressed={show} style={{ position: "absolute", right: 4, top: 3, width: 40, height: 40, border: 0, borderRadius: 10, background: "none", color: "var(--ink-soft)", display: "grid", placeItems: "center" }}>
              {show ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        </Field>
        {error && (
          <div className="alert alert-red" role="alert">
            {error}
          </div>
        )}
        <button className="btn btn-primary btn-block btn-lg" disabled={busy} aria-busy={busy}>
          {busy ? "Signing in…" : "Sign in"}
        </button>
      </form>

      {backend.mode === "demo" && (
        <>
          <div className="or" style={{ margin: "28px 0 16px" }}>
            or explore with sample data
          </div>
          <div className="stack" style={{ gap: 10 }}>
            {demos.map((d) => {
              const Icon = d.icon;
              return (
                <button key={d.key} className="btn btn-ghost btn-block" style={{ justifyContent: "flex-start", minHeight: 60, gap: 14 }} disabled={busy} onClick={() => go(d.email, DEMO_PASSWORD)} data-demo={d.key}>
                  <span className="tile-ic" style={{ width: 36, height: 36, borderRadius: 10 }} aria-hidden>
                    <Icon size={16} />
                  </span>
                  <span style={{ textAlign: "left" }}>
                    Explore as {d.label.toLowerCase()}
                    <span className="muted" style={{ display: "block", fontSize: 14, fontWeight: 500 }}>
                      {d.sub}
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
          <p className="muted small" style={{ marginTop: 16 }}>
            Demo accounts use the password <code>{DEMO_PASSWORD}</code>. Sample data stays in this browser.
          </p>
        </>
      )}
      <p className="muted" style={{ marginTop: 28, textAlign: "center" }}>
        New to OneStay360?{" "}
        <Link href="/signup/" className="text-link">
          Create an account
        </Link>
      </p>
    </AuthShell>
  );
}
