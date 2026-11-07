import Link from "next/link";

export default function Inicio() {
  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center px-5 py-12">
      <h1 className="text-2xl font-bold">Tarjetas de fidelización</h1>
      <p className="mt-2 text-neutral-600">
        Para ver tu tarjeta, escaneá el código QR del local donde comprás.
      </p>
      <Link
        href="/login"
        className="mt-10 flex h-12 items-center justify-center rounded-lg border border-neutral-300 font-medium"
      >
        Ingreso para negocios
      </Link>
    </main>
  );
}
