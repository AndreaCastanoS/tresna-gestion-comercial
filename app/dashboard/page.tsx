
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { signOut } from "@/app/login/actions";
import Image from "next/image";
import { connection } from "next/server";

async function DashboardContent() {
  await connection();

  const supabase = await createClient();

  const {
    data,
    error: claimsError,
  } = await supabase.auth.getClaims();

  const claims = data?.claims;

  if (claimsError || !claims?.sub) {
    redirect("/login");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("full_name, role")
    .eq("id", claims.sub)
    .maybeSingle();

  if (profileError || !profile) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-stone-50 px-5">
        <section className="max-w-md rounded-2xl border border-stone-200 bg-white p-8 text-center">
          <h1 className="text-xl font-semibold text-stone-900">
            Perfil no disponible
          </h1>

          <p className="mt-3 text-sm text-stone-500">
            Tu cuenta está autenticada, pero no encontramos un
            perfil asociado. Contacta al administrador de Tresna.
          </p>

          <form action={signOut} className="mt-6">
            <button
              type="submit"
              className="rounded-xl bg-emerald-950 px-5 py-3 text-sm font-medium text-white"
            >
              Cerrar sesión
            </button>
          </form>
        </section>
      </main>
    );
  }

  const displayName = profile.full_name?.trim() || "Usuario";

  const roleName =
    profile.role === "admin" ? "Administrador" : "Empleado";

  return (
    <main className="min-h-screen bg-[#F5F6F2]">
      <header className="flex items-center justify-between border-b border-stone-200 bg-white px-6 py-5">
       <div className="flex items-center gap-3">
  <div className="w-36 overflow-hidden rounded-md bg-black">
    <Image
      src="/tresna-logo.jpeg"
      alt="Logo Tresna"
      width={1600}
      height={400}
      className="block h-auto w-full object-contain"
    />
  </div>

  <p className="text-xs text-stone-500">
    Gestión comercial
  </p>
</div>

        <form action={signOut}>
          <button
            type="submit"
            className="rounded-lg border border-stone-200 px-4 py-2 text-sm font-medium text-stone-700 transition hover:bg-stone-50"
          >
            Cerrar sesión
          </button>
        </form>
      </header>

      <section className="mx-auto max-w-7xl px-6 py-10">
        <div className="rounded-2xl bg-emerald-950 p-8 text-white">
          <p className="text-sm text-emerald-200">
            Panel de administración
          </p>

          <h2 className="mt-2 text-3xl font-semibold">
            ¡Bienvenido, {displayName}!
          </h2>

          <p className="mt-3 text-sm text-emerald-100">
            Tu espacio de trabajo en Tresna está listo.
          </p>

          <div className="mt-6 inline-flex rounded-full bg-white/10 px-4 py-2 text-xs font-medium">
            Rol: {roleName}
          </div>
        </div>

        <div className="mt-8">
          <h3 className="text-lg font-semibold text-stone-900">
            Próximamente
          </h3>

          <p className="mt-2 text-sm text-stone-500">
            Aquí construiremos los módulos de inventario,
            clientes, documentos y cartera de Tresna.
          </p>
        </div>
      </section>
    </main>
  );
}

function DashboardFallback() {
  return (
    <main className="min-h-screen bg-[#F5F6F2]">
      <header className="border-b border-stone-200 bg-white px-6 py-5">
        <h1 className="text-xl font-bold text-emerald-950">
          Tresna
        </h1>
      </header>

      <section className="mx-auto max-w-7xl px-6 py-10">
        <div className="animate-pulse rounded-2xl bg-emerald-950 p-8 text-white">
          <div className="h-4 w-40 rounded bg-white/20" />

          <div className="mt-4 h-8 w-64 rounded bg-white/20" />

          <div className="mt-4 h-4 w-52 rounded bg-white/20" />
        </div>

        <p className="mt-6 text-sm text-stone-500">
          Verificando tu sesión...
        </p>
      </section>
    </main>
  );
}

export default function DashboardPage() {
  return (
    <Suspense fallback={<DashboardFallback />}>
      <DashboardContent />
    </Suspense>
  );
}
