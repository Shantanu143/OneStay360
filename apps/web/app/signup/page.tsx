"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { Briefcase, Home } from "lucide-react";
import { AuthShell, homeFor } from "@/components/auth-shell";
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
      const account = await backend.signUp({ kind, ...form });
      router.replace(homeFor(account));
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setBusy(false);
    }
  };

  return (
    <AuthShell aside={{ title: kind === "business" ? "Run your PG from one screen." : "Find a PG. Pay rent. Done.", body: kind === "business" ? "Beds, tenants, rent and maintenance in one place. Free to set up." : "Join a verified PG, pay rent with proof and raise requests — always free for tenants." }}>
      <h1 className="auth-title">Create your account</h1>
      <p className="muted auth-sub">Free to start. Takes about a minute.</p>
      <form className="auth-form" onSubmit={submit} noValidate>
        <FieldGroup label="I am">
          <div className="seg seg-block" role="radiogroup" aria-label="Account type">
            <button type="button" role="radio" aria-checked={kind === "business"} onClick={() => setKind("business")}>
              <Briefcase size={17} aria-hidden /> A PG owner
            </button>
            <button type="button" role="radio" aria-checked={kind === "tenant"} onClick={() => setKind("tenant")}>
              <Home size={17} aria-hidden /> A tenant
            </button>
          </div>
        </FieldGroup>
        <Field label="Full name" required error={errors.name}>
          <input className="input" autoComplete="name" aria-invalid={!!errors.name} value={form.name} onChange={set("name")} placeholder="e.g. Asha Rao" />
        </Field>
        <Field label="Email address" required error={errors.email}>
          <input className="input" type="email" autoComplete="email" aria-invalid={!!errors.email} value={form.email} onChange={set("email")} placeholder="you@example.com" />
        </Field>
        <Field label="Mobile number" required error={errors.phone}>
          <input className="input" type="tel" inputMode="numeric" autoComplete="tel" aria-invalid={!!errors.phone} value={form.phone} onChange={set("phone")} placeholder="98765 43210" />
        </Field>
        <Field label="Password" required error={errors.password}>
          <input className="input" type="password" autoComplete="new-password" aria-invalid={!!errors.password} value={form.password} onChange={set("password")} placeholder="At least 6 characters" />
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
      <p className="muted auth-foot">
        Already have an account?{" "}
        <Link href="/signin/" className="text-link">
          Sign in
        </Link>
      </p>
    </AuthShell>
  );
}
