
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import LoginForm from "./login-form";
import Image from "next/image";
import { connection } from "next/server";

async function LoginContent() {
  await connection();
  const supabase = await createClient();

  const { data, error } = await supabase.auth.getClaims();

  const claims = data?.claims;

  if (!error && claims) {
    redirect("/dashboard");
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#F5F6F2] px-5 py-10">
      <section className="w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-5 w-full max-w-[300px] overflow-hidden rounded-xl bg-black shadow-sm">
  <Image
    src="/tresna-logo.jpeg"
    alt="Logo Tresna"
    width={1600}
    height={400}
    priority
    className="h-auto w-full object-contain"
  />
            </div>

         <p className="mt-2 text-sm text-stone-500">
            Sistema de gestión comercial
         </p>
        </div>

        <div className="rounded-2xl border border-stone-200 bg-white p-8 shadow-sm">
          <div className="mb-7">
            <h2 className="text-xl font-semibold text-stone-900">
              Bienvenido
            </h2>

            <p className="mt-2 text-sm text-stone-500">
              Ingresa tus credenciales para acceder al sistema.
            </p>
          </div>

          <LoginForm />
        </div>

        <p className="mt-6 text-center text-xs text-stone-400">
          Tresna · Gestión comercial
        </p>
      </section>
    </main>
  );
}

function LoginFallback() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[#F5F6F2] px-5 py-10">
      <div className="w-full max-w-md rounded-2xl border border-stone-200 bg-white p-8 shadow-sm">
        <div className="text-center">
          <div className="mx-auto mb-5 flex h-16 w-16 items-center justify-center rounded-2xl bg-emerald-950 text-2xl font-bold text-white">
            T
          </div>

          <h1 className="text-3xl font-bold text-emerald-950">
            Tresna
          </h1>

          <p className="mt-3 text-sm text-stone-500">
            Verificando sesión...
          </p>
        </div>
      </div>
    </main>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<LoginFallback />}>
      <LoginContent />
    </Suspense>
  );
}
