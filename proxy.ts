import type { NextRequest } from "next/server";
import { actualizarSesion } from "@/lib/supabase/proxy";

export function proxy(request: NextRequest) {
  return actualizarSesion(request);
}

// Solo las pantallas de usuarios internos. Las páginas públicas de cada negocio
// no necesitan sesión y así cargan más rápido.
export const config = {
  matcher: ["/login", "/admin/:path*", "/panel/:path*", "/caja/:path*"],
};
