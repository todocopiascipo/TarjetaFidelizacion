# Bitácora del proyecto

Cinco minutos al terminar cada día. Copiá el bloque de abajo y completalo.

---

## Miércoles 4/11
- **Hice:** definí el proyecto (protoprompt) y armé el documento base v0.1 con el plan hacia el MVP.
- **Falta:** confirmar las decisiones D-01, D-02 y D-03 (ver decisiones.md).
- **Problemas:** —
- **Próximo paso:** Fase 0, crear cuentas (GitHub, Supabase, Vercel) e instalar herramientas.

---

## Miércoles 4/11 (noche) · Fase 0 completa
- **Hice:**
  - Verifiqué herramientas: Node 24.19, npm 11.17, Git 2.55, VS Code 1.133.
  - Creé el proyecto Next.js 16.4 (TypeScript, App Router, Tailwind 4, ESLint) en la raíz, sin tocar `docs/` ni `CLAUDE.md`.
  - Git iniciado (rama `main`, firma "Esteban"). `.gitignore` excluye `.env.local`, `node_modules`, `.next` y `.vercel`. Primer commit hecho.
  - Repositorio privado en GitHub: https://github.com/todocopiascipo/TarjetaFidelizacion
  - Proyecto `fidelizacion` en Vercel, conectado al repo y publicado: https://fidelizacion-ten.vercel.app
  - Proyecto `fidelizacion` en Supabase, región São Paulo.
  - Claves de Supabase (URL, publishable y secret) en `.env.local` y en Vercel (la secret como "Sensitive"). Plantilla sin valores en `.env.example`.
- **Falta:**
  - La web todavía muestra la página de ejemplo de Next.js.
  - La base de datos está vacía: tablas, RLS, funciones y seed son la Fase 1.
  - Confirmar las decisiones D-01 a D-07.
- **Problemas:**
  - Vercel no aceptó el nombre del proyecto con mayúsculas → usamos `fidelizacion`.
  - `vercel link` agregó `.env*` al final de `.gitignore` y eso volvía a esconder `.env.example` → lo corregimos.
  - npm avisa 8 vulnerabilidades "moderadas" en herramientas de ESLint (solo se usan en la compu, no se publican). Revisar más adelante sin `--force`.
- **Para tener en cuenta:** el plan gratuito (Hobby) de Vercel es para uso no comercial. Antes de usarlo con clientes reales, evaluar el plan Pro (gasto: lo decide Esteban).
- **Próximo paso:** Fase 1 (viernes 6): migraciones 0001 (tablas), 0002 (RLS), 0003 (funciones), `seed.sql` con Valisburger + Pizzería Demo, y login por rol. Tené a mano la contraseña de la base de datos de Supabase.

---

## Viernes 6/11 · Fase 1 (en curso)
- **Hice:**
  - Modo autonomía máxima y regla de gasto $0, registrados en `CLAUDE.md`. El skill ANTISLOP quedó en pausa.
  - Migraciones `0001_esquema` (7 tablas), `0002_rls` (funciones de ayuda + políticas) y `0003_funciones` (cargar_sellos, canjear_premio, registros, consultas y vencimientos).
  - `seed.sql`: Valisburger con 5 clientes (vacía, a mitad, con premio, canjeado, sellos vencidos) y Pizzería Demo con un DNI repetido a propósito.
  - `npm run probar:db`: 35 pruebas en un Postgres local (PGlite, sin Docker). Todas pasan, incluida "el cajero de Pizzería Demo no ve nada de Valisburger".
  - Login con redirección por rol (`/admin`, `/panel`, `/caja`) y protección de esas rutas. Publicado en Vercel.
  - `npm run crear:usuarios`: crea superadmin, dueños y cajeros de prueba. Las contraseñas se generaron al azar y están solo en `.env.local`.
- **Falta:**
  - Aplicar las migraciones y el seed en Supabase. Necesita el token de acceso (`SUPABASE_ACCESS_TOKEN` en `.env.local`).
  - Crear los usuarios en la nube y probar el login de punta a punta.
- **Problemas:**
  - La plantilla de Next 16 trae "Cache Components": todo lo que lee la sesión tiene que ir dentro de `<Suspense>`. Resuelto.
  - El primer intento de pruebas falló por cómo Postgres corta una transacción después de un error. Se resolvió con savepoints.
- **Próximo paso:** con el token, `supabase db push --remote --include-seed`, después `npm run crear:usuarios` y probar el login con cada rol.

---

## (Plantilla) Día dd/mm
- **Hice:**
- **Falta:**
- **Problemas:**
- **Próximo paso:**
