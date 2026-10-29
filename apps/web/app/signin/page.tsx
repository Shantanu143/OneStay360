"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { ArrowRight, Briefcase, Eye, EyeOff, Home, UserCog } from "lucide-react";
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

  const submit = (e: FormEvent) => {
    e.preventDefault();
    void go(email, password);
  };

  return (
    <AuthShell>
      <h1 style={{ fontSize: 26, fontWeight: 800, letterSpacing: "-0.02em" }}>Welcome back</h1>
      <p className="muted" style={{ marginTop: 6, marginBottom: 22 }}>
        Sign in to your OneStay360 account.
      </p>
      <form className="stack" onSubmit={submit}>
        <Field label="Email">
          <input className="input" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" />
        </Field>
        <Field label="Password">
          <div style={{ position: "relative" }}>
            <input className="input" type={show ? "text" : "password"} autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••" style={{ paddingRight: 44 }} />
            <button type="button" onClick={() => setShow((s) => !s)} aria-label={show ? "Hide password" : "Show password"} style={{ position: "absolute", right: 6, top: 6, width: 32, height: 32, border: 0, background: "none", color: "var(--ink-soft)" }}>
              {show ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        </Field>
        {error && <div className="alert alert-red">{error}</div>}
        <button className="btn btn-primary btn-block btn-lg" disabled={busy}>
          {busy ? "Signing in…" : "Sign in"} <ArrowRight size={18} />
        </button>
      </form>

      {backend.mode === "demo" && (
        <>
          <div className="or" style={{ margin: "22px 0 12px" }}>
            or explore a demo account
          </div>
          <div className="stack" style={{ gap: 8 }}>
            {demos.map((d) => {
              const Icon = d.icon;
              return (
                <button key={d.key} className="btn btn-ghost btn-block" style={{ justifyContent: "flex-start", height: 52 }} disabled={busy} onClick={() => go(d.email, DEMO_PASSWORD)} data-demo={d.key}>
                  <span className="tile-ic" style={{ width: 32, height: 32, borderRadius: 10 }}>
                    <Icon size={16} />
                  </span>
                  <span style={{ textAlign: "left" }}>
                    {d.label}
                    <span className="faint" style={{ display: "block", fontSize: 12, fontWeight: 500 }}>
                      {d.sub}
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
          <p className="faint" style={{ fontSize: 12, marginTop: 12 }}>
            Demo accounts use the password <code>{DEMO_PASSWORD}</code>. Data stays in this browser.
          </p>
        </>
      )}
      <p className="muted" style={{ marginTop: 20, fontSize: 14, textAlign: "center" }}>
        New to OneStay360?{" "}
        <Link href="/signup/" style={{ color: "var(--brand)", fontWeight: 650 }}>
          Create an account
        </Link>
      </p>
    </AuthShell>
  );
}
