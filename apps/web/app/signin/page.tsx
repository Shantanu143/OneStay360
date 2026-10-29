"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Eye, EyeOff } from "lucide-react";
import { AuthShell, homeFor } from "@/components/auth-shell";
import { Field } from "@/components/ui";
import { useBackend } from "@/lib/hooks";

export default function SignInPage() {
  const backend = useBackend();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErr, setFieldErr] = useState<{ email?: string; password?: string }>({});
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const errs = {
      email: !email.trim() ? "Enter your email address." : !/^\S+@\S+\.\S+$/.test(email.trim()) ? "Enter a valid email, like name@example.com." : undefined,
      password: !password ? "Enter your password." : undefined,
    };
    setFieldErr(errs);
    if (errs.email || errs.password) return;
    setBusy(true);
    setError(null);
    try {
      const account = await backend.signIn(email, password);
      // The role decides the destination: no extra step for the user.
      router.replace(homeFor(account));
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setBusy(false);
    }
  };

  return (
    <AuthShell aside={{ title: "Welcome back.", body: "Owners land on their business dashboard, tenants on their stay — just sign in." }}>
      <h1 className="auth-title">Sign in</h1>
      <p className="muted auth-sub">Use the email and password you signed up with.</p>
      <form className="auth-form" onSubmit={submit} noValidate>
        <Field label="Email address" error={fieldErr.email}>
          <input className="input" type="email" autoComplete="email" autoFocus aria-invalid={!!fieldErr.email} value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" />
        </Field>
        <Field label="Password" error={fieldErr.password}>
          <span style={{ position: "relative", display: "block" }}>
            <input className="input" type={show ? "text" : "password"} autoComplete="current-password" aria-invalid={!!fieldErr.password} value={password} onChange={(e) => setPassword(e.target.value)} style={{ paddingRight: 52 }} />
            <button type="button" onClick={() => setShow((s) => !s)} aria-label={show ? "Hide password" : "Show password"} aria-pressed={show} style={{ position: "absolute", right: 4, top: 3, width: 40, height: 40, border: 0, borderRadius: 10, background: "none", color: "var(--ink-soft)", display: "grid", placeItems: "center" }}>
              {show ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </span>
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
      <p className="muted auth-foot">
        New to OneStay360?{" "}
        <Link href="/signup/" className="text-link">
          Create an account
        </Link>
      </p>
    </AuthShell>
  );
}
