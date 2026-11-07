-- Datos de ejemplo (documento base, sección 11). Todos ficticios.
-- Los usuarios internos (superadmin, dueños, cajeros) los crea scripts/crear-usuarios.mjs,
-- porque necesitan una cuenta de login además de la fila en usuarios_internos.
-- Se puede correr varias veces: los ids son fijos y los duplicados se ignoran.

insert into public.negocios (id, slug, nombre, color_primario, color_secundario) values
  ('11111111-1111-4111-8111-111111111111', 'valisburger',   'Valisburger',   '#C8102E', '#FFC72C'),
  ('22222222-2222-4222-8222-222222222222', 'pizzeria-demo', 'Pizzería Demo', '#1F7A3A', '#F4E4C1')
on conflict (id) do nothing;

insert into public.reglas_tarjeta (negocio_id, sellos_requeridos, premio_titulo, premio_descripcion) values
  ('11111111-1111-4111-8111-111111111111', 6, 'Hamburguesa simple gratis', 'No incluye papas ni bebida.'),
  ('22222222-2222-4222-8222-222222222222', 8, 'Pizza muzzarella grande gratis', 'Solo para comer en el local.')
on conflict (negocio_id) do nothing;

-- Valisburger: un cliente en cada estado de la tarjeta.
insert into public.clientes (id, negocio_id, dni, nombre, celular, origen, acepto_privacidad_en, creado_en) values
  ('a0000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '30111222', 'Ana Gómez',   '+5492994000001', 'autorregistro', now() - interval '2 days',   now() - interval '2 days'),
  ('a0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', '30222333', 'Bruno Díaz',  '+5492994000002', 'caja',          null,                        now() - interval '30 days'),
  ('a0000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '30333444', 'Carla Ruiz',  '+5492994000003', 'autorregistro', now() - interval '60 days',  now() - interval '60 days'),
  ('a0000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', '30444555', 'Diego López', '+5492994000004', 'caja',          null,                        now() - interval '90 days'),
  ('a0000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', '30555666', 'Eva Torres',  '+5492994000005', 'autorregistro', now() - interval '200 days', now() - interval '200 days'),
-- Pizzería Demo: mismo DNI que Ana, otra persona y otra tarjeta (RN-01).
  ('b0000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', '30111222', 'Ana Gómez',   '+5492994000001', 'caja',          null,                        now() - interval '15 days'),
  ('b0000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', '28999000', 'Pablo Sosa',  '+5492994000099', 'autorregistro', now() - interval '20 days',  now() - interval '20 days')
on conflict (id) do nothing;

insert into public.tarjetas (id, negocio_id, cliente_id, sellos_actuales, ultimo_sello_en) values
  -- tarjeta vacía
  ('c0000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000001', 0, null),
  -- a mitad: 3 de 6
  ('c0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000002', 3, now() - interval '10 days'),
  -- completó la tarjeta con 7 sellos: premio disponible y 1 sello en la nueva
  ('c0000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000003', 1, now() - interval '5 days'),
  -- canjeó su premio y volvió a sumar 2
  ('c0000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000004', 2, now() - interval '15 days'),
  -- 4 sellos sin actividad hace 130 días: vencen en la próxima consulta o carga
  ('c0000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000005', 4, now() - interval '130 days'),
  ('c0000000-0000-4000-8000-000000000006', '22222222-2222-4222-8222-222222222222', 'b0000000-0000-4000-8000-000000000001', 5, now() - interval '3 days'),
  ('c0000000-0000-4000-8000-000000000007', '22222222-2222-4222-8222-222222222222', 'b0000000-0000-4000-8000-000000000002', 2, now() - interval '8 days')
on conflict (id) do nothing;

insert into public.premios (id, negocio_id, cliente_id, estado, descripcion, condiciones, generado_en, vence_en, canjeado_en) values
  ('d0000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000003',
   'disponible', 'Hamburguesa simple gratis', 'No incluye papas ni bebida.', now() - interval '5 days',  now() + interval '25 days', null),
  ('d0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000004',
   'canjeado',   'Hamburguesa simple gratis', 'No incluye papas ni bebida.', now() - interval '40 days', now() - interval '10 days', now() - interval '20 days')
on conflict (id) do nothing;

insert into public.movimientos (id, negocio_id, cliente_id, tipo, cantidad, premio_id, creado_en) values
  ('e0000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000002', 'sello', 3, null, now() - interval '10 days'),
  ('e0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000003', 'sello', 7, null, now() - interval '5 days'),
  ('e0000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000004', 'sello', 6, null, now() - interval '40 days'),
  ('e0000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000004', 'canje', 1, 'd0000000-0000-4000-8000-000000000002', now() - interval '20 days'),
  ('e0000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000004', 'sello', 2, null, now() - interval '15 days'),
  ('e0000000-0000-4000-8000-000000000006', '11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000005', 'sello', 4, null, now() - interval '130 days'),
  ('e0000000-0000-4000-8000-000000000007', '22222222-2222-4222-8222-222222222222', 'b0000000-0000-4000-8000-000000000001', 'sello', 5, null, now() - interval '3 days'),
  ('e0000000-0000-4000-8000-000000000008', '22222222-2222-4222-8222-222222222222', 'b0000000-0000-4000-8000-000000000002', 'sello', 2, null, now() - interval '8 days')
on conflict (id) do nothing;
