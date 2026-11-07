# Proyecto: Plataforma de tarjetas de fidelización digitales

## Quién soy y cómo trabajar conmigo
- Trabajo en una imprenta y es mi primer proyecto grande. Soy principiante en programación.
- Hablame en español rioplatense, con explicaciones simples y sin jerga (o explicándola).
- **Modo autonomía máxima (desde 6/11):** decidí y avanzá en lo técnico y de diseño sin consultarme cosas menores o reversibles; resolvé los problemas antes de traérmelos; verificá antes de dar algo por terminado; informá por bloques (hice / verifiqué / resolví / pendiente / decisiones).
- Consultame solo si: cambia el objetivo del proyecto, hay riesgo de perder información sin vuelta atrás, hace falta una credencial o acción que solo yo puedo hacer, hay un riesgo de seguridad importante, una ambigüedad que no se puede resolver, o cualquier posibilidad de gasto.
- **Gasto $0, sin excepción (tiene prioridad sobre todo):** solo planes gratuitos de Supabase y Vercel. Nada de upgrades, suscripciones, pruebas que pasan a pago, APIs pagas, dominios ni dependencias de servicios pagos. Se puede investigar y proponer algo pago, nunca activarlo.
- Calidad: código y pantallas concretos e intencionales, sin relleno, sin sobreingeniería, sin simular funciones que no andan. (El skill ANTISLOP quedó en pausa el 6/11 por pedido de Esteban.)
- Cuando tenga que hacer algo yo (crear una cuenta, copiar una clave, hacer clic en una web), dame los pasos numerados, de a uno.
- Nunca me pidas que pegue contraseñas ni claves en el chat: indicame en qué archivo ponerlas.

## Qué estamos construyendo
PWA multi-negocio (multi-tenant) de tarjetas de fidelización. Cada negocio tiene su marca (logo, colores, slug) y sus reglas de premios. El cajero carga sellos por DNI; el cliente consulta su tarjeta desde el celular. Negocio piloto: Valisburger.

La fuente de verdad es `docs/Documento_base_fidelizacion_v0.1.docx` (podés leerlo convirtiéndolo con pandoc o una librería). Ahí están: reglas de negocio (RN-01 a RN-14), modelo de datos, políticas RLS, pantallas por rol, estructura de carpetas y el plan por fases. Mi idea original está en `docs/protoprompt.txt`.

## Stack
- Next.js (App Router, TypeScript), Tailwind CSS.
- Supabase: Postgres, Auth (solo usuarios internos), Row Level Security, Storage (logos). Región São Paulo.
- Vercel para el deploy. GitHub para el código.
- Mobile-first, interfaz en español (Argentina).

## Decisiones vigentes (ver docs/decisiones.md)
- Direcciones con barra: `/valisburger`, no subdominios (D-01).
- Vencimientos por defecto: sellos 120 días sin actividad; premios 30 días; el negocio puede cambiarlos o desactivarlos (D-02).
- La tarjeta se reinicia al completarse y los sellos sobrantes pasan a la nueva (D-03).
- Entre 1 y 20 sellos por carga (D-07).

## Reglas técnicas que no se negocian
- RLS activado en todas las tablas. Tarjetas, movimientos y premios solo se modifican mediante funciones de la base de datos (cargar_sellos, canjear_premio, etc.), nunca con insert/update directos desde la app.
- La clave `service_role` de Supabase solo se usa en el servidor; nunca en código del navegador ni en GitHub.
- `.env.local` está en `.gitignore` desde el primer commit.
- Los cambios de base de datos van como migraciones en `supabase/migrations/`; los datos de ejemplo en `supabase/seed.sql` (Valisburger + "Pizzería Demo" como negocio de control).

## Cómo llevamos el registro
- Commits chicos y frecuentes con mensajes en español: `feat: ...`, `fix: ...`, `docs: ...`.
- Al terminar cada sesión, agregá una entrada en `docs/bitacora.md` (hice / falta / problemas / próximo paso).
- Si se toma o cambia una decisión, actualizá `docs/decisiones.md`.

## Plan (fecha objetivo del MVP: lunes 9/11/2026, margen martes 10)
- F0 Jue 5: herramientas, proyecto Next.js, GitHub, Vercel, Supabase, primer deploy.
- F1 Vie 6: tablas, RLS, funciones, seed, login por rol.
- F2–F3 Sáb 7: superadmin (alta de negocios y marca), página pública, registro de clientes (QR/NFC y caja).
- F4–F5 Dom 8: caja (sellos y canje) y vista del cliente.
- F6–F7 Lun 9: panel del dueño, PWA, pruebas en celulares, publicación.
- F8 Mar 10: correcciones y demo.

## Estado actual
Fase 1 casi completa (6/11): migraciones, RLS, funciones, seed y login por rol escritos y probados localmente (`npm run probar:db`); login publicado en https://fidelizacion-ten.vercel.app. Falta aplicar la base en Supabase (`npx supabase db push --remote --include-seed` con `SUPABASE_ACCESS_TOKEN`) y correr `npm run crear:usuarios`. Detalle en `docs/bitacora.md`.

Comandos útiles: `npm run probar:db` (pruebas de base de datos) · `npm run crear:usuarios` (usuarios internos de prueba) · `npm run lint` · `npm run build`.
Next.js 16: `middleware.ts` ahora se llama `proxy.ts`; con Cache Components, lo que lee cookies/sesión va dentro de `<Suspense>`. Antes de usar una API de Next, mirá `node_modules/next/dist/docs/`.
