import type { Metadata } from "next";
import { Suspense } from "react";
import { BarraInterna } from "@/components/BarraInterna";
import { Cargando } from "@/components/Cargando";
import { exigirRol } from "@/lib/auth";

export const metadata: Metadata = { title: "Negocios" };

export default function PaginaAdmin() {
  return (
    <Suspense fallback={<Cargando />}>
      <Admin />
    </Suspense>
  );
}

async function Admin() {
  const perfil = await exigirRol("superadmin");

  return (
    <>
      <BarraInterna perfil={perfil} />
      <main className="px-5 py-6">
        <h1 className="text-xl font-bold">Negocios</h1>
        <p className="mt-2 text-neutral-600">El alta y la edición de negocios llegan en la Fase 2.</p>
      </main>
    </>
  );
}
