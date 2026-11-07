import type { Metadata } from "next";
import { Suspense } from "react";
import { BarraInterna } from "@/components/BarraInterna";
import { Cargando } from "@/components/Cargando";
import { exigirRol } from "@/lib/auth";

export const metadata: Metadata = { title: "Panel" };

export default function PaginaPanel() {
  return (
    <Suspense fallback={<Cargando />}>
      <Panel />
    </Suspense>
  );
}

async function Panel() {
  const perfil = await exigirRol("dueno");

  return (
    <>
      <BarraInterna perfil={perfil} />
      <main className="px-5 py-6">
        <h1 className="text-xl font-bold">Panel del negocio</h1>
        <p className="mt-2 text-neutral-600">Reglas, cajeros y estadísticas llegan en la Fase 6.</p>
      </main>
    </>
  );
}
