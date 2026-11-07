// Chequeo rápido de seguridad contra la base real de Supabase (no modifica datos).
// Uso: npm run probar:nube

import { createClient } from '@supabase/supabase-js';
const { NEXT_PUBLIC_SUPABASE_URL: url, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key, PASSWORD_PRUEBA: pw } = process.env;
const nuevo = () => createClient(url, key, { auth: { persistSession: false } });
async function como(email) { const c = nuevo(); const { error } = await c.auth.signInWithPassword({ email, password: pw }); if (error) throw error; return c; }
const cuenta = async (c, t) => { const { count, error } = await c.from(t).select('*', { count: 'exact', head: true }); return error ? `error: ${error.message}` : count; };
const pizza = await como('cajero@pizzeriademo.test');
const vali = await como('cajero@valisburger.test');
const anon = nuevo();
console.log('cajero Pizzería ve clientes:', await cuenta(pizza, 'clientes'), '(esperado 2)');
console.log('cajero Valisburger ve clientes:', await cuenta(vali, 'clientes'), '(esperado 5)');
console.log('cajero Pizzería busca DNI de Eva (Valisburger):', JSON.stringify((await pizza.rpc('buscar_cliente_caja', { p_dni: '30555666' })).data), '(esperado null)');
const r = await pizza.rpc('cargar_sellos', { p_cliente_id: 'a0000000-0000-4000-8000-000000000002', p_cantidad: 1 });
console.log('cajero Pizzería carga sellos a Bruno (Valisburger):', r.error?.message, '(esperado: no encontramos)');
const u = await pizza.from('tarjetas').update({ sellos_actuales: 99 }).eq('negocio_id', '22222222-2222-4222-8222-222222222222');
console.log('cajero Pizzería edita su tarjeta directo:', u.error?.message, '(esperado: permission denied)');
console.log('público lee clientes:', await cuenta(anon, 'clientes'), '(esperado error)');
const n = await anon.rpc('negocio_publico', { p_slug: 'valisburger' });
console.log('público ve marca de Valisburger:', n.data?.nombre, n.data?.color_primario);
const t = await anon.rpc('consultar_tarjeta', { p_slug: 'valisburger', p_dni: '30333444', p_celular: '2994000003' });
console.log('público consulta tarjeta de Carla:', t.data?.sellos_actuales, 'sellos,', t.data?.premios_disponibles?.length, 'premio disponible');
const mal = await anon.rpc('consultar_tarjeta', { p_slug: 'valisburger', p_dni: '30333444', p_celular: '2990000000' });
console.log('público con celular equivocado:', JSON.stringify(mal.data), '(esperado null)');
