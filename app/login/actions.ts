
"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type LoginActionState = {
  error: string | null;
};

export async function signIn(
  _prevState: LoginActionState,
  formData: FormData
): Promise<LoginActionState> {
  const email = formData.get("email");
  const password = formData.get("password");

  if (
    typeof email !== "string" ||
    typeof password !== "string" ||
    !email.trim() ||
    !password
  ) {
    return {
      error: "Ingresa tu correo y contraseña.",
    };
  }

  const supabase = await createClient();

  const { error } = await supabase.auth.signInWithPassword({
    email: email.trim(),
    password,
  });

  if (error) {
    return {
      error: "No fue posible iniciar sesión. Verifica tus credenciales.",
    };
  }

  redirect("/dashboard");
}

export async function signOut() {
  const supabase = await createClient();

  await supabase.auth.signOut();

  redirect("/login");
}
