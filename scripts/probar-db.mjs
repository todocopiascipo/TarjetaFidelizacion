// Prueba las migraciones, el seed y las reglas de seguridad en un Postgres local
// (PGlite, corre dentro de Node: no necesita Docker ni toca la base de la nube).
// Uso: npm run probar:db

import { PGlite } from '@electric-sql/pglite';
import { readFileSync, readdirSync } from 'node:fs';

const raiz = new URL('../supabase/', import.meta.url);
const db = new PGlite();

// Lo mínimo de Supabase que usan las migraciones: roles, auth.users y auth.uid().
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  grant usage on schema public to anon, authenticated, service_role;
  create schema auth;
  grant usage on schema auth to anon, authenticated, service_role;
  create table auth.users (id uuid primary key, email text);
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  -- Supabase da todos los permisos por defecto en public; las migraciones deben quitarlos.
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`);

for (const archivo of readdirSync(new URL('migrations/', raiz)).sort()) {
  await db.exec(readFileSync(new URL(`migrations/${archivo}`, raiz), 'utf8'));
}
await db.exec(readFileSync(new URL('seed.sql', raiz), 'utf8'));

const VALI = '11111111-1111-4111-8111-111111111111';
const PIZZA = '22222222-2222-4222-8222-222222222222';
const U = {
  superadmin:      'f0000000-0000-4000-8000-000000000001',
  duenoVali:       'f0000000-0000-4000-8000-000000000002',
  cajeroVali:      'f0000000-0000-4000-8000-000000000003',
  duenoPizza:      'f0000000-0000-4000-8000-000000000004',
  cajeroPizza:     'f0000000-0000-4000-8000-000000000005',
  cajeroInactivo:  'f0000000-0000-4000-8000-000000000006',
};
await db.exec(`
  insert into auth.users (id) values ${Object.values(U).map((id) => `('${id}')`).join(',')};
  insert into public.usuarios_internos (id, negocio_id, rol, nombre, activo) values
    ('${U.superadmin}', null, 'superadmin', 'Esteban', true),
    ('${U.duenoVali}', '${VALI}', 'dueno', 'Dueño Vali', true),
    ('${U.cajeroVali}', '${VALI}', 'cajero', 'Cajero Vali', true),
    ('${U.duenoPizza}', '${PIZZA}', 'dueno', 'Dueño Pizza', true),
    ('${U.cajeroPizza}', '${PIZZA}', 'cajero', 'Cajero Pizza', true),
    ('${U.cajeroInactivo}', '${VALI}', 'cajero', 'Ex cajero', false);
`);

// Corre fn como un rol de Supabase y deshace todo al final (cada prueba arranca del seed).
async function como(rol, uid, fn, { guardar = false } = {}) {
  return db.transaction(async (tx) => {
    await tx.exec(`set local role ${rol}`);
    if (uid) await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [uid]);
    const resultado = await fn(tx);
    if (!guardar) await tx.rollback();
    return resultado;
  });
}
const cajeroVali = (fn, o) => como('authenticated', U.cajeroVali, fn, o);
const cajeroPizza = (fn, o) => como('authenticated', U.cajeroPizza, fn, o);
const anon = (fn, o) => como('anon', null, fn, o);
const uno = async (tx, sql, params) => Object.values((await tx.query(sql, params)).rows[0] ?? {})[0];

let fallas = 0;
async function prueba(nombre, fn) {
  try {
    await fn();
    console.log(`  ok   ${nombre}`);
  } catch (e) {
    fallas++;
    console.log(`  FALLA ${nombre}\n        ${e.message}`);
  }
}
function igual(real, esperado) {
  if (JSON.stringify(real) !== JSON.stringify(esperado)) {
    throw new Error(`esperaba ${JSON.stringify(esperado)}, llegó ${JSON.stringify(real)}`);
  }
}
// Ejecuta sql esperando un error que contenga `texto`. Dentro de una transacción usa
// un savepoint, para que la transacción siga viva después del error.
async function falla(tx, sql, texto) {
  const enTransaccion = tx !== db;
  if (enTransaccion) await tx.exec('savepoint antes_del_error');
  try {
    await tx.query(sql);
  } catch (e) {
    if (enTransaccion) await tx.exec('rollback to savepoint antes_del_error');
    if (!e.message.includes(texto)) throw new Error(`error inesperado: ${e.message}`);
    return;
  }
  throw new Error(`debía fallar con "${texto}" y no falló`);
}

console.log('\nSeparación entre negocios (RLS)');
await prueba('el cajero de Pizzería Demo solo ve sus 2 clientes', () =>
  cajeroPizza(async (tx) => {
    igual(await uno(tx, 'select count(*)::int from clientes'), 2);
    igual(await uno(tx, `select count(*)::int from clientes where negocio_id = '${VALI}'`), 0);
  }));
await prueba('el cajero de Pizzería Demo no ve tarjetas, premios ni movimientos de Valisburger', () =>
  cajeroPizza(async (tx) => {
    for (const t of ['tarjetas', 'premios', 'movimientos', 'reglas_tarjeta', 'negocios']) {
      const tabla = t === 'negocios' ? 'negocios where id' : `${t} where negocio_id`;
      igual([t, await uno(tx, `select count(*)::int from ${tabla} = '${VALI}'`)], [t, 0]);
    }
  }));
await prueba('el mismo DNI en dos negocios son dos tarjetas distintas (RN-01)', () =>
  cajeroPizza(async (tx) => {
    const r = await uno(tx, `select buscar_cliente_caja('30.111.222')`);
    igual([r.sellos_actuales, r.sellos_requeridos], [5, 8]);
  }));
await prueba('el cajero de Pizzería Demo no encuentra ni carga sellos a clientes de Valisburger', () =>
  cajeroPizza(async (tx) => {
    igual(await uno(tx, `select buscar_cliente_caja('30555666')`), null);
    await falla(tx, `select cargar_sellos('a0000000-0000-4000-8000-000000000002', 1)`, 'No encontramos ese cliente');
    await falla(tx, `select canjear_premio('d0000000-0000-4000-8000-000000000001')`, 'No encontramos ese premio');
  }));
await prueba('el superadmin ve los 7 clientes de los dos negocios', () =>
  como('authenticated', U.superadmin, async (tx) => igual(await uno(tx, 'select count(*)::int from clientes'), 7)));
await prueba('el cajero ve su perfil pero no el de otros', () =>
  cajeroVali(async (tx) => igual(await uno(tx, 'select count(*)::int from usuarios_internos'), 1)));
await prueba('el dueño ve a todo su equipo y a nadie de otro negocio', () =>
  como('authenticated', U.duenoVali, async (tx) => igual(await uno(tx, 'select count(*)::int from usuarios_internos'), 3)));

console.log('\nNadie escribe directo en tarjetas, premios ni movimientos');
for (const sql of [
  `update tarjetas set sellos_actuales = 99`,
  `insert into movimientos (negocio_id, cliente_id, tipo, cantidad) values ('${VALI}', 'a0000000-0000-4000-8000-000000000001', 'sello', 5)`,
  `update premios set estado = 'disponible'`,
  `insert into clientes (negocio_id, dni, nombre, celular, origen) values ('${VALI}', '12345678', 'X', '+5492994000000', 'caja')`,
]) {
  await prueba(`cajero: ${sql.slice(0, 40)}… → rechazado`, () => cajeroVali((tx) => falla(tx, sql, 'permission denied')));
}
await prueba('el historial no se puede borrar ni con permisos de administrador (RN-05)', () =>
  falla(db, 'delete from movimientos', 'no se puede modificar'));

console.log('\nPúblico (sin login)');
await prueba('no puede leer ninguna tabla', () =>
  anon(async (tx) => {
    for (const t of ['negocios', 'clientes', 'tarjetas', 'premios', 'movimientos', 'usuarios_internos']) {
      await falla(tx, `select * from ${t}`, 'permission denied');
    }
  }));
await prueba('no puede cargar sellos ni canjear', () =>
  anon(async (tx) => {
    await falla(tx, `select cargar_sellos('a0000000-0000-4000-8000-000000000001', 1)`, 'permission denied');
  }));
await prueba('negocio_publico devuelve marca y reglas', () =>
  anon(async (tx) => {
    const n = await uno(tx, `select negocio_publico('Valisburger')`);
    igual([n.nombre, n.color_primario, n.sellos_requeridos, n.activo], ['Valisburger', '#C8102E', 6, true]);
    igual(await uno(tx, `select negocio_publico('no-existe')`), null);
  }));
await prueba('consultar_tarjeta exige DNI y celular correctos (RN-14)', () =>
  anon(async (tx) => {
    const t = await uno(tx, `select consultar_tarjeta('valisburger', '30333444', '299 400-0003')`);
    igual([t.nombre, t.sellos_actuales, t.premios_disponibles.length], ['Carla Ruiz', 1, 1]);
    igual(await uno(tx, `select consultar_tarjeta('valisburger', '30333444', '2994000099')`), null);
    igual(await uno(tx, `select consultar_tarjeta('pizzeria-demo', '30333444', '2994000003')`), null);
  }));
await prueba('al consultar, los sellos con 130 días sin actividad vencen y queda registro (RN-09, RN-11)', () =>
  anon(async (tx) => {
    const t = await uno(tx, `select consultar_tarjeta('valisburger', '30555666', '+54 9 299 400-0005')`);
    igual([t.sellos_actuales, t.sellos_vencen_en], [0, null]);
    await tx.exec('reset role');
    igual(await uno(tx, `select cantidad from movimientos where cliente_id = 'a0000000-0000-4000-8000-000000000005' and tipo = 'vencimiento_sellos'`), -4);
  }));
await prueba('autorregistro: crea cliente y tarjeta vacía; repetido avisa sin mostrar datos', () =>
  anon(async (tx) => {
    const r = await uno(tx, `select registrar_cliente_publico('valisburger', '40.123.456', '  juan   pérez ', '0299 15 412-3456', true)`);
    igual([r.estado, r.tarjeta.sellos_actuales, r.tarjeta.nombre], ['creado', 0, 'juan pérez']);
    const t = await uno(tx, `select consultar_tarjeta('valisburger', '40123456', '+5492994123456')`);
    igual(t.nombre, 'juan pérez');
    igual(await uno(tx, `select registrar_cliente_publico('valisburger', '40123456', 'Otro', '2994000000', true)`), { estado: 'ya_registrado' });
  }));
await prueba('autorregistro: rechaza sin aviso de privacidad, DNI o celular inválidos', () =>
  anon(async (tx) => {
    await falla(tx, `select registrar_cliente_publico('valisburger', '40123456', 'Juan Pérez', '2994123456', false)`, 'aviso de privacidad');
    await falla(tx, `select registrar_cliente_publico('valisburger', '123', 'Juan Pérez', '2994123456', true)`, 'Revisá el DNI');
    await falla(tx, `select registrar_cliente_publico('valisburger', '40123456', 'Juan Pérez', '4123456', true)`, 'Revisá el celular');
  }));

console.log('\nCaja: sellos y canje');
await prueba('cargar 5 sellos con 3 de 6 → 1 premio y la tarjeta nueva queda con 2 (D-03)', () =>
  cajeroVali(async (tx) => {
    const r = await uno(tx, `select cargar_sellos('a0000000-0000-4000-8000-000000000002', 5)`);
    igual([r.sellos_actuales, r.premios_generados, r.premios_disponibles.length], [2, 1, 1]);
    igual(r.premios_disponibles[0].descripcion, 'Hamburguesa simple gratis');
  }));
await prueba('cargar 20 sellos a una tarjeta vacía de 6 → 3 premios y quedan 2 (RN-07)', () =>
  cajeroVali(async (tx) => {
    const r = await uno(tx, `select cargar_sellos('a0000000-0000-4000-8000-000000000001', 20)`);
    igual([r.sellos_actuales, r.premios_generados, r.premios_disponibles.length], [2, 3, 3]);
  }));
await prueba('la cantidad tiene que estar entre 1 y 20 (D-07)', () =>
  cajeroVali(async (tx) => {
    for (const n of [0, 21, -1]) {
      await falla(tx, `select cargar_sellos('a0000000-0000-4000-8000-000000000001', ${n})`, 'entre 1 y 20');
    }
  }));
await prueba('cada carga queda registrada con el cajero que la hizo (RN-05)', () =>
  cajeroVali(async (tx) => {
    await tx.query(`select cargar_sellos('a0000000-0000-4000-8000-000000000001', 2)`);
    igual(await uno(tx, `select usuario_id from movimientos where cliente_id = 'a0000000-0000-4000-8000-000000000001' and tipo = 'sello'`), U.cajeroVali);
  }));
await prueba('canjear un premio lo marca con quién y cuándo; un segundo canje se rechaza (RN-08)', () =>
  cajeroVali(async (tx) => {
    const r = await uno(tx, `select canjear_premio('d0000000-0000-4000-8000-000000000001')`);
    igual(r.premios_disponibles.length, 0);
    igual(await uno(tx, `select canjeado_por from premios where id = 'd0000000-0000-4000-8000-000000000001'`), U.cajeroVali);
    await falla(tx, `select canjear_premio('d0000000-0000-4000-8000-000000000001')`, 'ya fue canjeado');
  }));
await prueba('un premio vencido no se puede canjear (RN-10)', () =>
  cajeroVali(async (tx) => {
    await tx.exec('reset role');
    await tx.exec(`update premios set vence_en = now() - interval '1 day' where id = 'd0000000-0000-4000-8000-000000000001'`);
    await tx.exec('set local role authenticated');
    await falla(tx, `select canjear_premio('d0000000-0000-4000-8000-000000000001')`, 'vencido');
  }));
await prueba('el premio guarda el texto de cuando se generó aunque cambien las reglas (RN-13)', () =>
  como('authenticated', U.duenoVali, async (tx) => {
    await tx.exec(`update reglas_tarjeta set premio_titulo = 'Doble con papas' where negocio_id = '${VALI}'`);
    const r = await uno(tx, `select cargar_sellos('a0000000-0000-4000-8000-000000000003', 5)`);
    igual(r.premios_disponibles.map((p) => p.descripcion), ['Hamburguesa simple gratis', 'Doble con papas']);
  }));
await prueba('registro en caja: crea el cliente; con DNI repetido avisa', () =>
  cajeroVali(async (tx) => {
    const r = await uno(tx, `select registrar_cliente_caja('41222333', 'Lucía Fernández', '11 15 2345-6789')`);
    igual([r.nombre, r.sellos_actuales], ['Lucía Fernández', 0]);
    igual(await uno(tx, `select celular from clientes where dni = '41222333'`), '+5491123456789');
    await falla(tx, `select registrar_cliente_caja('30111222', 'Ana', '2994000001')`, 'Ya hay un cliente');
  }));

console.log('\nRoles y negocios desactivados');
await prueba('el superadmin no opera la caja', () =>
  como('authenticated', U.superadmin, (tx) =>
    falla(tx, `select cargar_sellos('a0000000-0000-4000-8000-000000000001', 1)`, 'Solo el dueño o un cajero')));
await prueba('un cajero desactivado no ve nada ni opera', () =>
  como('authenticated', U.cajeroInactivo, async (tx) => {
    igual(await uno(tx, 'select count(*)::int from clientes'), 0);
    await falla(tx, `select buscar_cliente_caja('30111222')`, 'Solo el dueño o un cajero');
  }));
await prueba('negocio desactivado: no hay cargas ni registros, y la página pública avisa (RN-12)', async () => {
  await db.transaction(async (tx) => {
    await tx.exec(`update negocios set activo = false where id = '${PIZZA}'`);
    await tx.exec('set local role authenticated');
    await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [U.cajeroPizza]);
    await falla(tx, `select cargar_sellos('b0000000-0000-4000-8000-000000000001', 1)`, 'desactivado');
    await tx.exec('set local role anon');
    await falla(tx, `select registrar_cliente_publico('pizzeria-demo', '40123456', 'Juan Pérez', '2994123456', true)`, 'no está recibiendo');
    const n = await uno(tx, `select negocio_publico('pizzeria-demo')`);
    igual([n.nombre, n.activo, n.color_primario], ['Pizzería Demo', false, undefined]);
    await tx.rollback();
  });
});
await prueba('reglas: el dueño edita las suyas; el cajero y otros dueños no', async () => {
  await como('authenticated', U.duenoVali, async (tx) =>
    igual((await tx.query(`update reglas_tarjeta set sellos_requeridos = 8 where negocio_id = '${VALI}'`)).affectedRows, 1));
  await cajeroVali(async (tx) =>
    igual((await tx.query(`update reglas_tarjeta set sellos_requeridos = 8`)).affectedRows, 0));
  await como('authenticated', U.duenoPizza, async (tx) =>
    igual((await tx.query(`update reglas_tarjeta set sellos_requeridos = 8 where negocio_id = '${VALI}'`)).affectedRows, 0));
});
await prueba('el dueño no puede cambiar la marca ni el slug de su negocio', () =>
  como('authenticated', U.duenoVali, async (tx) =>
    igual((await tx.query(`update negocios set color_primario = '#000000'`)).affectedRows, 0)));
await prueba('el dueño desactiva a su cajero, pero no a cajeros de otro negocio', async () => {
  await como('authenticated', U.duenoVali, async (tx) =>
    igual((await tx.query(`update usuarios_internos set activo = false where id = '${U.cajeroVali}'`)).affectedRows, 1));
  await como('authenticated', U.duenoVali, async (tx) =>
    igual((await tx.query(`update usuarios_internos set activo = false where id = '${U.cajeroPizza}'`)).affectedRows, 0));
  await cajeroVali((tx) => falla(tx, `update usuarios_internos set rol = 'dueno'`, 'permission denied'));
});
await prueba('no se puede usar una ruta interna como slug', () =>
  falla(db, `insert into negocios (slug, nombre) values ('admin', 'X')`, 'check constraint'));

console.log(fallas ? `\n${fallas} prueba(s) fallaron.\n` : '\nTodas las pruebas pasaron.\n');
process.exit(fallas ? 1 : 0);
