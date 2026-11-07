import type { Metadata } from "next";
import { Suspense } from "react";
import { BarraInterna } from "@/components/BarraInterna";
import { Cargando } from "@/components/Cargando";
import { exigirRol } from "@/lib/auth";

export const metadata: Metadata = { title: "Caja" };

export default function PaginaCaja() {
  return (
    <Suspense fallback={<Cargando />}>
      <Caja />
    </Suspense>
  );
}

async function Caja() {
  const perfil = await exigirRol("dueno", "cajero");

  return (
    <>
      <BarraInterna perfil={perfil} />
      <main className="px-5 py-6">
        <h1 className="text-xl font-bold">Caja</h1>
        <p className="mt-2 text-neutral-600">La búsqueda por DNI y la carga de sellos llegan en la Fase 4.</p>
      </main>
    </>
  );
}
