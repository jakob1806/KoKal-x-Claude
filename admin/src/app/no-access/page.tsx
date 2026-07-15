import { SignOutButton } from "@/components/sign-out-button";

export default function NoAccessPage() {
  return (
    <div className="flex min-h-full items-center justify-center px-6 py-16">
      <div className="max-w-sm text-center">
        <p className="text-sm font-semibold tracking-tight">Kein Zugriff</p>
        <p className="mt-2 text-sm text-neutral-500">
          Dein Account ist angemeldet, hat aber keine Redaktionsrechte für dieses
          Dashboard. Bitte einen bestehenden Admin bitten, dir eine Rolle in{" "}
          <code className="font-mono">user_roles</code> zuzuweisen.
        </p>
        <div className="mt-6">
          <SignOutButton />
        </div>
      </div>
    </div>
  );
}
