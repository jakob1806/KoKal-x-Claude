"use client";

import { Suspense, useState, type FormEvent } from "react";
import { useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

function LoginForm() {
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirectTo") ?? "/events";

  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [errorMessage, setErrorMessage] = useState("");

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setStatus("sending");
    setErrorMessage("");

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback?redirectTo=${encodeURIComponent(redirectTo)}`,
      },
    });

    if (error) {
      setStatus("error");
      setErrorMessage(error.message);
      return;
    }
    setStatus("sent");
  }

  return (
    <div className="flex min-h-full items-center justify-center px-6 py-16">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <p className="text-sm font-semibold tracking-tight">Klassik München</p>
          <p className="text-xs text-neutral-500">Redaktions-Dashboard</p>
        </div>

        {status === "sent" ? (
          <div className="rounded-lg border border-neutral-200 bg-white px-5 py-4 text-center text-sm text-neutral-700">
            Link geschickt an <span className="font-medium">{email}</span>.
            Öffne ihn auf diesem Gerät, um dich anzumelden.
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <label className="text-xs font-medium text-neutral-600" htmlFor="email">
              E-Mail-Adresse
            </label>
            <input
              id="email"
              type="email"
              required
              autoFocus
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="name@beispiel.de"
              className="rounded-md border border-neutral-300 px-3 py-2 text-sm outline-none focus:border-neutral-500"
            />
            {status === "error" && (
              <p className="text-xs text-red-600">{errorMessage}</p>
            )}
            <button
              type="submit"
              disabled={status === "sending"}
              className="mt-2 rounded-md bg-neutral-900 px-3 py-2 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-50"
            >
              {status === "sending" ? "Sende Link…" : "Anmeldelink senden"}
            </button>
            <p className="mt-1 text-center text-xs text-neutral-400">
              Kein Passwort nötig — du bekommst einen Anmeldelink per E-Mail.
            </p>
          </form>
        )}
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}
