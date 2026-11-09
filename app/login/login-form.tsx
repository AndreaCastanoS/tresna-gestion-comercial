
"use client";

import { useActionState } from "react";
import { signIn, type LoginActionState } from "./actions";

const initialState: LoginActionState = {
  error: null,
};

export default function LoginForm() {
  const [state, formAction, pending] = useActionState(
    signIn,
    initialState
  );

  return (
    <form action={formAction} className="space-y-5">
      <div className="space-y-2">
        <label
          htmlFor="email"
          className="block text-sm font-medium text-stone-700"
        >
          Correo electrónico
        </label>

        <input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          placeholder="nombre@empresa.com"
          required
          className="w-full rounded-xl border border-stone-300 bg-white px-4 py-3 text-sm outline-none transition focus:border-emerald-800 focus:ring-2 focus:ring-emerald-800/10"
        />
      </div>

      <div className="space-y-2">
        <label
          htmlFor="password"
          className="block text-sm font-medium text-stone-700"
        >
          Contraseña
        </label>

        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          placeholder="Ingresa tu contraseña"
          required
          className="w-full rounded-xl border border-stone-300 bg-white px-4 py-3 text-sm outline-none transition focus:border-emerald-800 focus:ring-2 focus:ring-emerald-800/10"
        />
      </div>

      {state.error && (
        <div
          role="alert"
          className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {state.error}
        </div>
      )}

      <button
        type="submit"
        disabled={pending}
        className="w-full rounded-xl bg-emerald-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-emerald-900 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {pending ? "Ingresando..." : "Iniciar sesión"}
      </button>
    </form>
  );
}
