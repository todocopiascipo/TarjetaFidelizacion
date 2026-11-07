"use client";

import { useActionState } from "react";
import { iniciarSesion } from "./actions";

export function FormularioLogin() {
  const [estado, enviar, enviando] = useActionState(iniciarSesion, null);

  return (
    <form action={enviar} className="flex flex-col gap-4">
      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-medium">Email</span>
        <input
          name="email"
          type="email"
          autoComplete="username"
          inputMode="email"
          required
          defaultValue={estado?.email}
          className="h-12 rounded-lg border border-neutral-300 px-3 text-base outline-none focus:border-neutral-900 focus:ring-2 focus:ring-neutral-900/10"
        />
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-medium">Contraseña</span>
        <input
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="h-12 rounded-lg border border-neutral-300 px-3 text-base outline-none focus:border-neutral-900 focus:ring-2 focus:ring-neutral-900/10"
        />
      </label>

      {estado?.error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2.5 text-sm text-red-800">
          {estado.error}
        </p>
      )}

      <button
        type="submit"
        disabled={enviando}
        className="mt-2 h-12 rounded-lg bg-neutral-900 text-base font-semibold text-white disabled:opacity-60"
      >
        {enviando ? "Ingresando…" : "Ingresar"}
      </button>
    </form>
  );
}
