import { cerrarSesion } from "@/app/login/actions";
import { NOMBRE_ROL, type Perfil } from "@/lib/auth";

// Encabezado de las pantallas internas: quién está operando y en qué negocio.
export function BarraInterna({ perfil }: { perfil: Perfil }) {
  return (
    <header className="flex items-center justify-between gap-4 border-b border-neutral-200 px-5 py-3">
      <div className="min-w-0">
        <p className="truncate font-semibold">{perfil.negocio?.nombre ?? "Plataforma"}</p>
        <p className="truncate text-sm text-neutral-600">
          {perfil.nombre} · {NOMBRE_ROL[perfil.rol]}
        </p>
      </div>
      <form action={cerrarSesion}>
        <button type="submit" className="h-11 rounded-lg px-3 text-sm font-medium text-neutral-700 hover:bg-neutral-100">
          Salir
        </button>
      </form>
    </header>
  );
}
