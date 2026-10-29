"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { Briefcase, Home } from "lucide-react";
import { AuthShell, nextPath } from "@/components/auth-shell";
import { Field, FieldGroup } from "@/components/ui";
import { useBackend } from "@/lib/hooks";

type Form = { name: string; email: string; phone: string; password: string };

function validate(f: Form): Partial<Record<keyof Form, string>> {
  return {
    name: f.name.trim().length < 2 ? "Enter your full name." : undefined,
    email: !/^\S+@\S+\.\S+$/.test(f.email.trim()) ? "Enter a valid email, like name@example.com." : undefined,
    phone: f.phone.replace(/\D/g, "").slice(-10).length !== 10 ? "Enter a 10-digit mobile number." : undefined,
    password: f.password.length < 6 ? "Use at least 6 characters." : undefined,
  };
}

export default function SignUpPage() {
  const backend = useBackend();
  const router = useRouter();
  const [kind, setKind] = useState<"business" | "tenant">("business");
  const [form, setForm] = useState<Form>({ name: "", email: "", phone: "", password: "" });
  const [errors, setErrors] = useState<Partial<Record<keyof Form, string>>>({});
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const k = new URLSearchParams(window.location.search).get("kind");
    if (k === "tenant" || k === "business") setKind(k);
  }, []);

  const set = (k: keyof Form) => (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm((f) => ({ ...f, [k]: e.target.value }));
    if (errors[k]) setErrors((x) => ({ ...x, [k]: undefined }));
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const errs = validate(form);
    setErrors(errs);
    if (Object.values(errs).some(Boolean)) return;
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
      <h1 style={{ fontSize: 30, fontWeight: 800, letterSpacing: "-0.02em", lineHeight: 1.2 }}>Create your account</h1>
      <p className="muted" style={{ marginTop: 8, marginBottom: 28 }}>
        Free to start. It takes about a minute.
      </p>
      <form className="stack" style={{ gap: 20 }} onSubmit={submit} noValidate>
        <FieldGroup label="I want to">
          <div className="role-pick" role="radiogroup" aria-label="Account type">
            <button type="button" role="radio" aria-checked={kind === "business"} onClick={() => setKind("business")}>
              <Briefcase size={20} color="var(--brand-text)" aria-hidden />
              <b>Manage a PG</b>
              <small>Properties, tenants and rent</small>
            </button>
            <button type="button" role="radio" aria-checked={kind === "tenant"} onClick={() => setKind("tenant")}>
              <Home size={20} color="var(--brand-text)" aria-hidden />
              <b>Find or live in a PG</b>
              <small>Join a PG and pay rent</small>
            </button>
          </div>
        </FieldGroup>
        <Field label="Full name" required error={errors.name}>
          <input className="input" autoComplete="name" aria-invalid={!!errors.name} value={form.name} onChange={set("name")} placeholder="e.g. Asha Rao" />
        </Field>
        <Field label="Email address" required error={errors.email}>
          <input className="input" type="email" autoComplete="email" aria-invalid={!!errors.email} value={form.email} onChange={set("email")} placeholder="you@example.com" />
        </Field>
        <Field label="Mobile number" required error={errors.phone} hint={kind === "tenant" ? "Owners invite you to a bed using this number." : "Team invitations are matched to this number."}>
          <input className="input" type="tel" inputMode="numeric" autoComplete="tel" aria-invalid={!!errors.phone} value={form.phone} onChange={set("phone")} placeholder="98765 43210" />
        </Field>
        <Field label="Password" required error={errors.password} hint="At least 6 characters.">
          <input className="input" type="password" autoComplete="new-password" aria-invalid={!!errors.password} value={form.password} onChange={set("password")} />
        </Field>
        {error && (
          <div className="alert alert-red" role="alert">
            {error}
          </div>
        )}
        <button className="btn btn-primary btn-block btn-lg" disabled={busy} aria-busy={busy}>
          {busy ? "Creating your account…" : kind === "business" ? "Create owner account" : "Create tenant account"}
        </button>
      </form>
      <p className="muted" style={{ marginTop: 28, textAlign: "center" }}>
        Already have an account?{" "}
        <Link href="/signin/" className="text-link">
          Sign in
        </Link>
      </p>
    </AuthShell>
  );
}
