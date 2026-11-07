-- 0003 · Funciones de negocio (documento base, sección 7.1).
-- Toda escritura en clientes, tarjetas, premios y movimientos pasa por acá.
-- Cada función corre completa o no hace nada (una función = una transacción).
-- Los errores con código P0001 traen un mensaje pensado para mostrarse tal cual.

-- Esquema privado: no se publica en la API, solo lo usan las funciones de abajo.
create schema interno;
revoke all on schema interno from public;

-- ── Normalización de datos ingresados ────────────────────────────────────────

create function interno.normalizar_dni(p_dni text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');
begin
  if v !~ '^[0-9]{7,8}$' then
    raise exception 'Revisá el DNI: tiene que tener 7 u 8 números.' using errcode = 'P0001';
  end if;
  return v;
end;
$$;

-- Devuelve el celular en formato internacional (+549 + 10 dígitos), listo para WhatsApp.
-- Acepta lo que la gente escribe: con o sin +54, 9, 0 inicial o 15.
create function interno.normalizar_celular(p_celular text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := regexp_replace(coalesce(p_celular, ''), '\D', '', 'g');
begin
  if v like '00%' then v := substr(v, 3); end if;
  if v like '54%' then v := substr(v, 3); end if;   -- ningún código de área empieza con 5
  if v like '9%'  then v := substr(v, 2); end if;   -- ni con 9
  if v like '0%'  then v := substr(v, 2); end if;
  -- 12 dígitos = vino con el 15. Va después del código de área (2 a 4 dígitos).
  if length(v) = 12 then
    for i in 3..5 loop
      if substr(v, i, 2) = '15' then
        v := left(v, i - 1) || substr(v, i + 2);
        exit;
      end if;
    end loop;
  end if;
  if v !~ '^[1-3][0-9]{9}$' then
    raise exception 'Revisá el celular: código de área sin 0 y número sin 15 (por ejemplo, 299 4123456).'
      using errcode = 'P0001';
  end if;
  return '+549' || v;
end;
$$;

create function interno.normalizar_nombre(p_nombre text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := regexp_replace(btrim(coalesce(p_nombre, '')), '\s+', ' ', 'g');
begin
  if char_length(v) not between 2 and 80 then
    raise exception 'Escribí nombre y apellido.' using errcode = 'P0001';
  end if;
  return v;
end;
$$;

-- ── Piezas internas ──────────────────────────────────────────────────────────

-- Vencimientos al consultar o al cargar (RN-09, RN-10, RN-11). Bloquea la tarjeta
-- hasta el final de la transacción, así dos cargas simultáneas no se pisan.
create function interno.aplicar_vencimientos(p_cliente_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  t public.tarjetas;
  r public.reglas_tarjeta;
begin
  select * into t from public.tarjetas where cliente_id = p_cliente_id for update;
  select * into r from public.reglas_tarjeta where negocio_id = t.negocio_id;

  if r.dias_vencimiento_sellos is not null
     and t.sellos_actuales > 0
     and t.ultimo_sello_en + make_interval(days => r.dias_vencimiento_sellos) <= now() then
    insert into public.movimientos (negocio_id, cliente_id, tipo, cantidad)
    values (t.negocio_id, p_cliente_id, 'vencimiento_sellos', -t.sellos_actuales);
    update public.tarjetas set sellos_actuales = 0 where id = t.id;
  end if;

  with vencidos as (
    update public.premios
    set estado = 'vencido'
    where cliente_id = p_cliente_id and estado = 'disponible' and vence_en <= now()
    returning id, negocio_id
  )
  insert into public.movimientos (negocio_id, cliente_id, tipo, cantidad, premio_id)
  select negocio_id, p_cliente_id, 'vencimiento_premio', 1, id from vencidos;
end;
$$;

-- Lo que ven la caja y el cliente: sellos, premio a obtener, premios disponibles y vencimientos.
create function interno.estado_tarjeta(p_cliente_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'cliente_id',         c.id,
    'nombre',             c.nombre,
    'sellos_actuales',    t.sellos_actuales,
    'sellos_requeridos',  r.sellos_requeridos,
    'premio_titulo',      r.premio_titulo,
    'premio_descripcion', r.premio_descripcion,
    'sellos_vencen_en',
      case when r.dias_vencimiento_sellos is not null and t.sellos_actuales > 0
           then t.ultimo_sello_en + make_interval(days => r.dias_vencimiento_sellos) end,
    'premios_disponibles', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'descripcion', p.descripcion, 'condiciones', p.condiciones,
               'generado_en', p.generado_en, 'vence_en', p.vence_en)
             order by p.generado_en)
      from public.premios p
      where p.cliente_id = c.id and p.estado = 'disponible'
    ), '[]'::jsonb)
  )
  from public.clientes c
  join public.tarjetas t on t.cliente_id = c.id
  join public.reglas_tarjeta r on r.negocio_id = c.negocio_id
  where c.id = p_cliente_id;
$$;

-- Verifica que quien llama sea dueño o cajero activo de un negocio activo (RN-03, RN-12).
-- Devuelve el id de ese negocio.
create function interno.exigir_caja()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_negocio uuid := public.mi_negocio();
begin
  if coalesce(public.mi_rol(), '') not in ('dueno', 'cajero') then
    raise exception 'Solo el dueño o un cajero del negocio pueden hacer esto.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.negocios where id = v_negocio and activo) then
    raise exception 'Este negocio está desactivado: no se pueden registrar clientes ni cargar sellos.'
      using errcode = 'P0001';
  end if;
  return v_negocio;
end;
$$;

-- ── Caja (usuarios internos) ─────────────────────────────────────────────────

-- Busca por DNI. Devuelve null si no existe (la caja ofrece registrarlo).
create function public.buscar_cliente_caja(p_dni text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_negocio uuid := interno.exigir_caja();
  v_cliente uuid;
begin
  select id into v_cliente from public.clientes
  where negocio_id = v_negocio and dni = interno.normalizar_dni(p_dni);
  if v_cliente is null then
    return null;
  end if;
  perform interno.aplicar_vencimientos(v_cliente);
  return interno.estado_tarjeta(v_cliente);
end;
$$;

create function public.registrar_cliente_caja(p_dni text, p_nombre text, p_celular text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_negocio uuid := interno.exigir_caja();
  v_cliente uuid;
begin
  insert into public.clientes (negocio_id, dni, nombre, celular, origen)
  values (v_negocio, interno.normalizar_dni(p_dni), interno.normalizar_nombre(p_nombre),
          interno.normalizar_celular(p_celular), 'caja')
  on conflict (negocio_id, dni) do nothing
  returning id into v_cliente;

  if v_cliente is null then
    raise exception 'Ya hay un cliente con ese DNI en este negocio.' using errcode = 'P0001';
  end if;

  insert into public.tarjetas (negocio_id, cliente_id) values (v_negocio, v_cliente);
  return interno.estado_tarjeta(v_cliente);
end;
$$;

-- RN-04 a RN-07: suma sellos; cada vez que se completa la tarjeta genera un premio
-- y los sellos sobrantes quedan en la tarjeta nueva (D-03).
create function public.cargar_sellos(p_cliente_id uuid, p_cantidad integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_negocio uuid := interno.exigir_caja();
  t public.tarjetas;
  r public.reglas_tarjeta;
  v_total integer;
  v_premios integer;
begin
  if p_cantidad is null or p_cantidad not between 1 and 20 then
    raise exception 'La cantidad tiene que ser entre 1 y 20 sellos.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.clientes where id = p_cliente_id and negocio_id = v_negocio) then
    raise exception 'No encontramos ese cliente en este negocio.' using errcode = 'P0001';
  end if;

  perform interno.aplicar_vencimientos(p_cliente_id);
  select * into t from public.tarjetas where cliente_id = p_cliente_id;
  select * into r from public.reglas_tarjeta where negocio_id = v_negocio;

  v_total   := t.sellos_actuales + p_cantidad;
  v_premios := v_total / r.sellos_requeridos;

  insert into public.premios (negocio_id, cliente_id, descripcion, condiciones, vence_en)
  select v_negocio, p_cliente_id, r.premio_titulo, r.premio_descripcion,
         now() + make_interval(days => r.dias_vencimiento_premio)
  from generate_series(1, v_premios);

  update public.tarjetas
  set sellos_actuales = v_total % r.sellos_requeridos, ultimo_sello_en = now()
  where id = t.id;

  insert into public.movimientos (negocio_id, cliente_id, usuario_id, tipo, cantidad)
  values (v_negocio, p_cliente_id, (select auth.uid()), 'sello', p_cantidad);

  return interno.estado_tarjeta(p_cliente_id)
         || jsonb_build_object('sellos_cargados', p_cantidad, 'premios_generados', v_premios);
end;
$$;

-- RN-08: marca el premio como canjeado y deja registro de quién y cuándo.
create function public.canjear_premio(p_premio_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_negocio uuid := interno.exigir_caja();
  v_cliente uuid;
begin
  select cliente_id into v_cliente from public.premios
  where id = p_premio_id and negocio_id = v_negocio;
  if v_cliente is null then
    raise exception 'No encontramos ese premio en este negocio.' using errcode = 'P0001';
  end if;

  perform interno.aplicar_vencimientos(v_cliente);

  update public.premios
  set estado = 'canjeado', canjeado_en = now(), canjeado_por = (select auth.uid())
  where id = p_premio_id and estado = 'disponible';
  if not found then
    raise exception 'Este premio ya fue canjeado o está vencido.' using errcode = 'P0001';
  end if;

  insert into public.movimientos (negocio_id, cliente_id, usuario_id, tipo, cantidad, premio_id)
  values (v_negocio, v_cliente, (select auth.uid()), 'canje', 1, p_premio_id);

  return interno.estado_tarjeta(v_cliente);
end;
$$;

-- ── Público (sin login) ──────────────────────────────────────────────────────

-- Marca y reglas para las páginas /[slug]. Un negocio desactivado solo muestra su nombre (RN-12).
create function public.negocio_publico(p_slug text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when n.activo then
    jsonb_build_object(
      'slug', n.slug, 'nombre', n.nombre, 'activo', true, 'logo_url', n.logo_url,
      'color_primario', n.color_primario, 'color_secundario', n.color_secundario,
      'sellos_requeridos', r.sellos_requeridos, 'premio_titulo', r.premio_titulo,
      'premio_descripcion', r.premio_descripcion,
      'dias_vencimiento_sellos', r.dias_vencimiento_sellos,
      'dias_vencimiento_premio', r.dias_vencimiento_premio)
  else
    jsonb_build_object('slug', n.slug, 'nombre', n.nombre, 'activo', false)
  end
  from public.negocios n
  join public.reglas_tarjeta r on r.negocio_id = n.id
  where n.slug = lower(btrim(p_slug));
$$;

-- Autorregistro por QR/NFC. Si el DNI ya existe, avisa sin mostrar datos (flujo 5.2).
create function public.registrar_cliente_publico(
  p_slug text, p_dni text, p_nombre text, p_celular text, p_acepta_privacidad boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_negocio public.negocios;
  v_cliente uuid;
begin
  select * into v_negocio from public.negocios where slug = lower(btrim(p_slug));
  if v_negocio.id is null then
    raise exception 'No encontramos este negocio.' using errcode = 'P0001';
  end if;
  if not v_negocio.activo then
    raise exception 'Este negocio no está recibiendo registros por ahora.' using errcode = 'P0001';
  end if;
  if not coalesce(p_acepta_privacidad, false) then
    raise exception 'Para registrarte tenés que aceptar el aviso de privacidad.' using errcode = 'P0001';
  end if;

  insert into public.clientes (negocio_id, dni, nombre, celular, origen, acepto_privacidad_en)
  values (v_negocio.id, interno.normalizar_dni(p_dni), interno.normalizar_nombre(p_nombre),
          interno.normalizar_celular(p_celular), 'autorregistro', now())
  on conflict (negocio_id, dni) do nothing
  returning id into v_cliente;

  if v_cliente is null then
    return jsonb_build_object('estado', 'ya_registrado');
  end if;

  insert into public.tarjetas (negocio_id, cliente_id) values (v_negocio.id, v_cliente);
  return jsonb_build_object('estado', 'creado', 'tarjeta', interno.estado_tarjeta(v_cliente));
end;
$$;

-- RN-14: devuelve solo esa tarjeta si DNI y celular coinciden; si no, null.
create function public.consultar_tarjeta(p_slug text, p_dni text, p_celular text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cliente uuid;
begin
  select c.id into v_cliente
  from public.clientes c
  join public.negocios n on n.id = c.negocio_id
  where n.slug = lower(btrim(p_slug))
    and c.dni = interno.normalizar_dni(p_dni)
    and c.celular = interno.normalizar_celular(p_celular);
  if v_cliente is null then
    return null;
  end if;
  perform interno.aplicar_vencimientos(v_cliente);
  return interno.estado_tarjeta(v_cliente);
end;
$$;

-- ── Quién puede llamar a qué ─────────────────────────────────────────────────
revoke execute on function
  public.buscar_cliente_caja(text),
  public.registrar_cliente_caja(text, text, text),
  public.cargar_sellos(uuid, integer),
  public.canjear_premio(uuid),
  public.negocio_publico(text),
  public.registrar_cliente_publico(text, text, text, text, boolean),
  public.consultar_tarjeta(text, text, text)
  from public, anon, authenticated;

grant execute on function
  public.buscar_cliente_caja(text),
  public.registrar_cliente_caja(text, text, text),
  public.cargar_sellos(uuid, integer),
  public.canjear_premio(uuid)
  to authenticated;

grant execute on function
  public.negocio_publico(text),
  public.registrar_cliente_publico(text, text, text, text, boolean),
  public.consultar_tarjeta(text, text, text)
  to anon, authenticated;
