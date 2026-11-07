import { cache } from "react";
import { redirect } from "next/navigation";
import { crearClienteServidor } from "@/lib/supabase/servidor";

export type Rol = "superadmin" | "dueno" | "cajero";

export type Perfil = {
  id: string;
  nombre: string;
  rol: Rol;
  negocio: { nombre: string; slug: string } | null;
};

export const INICIO_POR_ROL: Record<Rol, string> = {
  superadmin: "/admin",
  dueno: "/panel",
  cajero: "/caja",
};

export const NOMBRE_ROL: Record<Rol, string> = {
  superadmin: "Superadministrador",
  dueno: "Dueño",
  cajero: "Cajero",
};

// Usuario interno activo que inició sesión, o null. Se calcula una vez por pedido.
export const obtenerPerfil = cache(async (): Promise<Perfil | null> => {
  const supabase = await crearClienteServidor();
  const { data } = await supabase.auth.getClaims();
  const id = data?.claims?.sub;
  if (!id) return null;

  const { data: perfil } = await supabase
    .from("usuarios_internos")
    .select("id, nombre, rol, negocio:negocios(nombre, slug)")
    .eq("id", id)
    .eq("activo", true)
    .maybeSingle();

  return (perfil as Perfil | null) ?? null;
});

// Para el comienzo de cada página interna: sin sesión va al login; con otro rol, a su inicio.
export async function exigirRol(...roles: Rol[]): Promise<Perfil> {
  const perfil = await obtenerPerfil();
  if (!perfil) redirect("/login");
  if (!roles.includes(perfil.rol)) redirect(INICIO_POR_ROL[perfil.rol]);
  return perfil;
}
