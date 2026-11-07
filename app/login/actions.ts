"use server";

import { redirect } from "next/navigation";
import { INICIO_POR_ROL, type Rol } from "@/lib/auth";
import { crearClienteServidor } from "@/lib/supabase/servidor";

export type EstadoLogin = { error: string; email: string } | null;

export async function iniciarSesion(_previo: EstadoLogin, formData: FormData): Promise<EstadoLogin> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const password = String(formData.get("password") ?? "");
  if (!email || !password) return { error: "Completá el email y la contraseña.", email };

  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    const mensaje =
      error.code === "invalid_credentials"
        ? "El email o la contraseña no son correctos."
        : "No pudimos iniciar sesión. Probá de nuevo en un momento.";
    return { error: mensaje, email };
  }

  const { data: perfil } = await supabase
    .from("usuarios_internos")
    .select("rol")
    .eq("id", data.user.id)
    .eq("activo", true)
    .maybeSingle<{ rol: Rol }>();

  if (!perfil) {
    await supabase.auth.signOut();
    return { error: "Tu usuario no tiene acceso o está desactivado. Consultá con el dueño del negocio.", email };
  }

  redirect(INICIO_POR_ROL[perfil.rol]);
}

export async function cerrarSesion() {
  const supabase = await crearClienteServidor();
  await supabase.auth.signOut();
  redirect("/login");
}
