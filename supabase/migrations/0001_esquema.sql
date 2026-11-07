-- 0001 · Esquema: las 7 tablas del modelo de datos (documento base, sección 7).
-- Toda tabla con datos de un negocio lleva negocio_id: es la llave que usa RLS.

-- Palabras que no pueden usarse como slug porque son rutas internas (sección 6.2).
create function public.slug_reservado(p_slug text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_slug = any (array[
    'admin', 'panel', 'caja', 'login', 'logout', 'api', 'registro', 'mi-tarjeta',
    'auth', '_next', 'static', 'public', 'iconos', 'manifest', 'favicon'
  ]);
$$;

create table public.negocios (
  id               uuid primary key default gen_random_uuid(),
  slug             text not null unique
                   check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
                          and char_length(slug) between 3 and 40
                          and not public.slug_reservado(slug)),
  nombre           text not null check (char_length(btrim(nombre)) between 1 and 80),
  logo_url         text,
  color_primario   text not null default '#111827' check (color_primario ~ '^#[0-9A-Fa-f]{6}$'),
  color_secundario text not null default '#F59E0B' check (color_secundario ~ '^#[0-9A-Fa-f]{6}$'),
  activo           boolean not null default true,
  creado_en        timestamptz not null default now()
);

-- Separada de negocios para que el dueño edite sus reglas sin poder tocar marca ni slug.
create table public.reglas_tarjeta (
  negocio_id              uuid primary key references public.negocios (id) on delete cascade,
  sellos_requeridos       integer not null default 6 check (sellos_requeridos between 1 and 30),
  premio_titulo           text not null check (char_length(btrim(premio_titulo)) between 1 and 80),
  premio_descripcion      text check (char_length(premio_descripcion) <= 300),
  -- null = no vencen (RN-09, RN-10)
  dias_vencimiento_sellos integer default 120 check (dias_vencimiento_sellos > 0),
  dias_vencimiento_premio integer default 30  check (dias_vencimiento_premio > 0),
  actualizado_en          timestamptz not null default now()
);

create table public.usuarios_internos (
  id         uuid primary key references auth.users (id) on delete cascade,
  negocio_id uuid references public.negocios (id),
  rol        text not null check (rol in ('superadmin', 'dueno', 'cajero')),
  nombre     text not null check (char_length(btrim(nombre)) between 1 and 80),
  activo     boolean not null default true,
  creado_en  timestamptz not null default now(),
  -- El superadmin no pertenece a ningún negocio; dueños y cajeros, siempre a uno.
  constraint negocio_segun_rol check ((rol = 'superadmin') = (negocio_id is null))
);
create index usuarios_internos_negocio_idx on public.usuarios_internos (negocio_id);

create table public.clientes (
  id                   uuid primary key default gen_random_uuid(),
  negocio_id           uuid not null references public.negocios (id),
  dni                  text not null check (dni ~ '^[0-9]{7,8}$'),
  nombre               text not null check (char_length(btrim(nombre)) between 1 and 80),
  celular              text not null check (celular ~ '^\+549[0-9]{10}$'),
  origen               text not null check (origen in ('autorregistro', 'caja')),
  acepto_privacidad_en timestamptz,
  creado_en            timestamptz not null default now(),
  unique (negocio_id, dni),          -- RN-01
  unique (id, negocio_id)            -- permite que las demás tablas exijan el mismo negocio
);

create table public.tarjetas (
  id              uuid primary key default gen_random_uuid(),
  negocio_id      uuid not null,
  cliente_id      uuid not null unique,  -- RN-02: una tarjeta por cliente
  sellos_actuales integer not null default 0 check (sellos_actuales >= 0),
  ultimo_sello_en timestamptz,
  foreign key (cliente_id, negocio_id) references public.clientes (id, negocio_id)
);
create index tarjetas_negocio_idx on public.tarjetas (negocio_id);

create table public.premios (
  id           uuid primary key default gen_random_uuid(),
  negocio_id   uuid not null,
  cliente_id   uuid not null,
  estado       text not null default 'disponible'
               check (estado in ('disponible', 'canjeado', 'vencido')),
  -- Copia del premio vigente al generarse (RN-13)
  descripcion  text not null,
  condiciones  text,
  generado_en  timestamptz not null default now(),
  vence_en     timestamptz,
  canjeado_en  timestamptz,
  canjeado_por uuid references public.usuarios_internos (id),
  foreign key (cliente_id, negocio_id) references public.clientes (id, negocio_id),
  constraint canje_completo check ((estado = 'canjeado') = (canjeado_en is not null))
);
create index premios_cliente_idx on public.premios (cliente_id, estado);
create index premios_negocio_idx on public.premios (negocio_id, estado);

-- Historial (RN-05). cantidad: sellos sumados (+) en 'sello', sellos perdidos (−) en
-- 'vencimiento_sellos', 1 en 'canje' y 'vencimiento_premio' (un premio), libre en 'ajuste'.
create table public.movimientos (
  id         uuid primary key default gen_random_uuid(),
  negocio_id uuid not null,
  cliente_id uuid not null,
  usuario_id uuid references public.usuarios_internos (id),  -- null = lo hizo el sistema
  tipo       text not null
             check (tipo in ('sello', 'canje', 'vencimiento_sellos', 'vencimiento_premio', 'ajuste')),
  cantidad   integer not null check (cantidad <> 0),
  premio_id  uuid references public.premios (id),
  creado_en  timestamptz not null default now(),
  foreign key (cliente_id, negocio_id) references public.clientes (id, negocio_id)
);
create index movimientos_cliente_idx on public.movimientos (cliente_id, creado_en desc);
create index movimientos_negocio_idx on public.movimientos (negocio_id, creado_en desc);
create index movimientos_usuario_idx on public.movimientos (usuario_id);
create index movimientos_premio_idx on public.movimientos (premio_id);
create index premios_canjeado_por_idx on public.premios (canjeado_por);

-- El historial no se edita ni se borra, ni siquiera con la clave secreta (RN-05).
create function public.bloquear_cambios_historial()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'El historial de movimientos no se puede modificar ni borrar'
    using errcode = 'P0001';
end;
$$;

create trigger movimientos_inmutables
  before update or delete on public.movimientos
  for each row execute function public.bloquear_cambios_historial();

create function public.tocar_actualizado_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

create trigger reglas_actualizado_en
  before update on public.reglas_tarjeta
  for each row execute function public.tocar_actualizado_en();
