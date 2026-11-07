// Crea (o actualiza) los usuarios internos de prueba en Supabase: la cuenta de login
// y su fila en usuarios_internos. Necesita que el seed ya esté cargado.
// Uso: npm run crear:usuarios   (lee las claves y contraseñas de .env.local)

import { createClient } from '@supabase/supabase-js';

const { NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SECRET_KEY, SUPERADMIN_EMAIL, SUPERADMIN_PASSWORD, PASSWORD_PRUEBA } =
  process.env;
for (const [nombre, valor] of Object.entries({
  NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SECRET_KEY, SUPERADMIN_EMAIL, SUPERADMIN_PASSWORD, PASSWORD_PRUEBA,
})) {
  if (!valor) throw new Error(`Falta ${nombre} en .env.local`);
}

const VALI = '11111111-1111-4111-8111-111111111111';
const PIZZA = '22222222-2222-4222-8222-222222222222';

const usuarios = [
  { email: SUPERADMIN_EMAIL, password: SUPERADMIN_PASSWORD, rol: 'superadmin', negocio_id: null, nombre: 'Esteban' },
  { email: 'dueno@valisburger.test', password: PASSWORD_PRUEBA, rol: 'dueno', negocio_id: VALI, nombre: 'Dueño Valisburger' },
  { email: 'cajero@valisburger.test', password: PASSWORD_PRUEBA, rol: 'cajero', negocio_id: VALI, nombre: 'Cajero Valisburger' },
  { email: 'dueno@pizzeriademo.test', password: PASSWORD_PRUEBA, rol: 'dueno', negocio_id: PIZZA, nombre: 'Dueño Pizzería Demo' },
  { email: 'cajero@pizzeriademo.test', password: PASSWORD_PRUEBA, rol: 'cajero', negocio_id: PIZZA, nombre: 'Cajero Pizzería Demo' },
];

const supabase = createClient(NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SECRET_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const { data: lista, error: errorLista } = await supabase.auth.admin.listUsers({ perPage: 1000 });
if (errorLista) throw errorLista;

for (const u of usuarios) {
  let id = lista.users.find((x) => x.email === u.email)?.id;
  if (id) {
    const { error } = await supabase.auth.admin.updateUserById(id, { password: u.password });
    if (error) throw error;
  } else {
    const { data, error } = await supabase.auth.admin.createUser({
      email: u.email,
      password: u.password,
      email_confirm: true,
    });
    if (error) throw error;
    id = data.user.id;
  }

  const { error } = await supabase
    .from('usuarios_internos')
    .upsert({ id, rol: u.rol, negocio_id: u.negocio_id, nombre: u.nombre, activo: true });
  if (error) throw error;
  console.log(`ok  ${u.email} (${u.rol})`);
}
