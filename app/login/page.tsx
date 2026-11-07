import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Suspense } from "react";
import { INICIO_POR_ROL, obtenerPerfil } from "@/lib/auth";
import { FormularioLogin } from "./formulario";

export const metadata: Metadata = { title: "Ingresar" };

export default function PaginaLogin() {
  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center px-5 py-12">
      <Suspense>
        <SiYaEntro />
      </Suspense>
      <h1 className="text-2xl font-bold">Ingresar</h1>
      <p className="mt-1 mb-8 text-neutral-600">Para dueños y cajeros de los negocios.</p>
      <FormularioLogin />
    </main>
  );
}

// Si ya hay sesión, lleva directo a la pantalla de su rol.
async function SiYaEntro() {
  const perfil = await obtenerPerfil();
  if (perfil) redirect(INICIO_POR_ROL[perfil.rol]);
  return null;
}
