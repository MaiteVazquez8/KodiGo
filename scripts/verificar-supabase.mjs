// Verificador de solo lectura contra el proyecto Supabase configurado en .env.
// No usa ni expone credenciales: solo la clave publicable y, opcionalmente,
// una sesión efímera anónima creada para las pruebas (con --invitado).
//
//   node scripts/verificar-supabase.mjs            -> reporte público (anon)
//   node scripts/verificar-supabase.mjs --invitado -> además crea UN usuario
//                                                     anónimo de prueba aislado
//
// No modifica datos reales de usuarios. Modo --invitado crea una identidad
// anónima permanente en auth.users (es lo que hace la app); usarlo solo tras
// autorizar las pruebas en vivo y documentar su existencia.

import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const env = readFileSync(resolve(aqui, '..', '.env'), 'utf8')
  .split(/\r?\n/)
  .reduce((acc, line) => {
    const i = line.indexOf('=');
    if (i > 0) acc[line.slice(0, i).trim()] = line.slice(i + 1).trim();
    return acc;
  }, {});
const BASE = env.VITE_SUPABASE_URL;
const KEY = env.VITE_SUPABASE_PUBLISHABLE_KEY;
const CON_INVITADO = process.argv.includes('--invitado');

let ok = 0;
let fallos = 0;
const marca = (nombre, bien, detalle = '') => {
  if (bien) { ok += 1; console.log('  OK   ' + nombre + (detalle ? ' — ' + detalle : '')); }
  else { fallos += 1; console.log('  FALLA ' + nombre + (detalle ? ' — ' + detalle : '')); }
};

async function call(path, opts = {}) {
  const res = await fetch(BASE + path, {
    ...opts,
    headers: { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json', ...(opts.headers ?? {}) },
  });
  const text = await res.text();
  let body;
  try { body = JSON.parse(text); } catch { body = text; }
  return { status: res.status, body, headers: res.headers };
}

(async () => {
  console.log('Proyecto:', new URL(BASE).host);

  console.log('\n== Auth ==');
  const settings = await call('/auth/v1/settings');
  console.log('  settings ->', settings.status);
  marca('Anonymous Sign-Ins habilitado', settings.body?.external?.anonymous_users === true,
    'external.anonymous_users = ' + settings.body?.external?.anonymous_users);
  marca('email habilitado', settings.body?.external?.email === true);
  marca('registro habilitado', settings.body?.disable_signup === false);

  console.log('\n== Esquema público (anon) ==');
  const tablas = ['cursos', 'unidades', 'lecciones', 'preguntas', 'opciones', 'soluciones',
    'intentos', 'respuestas_intento', 'progreso_lecciones', 'progreso_unidades',
    'logros', 'logros_usuario', 'diccionario', 'perfiles',
    'expotec_resultados_publicos', 'expotec_eventos', 'expotec_desafios'];
  for (const t of tablas) {
    const r = await call('/rest/v1/' + t + '?select=*&limit=1');
    if (r.status === 200) {
      const count = Array.isArray(r.body) ? r.body.length : 0;
      marca('tabla ' + t, true, 'visible (filas muestra: ' + count + ')');
    } else {
      marca('tabla ' + t, false, 'status ' + r.status + ' ' + JSON.stringify(r.body).slice(0, 120));
    }
  }

  console.log('\n== Funciones RPC (anon) ==');
  const ZERO = '00000000-0000-0000-0000-000000000000';
  const rpcs = [
    ['comprobar_respuesta', { p_pregunta_id: ZERO, p_respuesta: {} }],
    ['cantidad_preguntas_publicadas', { p_leccion_id: ZERO }],
    ['obtener_diccionario', {}],
    ['es_leccion_publicada', { p_leccion_id: ZERO }],
    ['iniciar_intento', { p_leccion_id: ZERO, p_clave_idempotencia: ZERO }],
    ['registrar_respuesta', { p_intento_id: ZERO, p_pregunta_id: ZERO, p_respuesta: {} }],
    ['finalizar_intento', { p_intento_id: ZERO }],
    ['obtener_progreso', {}],
    ['obtener_estadisticas', {}],
    ['obtener_logros', {}],
    ['obtener_revision', {}],
    ['obtener_amistades', {}],
    ['enviar_solicitud_amistad', { p_alias: 'x' }],
    ['expotec_evento_activo', {}],
    ['expotec_ranking', { p_evento_id: ZERO, p_limite: 5 }],
  ];
  for (const [f, args] of rpcs) {
    const r = await call('/rest/v1/rpc/' + f, { method: 'POST', body: JSON.stringify(args) });
    if (r.status === 404) {
      marca('rpc ' + f, false, 'PGRST202 — no existe en el schema cache');
    } else if (r.status === 401 || r.status === 403) {
      marca('rpc ' + f, true, 'restringida (anon ' + r.status + ')');
    } else {
      marca('rpc ' + f, true, 'disponible (status ' + r.status + ')');
    }
  }

  console.log('\n== Contenido publicado (anon) ==');
  const activos = await call('/rest/v1/preguntas?select=tipo&estado_publicacion=eq.publicado&limit=500');
  if (activos.status === 200) {
    const porTipo = {};
    for (const fila of activos.body) porTipo[fila.tipo] = (porTipo[fila.tipo] ?? 0) + 1;
    console.log('  actividades publicadas por tipo:', JSON.stringify(porTipo));
    marca('hay actividades publicadas', activos.body.length > 0, activos.body.length + ' visibles para anon');
  } else {
    marca('hay actividades publicadas', false, 'status ' + activos.status);
  }
  const cursos = await call('/rest/v1/cursos?select=nombre,estado_publicacion');
  if (cursos.status === 200) {
    console.log('  cursos:', JSON.stringify(cursos.body));
    marca('cursos públicos', cursos.body.some((c) => c.estado_publicacion === 'publicado'));
  }

  if (CON_INVITADO) {
    console.log('\n== Sesión efímera anónima (prueba aislada) ==');
    const r = await call('/auth/v1/signup', {
      method: 'POST',
      body: JSON.stringify({}),
    });
    if (r.status === 200 && r.body?.user?.id) {
      marca('signInAnonymously funciona', true, 'uuid ' + r.body.user.id);
      const rid = r.body.access_token;
      const progreso = await call('/rest/v1/rpc/obtener_progreso', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + rid },
        body: '{}',
      });
      marca('obtener_progreso con invitado', progreso.status === 200,
        'status ' + progreso.status);
      console.log('  NOTA: quedó un usuario anónimo de prueba en auth.users (uuid arriba). No se eliminó; documentar su limpieza.');
    } else {
      marca('signInAnonymously funciona', false, 'status ' + r.status + ' ' + JSON.stringify(r.body).slice(0, 200));
    }
  }

  console.log('\nResultado: ' + ok + ' OK, ' + fallos + ' fallos');
  process.exitCode = fallos > 0 ? 1 : 0;
})().catch((e) => { console.error('FATAL', e); process.exitCode = 1; });
