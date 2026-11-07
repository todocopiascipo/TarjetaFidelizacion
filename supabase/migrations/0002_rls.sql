-- 0002 · Seguridad: funciones de ayuda y políticas RLS (documento base, sección 8).
--
-- Principio: los permisos de tabla (grant) dicen QUÉ operaciones existen para cada rol;
-- las políticas RLS dicen SOBRE QUÉ FILAS. El público (anon) no lee ninguna tabla:
-- entra solo por las funciones de 0003.

-- ── Funciones de ayuda ────────────────────────────────────────────────────────
-- security definer: leen usuarios_internos sin pasar por sus propias políticas
-- (si no, la política de usuarios_internos se llamaría a sí misma en bucle).
-- Un usuario desactivado es tratado como si no existiera.

create function public.mi_rol()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select rol from public.usuarios_internos
  where id = (select auth.uid()) and activo;
$$;

create function public.mi_negocio()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select negocio_id from public.usuarios_internos
  where id = (select auth.uid()) and activo;
$$;

create function public.es_superadmin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.mi_rol() = 'superadmin', false);
$$;

-- slug_reservado queda pública: la usa la restricción de negocios.slug al insertar.
revoke execute on function public.mi_rol(), public.mi_negocio(), public.es_superadmin(),
  public.bloquear_cambios_historial(), public.tocar_actualizado_en()
  from public, anon;
grant execute on function public.mi_rol(), public.mi_negocio(), public.es_superadmin()
  to authenticated;

-- ── Permisos de tabla ─────────────────────────────────────────────────────────
revoke all on public.negocios, public.reglas_tarjeta, public.usuarios_internos,
  public.clientes, public.tarjetas, public.premios, public.movimientos
  from anon, authenticated;

grant select on public.negocios, public.reglas_tarjeta, public.usuarios_internos,
  public.clientes, public.tarjetas, public.premios, public.movimientos
  to authenticated;

-- Escrituras directas permitidas (siempre filtradas por las políticas de abajo).
-- tarjetas, premios y movimientos no tienen ninguna: solo se tocan con funciones.
grant insert, update on public.negocios to authenticated;
grant insert, update on public.reglas_tarjeta to authenticated;
grant update (nombre, activo) on public.usuarios_internos to authenticated;

-- ── RLS activado en todas las tablas ─────────────────────────────────────────
alter table public.negocios          enable row level security;
alter table public.reglas_tarjeta    enable row level security;
alter table public.usuarios_internos enable row level security;
alter table public.clientes          enable row level security;
alter table public.tarjetas          enable row level security;
alter table public.premios           enable row level security;
alter table public.movimientos       enable row level security;

-- negocios: el superadmin todo; dueño y cajero ven el suyo.
create policy negocios_ver on public.negocios
  for select to authenticated
  using ((select public.es_superadmin()) or id = (select public.mi_negocio()));

create policy negocios_crear on public.negocios
  for insert to authenticated
  with check ((select public.es_superadmin()));

create policy negocios_editar on public.negocios
  for update to authenticated
  using ((select public.es_superadmin()))
  with check ((select public.es_superadmin()));

-- reglas_tarjeta: superadmin todo; dueño ve y edita las suyas; cajero solo ve.
create policy reglas_ver on public.reglas_tarjeta
  for select to authenticated
  using ((select public.es_superadmin()) or negocio_id = (select public.mi_negocio()));

create policy reglas_crear on public.reglas_tarjeta
  for insert to authenticated
  with check ((select public.es_superadmin()));

create policy reglas_editar on public.reglas_tarjeta
  for update to authenticated
  using ((select public.es_superadmin())
         or ((select public.mi_rol()) = 'dueno' and negocio_id = (select public.mi_negocio())))
  with check ((select public.es_superadmin())
              or ((select public.mi_rol()) = 'dueno' and negocio_id = (select public.mi_negocio())));

-- usuarios_internos: cada uno ve su perfil; el dueño ve a todo su equipo y gestiona
-- (nombre / activo) a sus cajeros. El alta de usuarios la hace el servidor con la
-- clave secreta, porque también hay que crear la cuenta de login.
create policy usuarios_ver on public.usuarios_internos
  for select to authenticated
  using ((select public.es_superadmin())
         or id = (select auth.uid())
         or ((select public.mi_rol()) = 'dueno' and negocio_id = (select public.mi_negocio())));

create policy usuarios_editar on public.usuarios_internos
  for update to authenticated
  using ((select public.es_superadmin())
         or ((select public.mi_rol()) = 'dueno' and rol = 'cajero'
             and negocio_id = (select public.mi_negocio())))
  with check ((select public.es_superadmin())
              or ((select public.mi_rol()) = 'dueno' and rol = 'cajero'
                  and negocio_id = (select public.mi_negocio())));

-- Datos de clientes: solo lectura, cada negocio lo suyo; el superadmin ve todo.
create policy clientes_ver on public.clientes
  for select to authenticated
  using ((select public.es_superadmin()) or negocio_id = (select public.mi_negocio()));

create policy tarjetas_ver on public.tarjetas
  for select to authenticated
  using ((select public.es_superadmin()) or negocio_id = (select public.mi_negocio()));

create policy premios_ver on public.premios
  for select to authenticated
  using ((select public.es_superadmin()) or negocio_id = (select public.mi_negocio()));

create policy movimientos_ver on public.movimientos
  for select to authenticated
  using ((select public.es_superadmin()) or negocio_id = (select public.mi_negocio()));
