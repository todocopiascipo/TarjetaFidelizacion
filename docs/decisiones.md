# Registro de decisiones

Cada decisión importante: qué se decidió, cuándo y por qué.
Estados: Pendiente → Confirmada (con fecha) o Descartada.

| Código | Decisión | Propuesta | Estado | Fecha |
|---|---|---|---|---|
| D-01 | Forma de las direcciones | miplataforma.com/valisburger en el MVP; subdominios después | Pendiente | |
| D-02 | Vencimientos estándar | Sellos: 120 días sin actividad · Premios: 30 días | Pendiente | |
| D-03 | Cuándo se reinicia la tarjeta | Al completarse, con los sellos sobrantes en la tarjeta nueva | Pendiente | |
| D-04 | Marca de Valisburger | Colores provisorios hasta tener logo y colores oficiales | Pendiente | |
| D-05 | Nombre y dominio de la plataforma | Dirección gratuita de Vercel en el MVP | Pendiente | |
| D-06 | Texto del aviso de privacidad | Breve: qué datos se guardan, para qué y cómo pedir la baja | Pendiente | |
| D-07 | Cantidad máxima por carga | Entre 1 y 20 sellos por operación | Pendiente | |

## Decisiones técnicas de la Fase 0

| Código | Decisión | Estado | Fecha |
|---|---|---|---|
| T-01 | Repositorio de GitHub privado (`todocopiascipo/TarjetaFidelizacion`) | Confirmada | 04/11/2026 |
| T-02 | Claves nuevas de Supabase: `publishable` (reemplaza a `anon`) y `secret` (reemplaza a `service_role`). Nombres: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY` | Confirmada | 04/11/2026 |
| T-03 | Commits firmados con todocopias.cipo@gmail.com (en vez del email privado de GitHub) | Confirmada | 04/11/2026 |

## Detalle de cada decisión
(Cuando se confirme una, anotá acá el motivo.)

- **D-05:** mientras tanto se usa https://fidelizacion-ten.vercel.app (sigue Pendiente).
- **T-02:** Supabase hoy entrega estas claves por defecto. La `secret` cumple la misma regla que la vieja `service_role`: solo en el servidor, nunca en el navegador ni en GitHub.
