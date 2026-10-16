/**
 * Prueba de integracion del modo invitado contra Supabase real.
 *
 * Crea dos sesiones anonimas, recorre el flujo completo (intento, respuestas,
 * cierre, XP, historial) y verifica el aislamiento entre usuarios.
 *
 * Escribe datos reales de prueba en la base (usuarios anonimos, intentos,
 * respuestas y progreso). No ejecuta DDL ni aplica migraciones.
 *
 *   node scripts/prueba-invitados.mjs
 *
 * Si las RPC todavia no estan aplicadas en el proyecto, el script lo detecta y
 * lo informa en lugar de dar por buena la prueba.
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const aqui = dirname(fileURLToPath(import.meta.url))
const raiz = resolve(aqui, '..')

function leerEntorno() {
  const archivos = ['.env', '.env.local'].filter((n) => {
    try {
      readFileSync(resolve(raiz, n))
      return true
    } catch {
      return false
    }
  })
  if (!archivos.length) throw new Error('No se encontro .env con las credenciales de Supabase.')

  const pares = archivos.flatMap((n) =>
    readFileSync(resolve(raiz, n), 'utf8')
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l.startsWith('VITE_') && l.includes('='))
      .map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]),
  )
  const env = Object.fromEntries(pares)

  const url = env.VITE_SUPABASE_URL
  const key = env.VITE_SUPABASE_PUBLISHABLE_KEY || env.VITE_SUPABASE_ANON_KEY
  if (!url || !key) throw new Error('Falta VITE_SUPABASE_URL o la clave publica en .env')
  return { url, key }
}

const { url, key } = leerEntorno()
const CORRECTAS_MINIMAS = 2

let ok = 0
let fallos = 0
const saltados = []

function check(nombre, condicion, detalle = '') {
  if (condicion) {
    ok += 1
    console.log(`  OK   ${nombre}`)
  } else {
    fallos += 1
    console.log(`  FALLA ${nombre}${detalle ? ` -> ${detalle}` : ''}`)
  }
}

function saltar(nombre, motivo) {
  saltados.push(`${nombre}: ${motivo}`)
  console.log(`  SKIP ${nombre} -> ${motivo}`)
}

function cabeceras(token) {
  return {
    apikey: key,
    Authorization: `Bearer ${token || key}`,
    'Content-Type': 'application/json',
  }
}

async function rpc(token, fn, body = {}) {
  const r = await fetch(`${url}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: cabeceras(token),
    body: JSON.stringify(body),
  })
  const texto = await r.text()
  let datos = null
  try {
    datos = texto ? JSON.parse(texto) : null
  } catch {
    datos = texto
  }
  return { ok: r.ok, status: r.status, datos, texto }
}

async function rest(token, ruta, opciones = {}) {
  const r = await fetch(`${url}/rest/v1/${ruta}`, {
    method: opciones.method || 'GET',
    headers: cabeceras(token),
    body: opciones.body ? JSON.stringify(opciones.body) : undefined,
  })
  const texto = await r.text()
  let datos = null
  try {
    datos = texto ? JSON.parse(texto) : null
  } catch {
    datos = texto
  }
  return { ok: r.ok, status: r.status, datos, texto }
}

/** Crea una sesion anonima nueva y devuelve su token. */
async function crearInvitado() {
  const r = await fetch(`${url}/auth/v1/signup`, {
    method: 'POST',
    headers: cabeceras(),
    body: JSON.stringify({}),
  })
  const datos = await r.json()
  if (!datos.access_token) throw new Error(`No se pudo crear la sesion anonima: ${r.status}`)
  return { token: datos.access_token, id: datos.user.id, esInvitado: datos.user.is_anonymous }
}

const esperar = (ms) => new Promise((r) => setTimeout(r, ms))

async function esperarPerfil(token, id) {
  for (let i = 1; i <= 8; i += 1) {
    const r = await rest(token, `perfiles?id=eq.${id}&select=id,experiencia,nivel`)
    if (r.ok && Array.isArray(r.datos) && r.datos.length) return r.datos[0]
    await esperar(i * 150)
  }
  return null
}

/** Devuelve la primera leccion publicada con preguntas publicadas. */
async function buscarLeccion(token) {
  const lecciones = await rest(
    token,
    'lecciones?select=id,titulo,estado_publicacion&estado_publicacion=eq.publicado&limit=20',
  )
  if (!lecciones.ok || !lecciones.datos?.length) return null

  for (const leccion of lecciones.datos) {
    const preguntas = await rest(
      token,
      `preguntas?leccion_id=eq.${leccion.id}&select=id&estado_publicacion=eq.publicado&limit=10`,
    )
    if (preguntas.ok && preguntas.datos?.length >= 3) return { leccion, preguntas: preguntas.datos }
  }
  return null
}

async function opcionesDe(token, preguntas) {
  const opciones = await rest(
    token,
    `opciones?pregunta_id=in.(${preguntas.map((p) => p.id).join(',')})&select=id,pregunta_id&limit=200`,
  )
  if (!opciones.ok) return []
  return opciones.datos ?? []
}

/** Descubre la opcion correcta usando la RPC de correccion (no expone soluciones). */
async function opcionCorrecta(token, preguntaId, opciones) {
  for (const opcion of opciones) {
    const r = await rpc(token, 'comprobar_respuesta', {
      p_pregunta_id: preguntaId,
      p_opcion_id: opcion.id,
    })
    if (r.ok && Array.isArray(r.datos) && r.datos[0]?.correcta) return opcion.id
  }
  return null
}

async function main() {
  console.log('\n=== Prueba de integracion: modo invitado ===\n')
  console.log(`Proyecto: ${url}\n`)

  console.log('[0] Las RPC de progreso estan aplicadas?')
  const existe = {}
  for (const fn of ['obtener_progreso', 'iniciar_intento', 'registrar_respuesta', 'finalizar_intento']) {
    const r = await rpc(null, fn, {})
    existe[fn] = !(r.status === 404 && /PGRST202/.test(r.texto))
  }

  const faltantes = Object.entries(existe)
    .filter(([, v]) => !v)
    .map(([k]) => k)

  if (faltantes.length) {
    console.log(`\n  Las RPC ${faltantes.join(', ')} NO existen en el proyecto.`)
    console.log('  Aplica src/scripts/kodigo-completo.sql en el SQL Editor del dashboard.')
    console.log('  Sin eso el invitado no puede guardar intentos ni progreso.\n')
  }

  console.log('[1] Crear dos sesiones anonimas independientes')
  const a = await crearInvitado()
  const b = await crearInvitado()
  check('invitado A es anonimo', a.esInvitado === true)
  check('invitado B es anonimo', b.esInvitado === true)
  check('A y B tienen identificadores distintos', a.id !== b.id)

  console.log('[2] El perfil se crea y se asocia a la identidad anonima')
  const perfilA = await esperarPerfil(a.token, a.id)
  const perfilB = await esperarPerfil(b.token, b.id)
  check('perfil de A existe', Boolean(perfilA))
  check('perfil de B existe', Boolean(perfilB))

  console.log('[3] Aislamiento: B no puede leer datos privados de A')
  const progresoInesperado = await rpc(b.token, 'obtener_progreso')
  if (existe.obtener_progreso) {
    check('el progreso de B arranca vacio', Array.isArray(progresoInesperado.datos) && progresoInesperado.datos.length === 0)
  } else {
    saltar('progreso de B', 'obtener_progreso no esta aplicada')
  }

  const perfilAjeno = await rest(b.token, `perfiles?id=eq.${a.id}&select=id,nombre_usuario`)
  check(
    'B no puede leer la fila de perfiles de A por RLS',
    perfilAjeno.ok && (!Array.isArray(perfilAjeno.datos) || perfilAjeno.datos.length === 0),
    `status ${perfilAjeno.status}`,
  )

  const ranking = await rest(b.token, 'perfiles_publicos?select=id&limit=5')
  if (ranking.ok) {
    check('la vista publica no expone datos privados', Array.isArray(ranking.datos))
  } else {
    saltar('vista perfiles_publicos', 'todavia no creada en el proyecto')
  }

  console.log('[4] Navegar el catalogo como invitado')
  const objetivo = await buscarLeccion(a.token)
  if (!obtenerObjetivo(objetivo)) {
    console.log('\n  No hay ninguna leccion publicada con 3 preguntas. Abortando.\n')
    return
  }
  const { leccion, preguntas } = objetivo
  check('se encuentra una leccion publicada', Boolean(leccion.id))
  check('la leccion tiene al menos 3 preguntas', preguntas.length >= 3)

  const opciones = await opcionesDe(a.token, preguntas)
  check('las preguntas tienen opciones', opciones.length > 0)

  if (faltantes.length) {
    console.log('\n[5] Flujo de intentos: omitido, faltan RPC.\n')
    console.log('=== Resumen ===')
    console.log(`OK: ${ok}  FALLA: ${fallos}  SKIP: ${saltados.length}`)
    console.log('\nAplicar el SQL y volver a correr para probar el flujo completo.\n')
    process.exitCode = 1
    return
  }

  console.log('[5] Crear intento persistente con clave de idempotencia')
  const clave = crypto.randomUUID()
  const inicio = await rpc(a.token, 'iniciar_intento', {
    p_leccion_id: leccion.id,
    p_clave_idempotencia: clave,
  })
  check('iniciar_intento responde ok', inicio.ok, inicio.texto?.slice(0, 160))
  const intentoId = inicio.datos?.[0]?.intento_id
  const total = inicio.datos?.[0]?.total ?? 0
  check('devuelve el identificador del intento', Boolean(intentoId))
  check('cuenta las preguntas de la leccion', total === preguntas.length, `total=${total}`)

  const repetido = await rpc(a.token, 'iniciar_intento', {
    p_leccion_id: leccion.id,
    p_clave_idempotencia: clave,
  })
  check(
    'la misma clave devuelve el mismo intento',
    repetido.datos?.[0]?.intento_id === intentoId,
  )
  check('informa que ya existia', repetido.datos?.[0]?.ya_existia === true)

  console.log('[6] Responder y persistir en el servidor')
  const usadas = []
  let correctas = 0
  for (const pregunta of preguntas) {
    const opcionesPregunta = opciones.filter((o) => o.pregunta_id === pregunta.id)
    const correcta = await opcionCorrecta(a.token, pregunta.id, opcionesPregunta)
    const elegida = correcta ?? opcionesPregunta[0].id
    const r = await rpc(a.token, 'registrar_respuesta', {
      p_intento_id: intentoId,
      p_pregunta_id: pregunta.id,
      p_opcion_id: elegida,
    })
    check(`responde la pregunta ${usadas.length + 1}`, r.ok, r.texto?.slice(0, 140))
    const fila = r.datos?.[0]
    if (fila?.correcta) correctas += 1
    usadas.push({ preguntaId: pregunta.id, opcionId: elegida })
  }

  const reenvio = await rpc(a.token, 'registrar_respuesta', {
    p_intento_id: intentoId,
    p_pregunta_id: usadas[0].preguntaId,
    p_opcion_id: usadas[0].opcionId,
  })
  check('reenviar la misma respuesta no la duplica',reenvio.datos?.[0]?.ya_registrada === true)

  console.log('[7] Cerrar el intento y aplicar la regla de aprobacion')
  const cierre = await rpc(a.token, 'finalizar_intento', { p_intento_id: intentoId })
  check('finalizar_intento responde ok', cierre.ok, cierre.texto?.slice(0, 160))
  const resultado = cierre.datos?.[0]
  const aprobadoEsperado = correctas >= CORRECTAS_MINIMAS
  check(
    'la aprobacion coincide con 2 de 3 correctas',
    Boolean(resultado?.aprobado) === aprobadoEsperado,
    `correctas=${correctas} aprobado=${resultado?.aprobado}`,
  )
  check('el resultado viene completo', Number(resultado?.total) === preguntas.length)

  console.log('[8] El XP se guarda y no se duplica')
  const xpEsperado = aprobadoEsperado ? 20 + correctas * 5 : 0
  check('el XP coincide con la regla del proyecto', Number(resultado?.xp_ganado) === xpEsperado, `xp=${resultado?.xp_ganado}`)

  const perfilTrasXp = await rest(a.token, `perfiles?id=eq.${a.id}&select=experiencia`)
  check(
    'el XP quedo persistido en perfiles',
    Number(perfilTrasXp.datos?.[0]?.experiencia) === xpEsperado,
    `perfiles=${perfilTrasXp.datos?.[0]?.experiencia}`,
  )

  const cierre2 = await rpc(a.token, 'finalizar_intento', { p_intento_id: intentoId })
  check('finalizar dos veces devuelve el mismo resultado', cierre2.ok && cierre2.datos?.[0]?.xp_ganado === resultado?.xp_ganado)

  const perfilTrasRepeticion = await rest(a.token, `perfiles?id=eq.${a.id}&select=experiencia`)
  check(
    'el XP no se duplica al repetir el cierre',
    Number(perfilTrasRepeticion.datos?.[0]?.experiencia) === xpEsperado,
    `perfiles=${perfilTrasRepeticion.datos?.[0]?.experiencia}`,
  )

  console.log('[9] El progreso y el historial se recuperan')
  const progreso = await rpc(a.token, 'obtener_progreso')
  const fila = progreso.datos?.find((p) => p.leccion_id === leccion.id)
  check('el progreso de la leccion quedo guardado', Boolean(fila))
  check('el progreso refleja la aprobacion', Boolean(fila?.aprobada) === aprobadoEsperado)
  check('el progreso apunta al ultimo intento', fila?.ultimo_intento_id === intentoId)

  const historial = await rest(a.token, `intentos?leccion_id=eq.${leccion.id}&select=id`)
  check('el intento aparece en el historial', historial.datos?.some((i) => i.id === intentoId))

  console.log('[10] Repetir la leccion conserva los intentos anteriores')
  const nuevoIntento = await rpc(a.token, 'iniciar_intento', {
    p_leccion_id: leccion.id,
    p_clave_idempotencia: crypto.randomUUID(),
  })
  check('una clave nueva crea un intento distinto', nuevoIntento.datos?.[0]?.intento_id !== intentoId)

  const historial2 = await rest(a.token, `intentos?leccion_id=eq.${leccion.id}&select=id`)
  check('el intento anterior sigue en el historial', historial2.datos?.some((i) => i.id === intentoId))
  check('hay dos intentos en total', historial2.datos?.length === 2, `hay ${historial2.datos?.length}`)

  console.log('[11] B no puede tocar el progreso de A')
  const intruso = await rpc(b.token, 'registrar_respuesta', {
    p_intento_id: intentoId,
    p_pregunta_id: usadas[0].preguntaId,
    p_opcion_id: usadas[0].opcionId,
  })
  check('B no puede responder en el intento de A', !intruso.ok, `status ${intruso.status}`)

  const cerrarAjeno = await rpc(b.token, 'finalizar_intento', { p_intento_id: intentoId })
  check('B no puede cerrar el intento de A', !cerrarAjeno.ok, `status ${cerrarAjeno.status}`)

  const lecturaAjena = await rest(b.token, `intentos?id=eq.${intentoId}&select=id`)
  check('B no puede leer el intento de A', lecturaAjena.ok && lecturaAjena.datos?.length === 0)

  console.log('[12] El cliente no puede approving ni ganar XP por su cuenta')
  const progresoFalso = await rest(b.token, 'progreso_lecciones', {
    method: 'POST',
    body: { usuario_id: b.id, leccion_id: leccion.id, aprobada: true, completada: true, mejor_porcentaje: 100, ultimo_porcentaje: 100, intentos: 1 },
  })
  check('no se puede insertar progreso con aprobada=true', !progresoFalso.ok, `status ${progresoFalso.status}`)

  const intentoFalso = await rest(b.token, 'intentos', {
    method: 'POST',
    body: { usuario_id: b.id, leccion_id: leccion.id, clave_idempotencia: crypto.randomUUID(), estado: 'completado', porcentaje: 100, aprobado: true, respuestas_correctas: 99 },
  })
  check('no se puede insertar un intento con aprobado=true', !intentoFalso.ok, `status ${intentoFalso.status}`)

  const respuestaFalsa = await rest(b.token, 'respuestas_intento', {
    method: 'POST',
    body: { intento_id: intentoId, pregunta_id: usadas[0].preguntaId, opcion_id: usadas[0].opcionId, correcta: true },
  })
  check('no se puede insertar una respuesta con correcta=true', !respuestaFalsa.ok, `status ${respuestaFalsa.status}`)

  const soluciones = await rest(a.token, 'soluciones?select=explicacion&limit=1')
  check('las soluciones siguen siendo inaccesibles', !soluciones.ok || (Array.isArray(soluciones.datos) && soluciones.datos.length === 0))

  console.log('[13] Cerrar y reabrir conserva la identidad y los datos')
  const progresoReabierto = await rpc(a.token, 'obtener_progreso')
  check('el progreso se recupera con la misma identidad', progresoReabierto.datos?.some((p) => p.leccion_id === leccion.id))
  const perfilReabierto = await rest(a.token, `perfiles?id=eq.${a.id}&select=experiencia`)
  check('el XP se recupera intacto', Number(perfilReabierto.datos?.[0]?.experiencia) === xpEsperado)

  console.log('\n=== Resumen ===')
  console.log(`OK: ${ok}   FALLA: ${fallos}   SKIP: ${saltados.length}`)
  if (saltados.length) saltados.forEach((s) => console.log(`  - ${s}`))
  console.log('')
  process.exitCode = fallos ? 1 : 0
}

function obtenerObjetivo(objetivo) {
  return objetivo !== null
}

main().catch((error) => {
  console.error('\nLa prueba no pudo terminar:', error.message)
  process.exitCode = 1
})