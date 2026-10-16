import { supabase } from '@/supabase'

// ---------------------------------------------------------------------------
// Progreso persistente
//
// La fuente de verdad es Supabase: cada respuesta se corrige y guarda en el
// servidor y el estado final lo calcula el servidor. Aqui solo se mantiene
// una copia en memoria para pintar las pantallas sin un round-trip en cada
// una, que se hidrata con cargarProgreso() al recuperar la sesion.
// ---------------------------------------------------------------------------

const progresoPorLeccion = new Map()
const resumenPorLeccion = new Map()
const cantidadPreguntasPorLeccion = new Map()
const intentoActivoPorLeccion = new Map()
const leccionDeIntento = new Map()

const PREFIJO_CLAVE_INTENTO = 'kodigo.intento.'

export const CORRECTAS_MINIMAS_PARA_APROBAR = 2

function generarUuid() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === 'x' ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}

function claveDeIntento(leccionId) {
  const clave = `${PREFIJO_CLAVE_INTENTO}${leccionId}`
  let valor = null
  try {
    valor = localStorage.getItem(clave)
  } catch {
    valor = null
  }
  if (!valor) {
    valor = generarUuid()
    try {
      localStorage.setItem(clave, valor)
    } catch {
      // Sin almacenamiento local la idempotencia se pierde al recargar,
      // pero el servidor sigue siendo la fuente de verdad.
    }
  }
  return valor
}

function borrarClaveDeIntento(leccionId) {
  try {
    localStorage.removeItem(`${PREFIJO_CLAVE_INTENTO}${leccionId}`)
  } catch {
    // sin almacenamiento local no hay nada que limpiar
  }
}

function mapearResumen(fila) {
  return {
    total: Number(fila.cantidad_preguntas ?? fila.total ?? 0),
    correctas: Number(fila.respuestas_correctas ?? fila.correctas ?? 0),
    incorrectas: Number(fila.respuestas_incorrectas ?? fila.incorrectas ?? 0),
    porcentaje: Math.round(Number(fila.porcentaje ?? 0)),
    completado: Boolean(fila.completado),
    aprobada: Boolean(fila.aprobado),
  }
}

function mapearProgreso(fila) {
  return {
    leccionId: fila.leccion_id,
    completada: Boolean(fila.completada),
    aprobada: Boolean(fila.aprobada),
    intentos: Number(fila.intentos ?? 0),
    mejorPorcentaje: Math.round(Number(fila.mejor_porcentaje ?? 0)),
    ultimoPorcentaje: Math.round(Number(fila.ultimo_porcentaje ?? 0)),
    ultimoIntentoId: fila.ultimo_intento_id,
    aprobadoEn: fila.aprobado_en,
    actualizadoEn: fila.updated_at,
  }
}

/**
 * Descarga el progreso del usuario autenticado y lo deja disponible en
 * memoria. Sin sesion no hay progreso que leer y se limpia la copia local.
 */
export async function cargarProgreso() {
  progresoPorLeccion.clear()
  resumenPorLeccion.clear()

  const { data: sesion } = await supabase.auth.getSession()
  if (!sesion?.session) return progresoPorLeccion

  const { data, error } = await supabase.rpc('obtener_progreso')
  if (error) throw crearError('No se pudo cargar el progreso.', error)

  const filas = data ?? []
  for (const fila of filas) {
    progresoPorLeccion.set(fila.leccion_id, mapearProgreso(fila))
  }

  // El resumen de la ultima intento aporta los conteos exactos de
  // correctas e incorrectas, que progreso_lecciones no guarda.
  const idsIntentos = filas.map((fila) => fila.ultimo_intento_id).filter(Boolean)
  if (idsIntentos.length) {
    const { data: ultimos, error: errorUltimos } = await supabase
      .from('intentos')
      .select(
        'id, leccion_id, cantidad_preguntas, respuestas_correctas, respuestas_incorrectas, porcentaje, completado, aprobado',
      )
      .in('id', idsIntentos)

    if (errorUltimos) throw crearError('No se pudieron cargar los últimos intentos.', errorUltimos)
    for (const fila of ultimos ?? []) {
      resumenPorLeccion.set(fila.leccion_id, mapearResumen(fila))
    }
  }

  return progresoPorLeccion
}

export function obtenerIntentoLeccion(leccionId) {
  return progresoPorLeccion.get(leccionId) ?? null
}

/**
 * Empieza (o recupera) el intento de una leccion. La clave de idempotencia
 * se guarda en el dispositivo, asi que recargar la pagina no crea un intento
 * nuevo ni duplica respuestas.
 */
export async function iniciarIntento(leccionId) {
  if (!leccionId) throw crearError('Falta la lección para iniciar el intento.')

  const { data, error } = await supabase.rpc('iniciar_intento', {
    p_leccion_id: leccionId,
    p_clave_idempotencia: claveDeIntento(leccionId),
  })

  if (error) throw crearError('No se pudo iniciar el intento.', error)

  const fila = (data && data[0]) || {}
  const total = fila.total ?? cantidadPreguntasPorLeccion.get(leccionId) ?? 0
  cantidadPreguntasPorLeccion.set(leccionId, total)
  intentoActivoPorLeccion.set(leccionId, fila.intento_id)
  leccionDeIntento.set(fila.intento_id, leccionId)

  return { intentoId: fila.intento_id, yaExistia: Boolean(fila.ya_existia), total }
}

export function obtenerIntentoActivo(leccionId) {
  return intentoActivoPorLeccion.get(leccionId) ?? null
}

/**
 * Registra la respuesta de una pregunta. El servidor corrige contra
 * soluciones, guarda la respuesta y devuelve el estado recalculado, asi que
 * el cliente nunca decide si acertó.
 */
export async function registrarRespuesta(intentoId, preguntaId, opcionId) {
  if (!intentoId) throw crearError('No hay un intento activo.')

  const { data, error } = await supabase.rpc('registrar_respuesta', {
    p_intento_id: intentoId,
    p_pregunta_id: preguntaId,
    p_opcion_id: opcionId,
  })

  if (error) throw crearError('No se pudo registrar la respuesta.', error)

  const fila = (data && data[0]) || {}
  const leccionId = leccionDeIntento.get(intentoId)
  const resumen = {
    porcentaje: Math.round(Number(fila.porcentaje ?? 0)),
    correctas: Number(fila.correctas ?? 0),
    incorrectas: Math.max(Number(fila.total ?? 0) - Number(fila.correctas ?? 0), 0),
    total: Number(fila.total ?? 0),
    completado: Boolean(fila.completado),
  }

  if (leccionId) {
    resumenPorLeccion.set(leccionId, { ...resumen, aprobada: Number(fila.correctas ?? 0) >= CORRECTAS_MINIMAS_PARA_APROBAR && Boolean(fila.completado) })
  }

  return {
    correcta: Boolean(fila.correcta),
    explicacion: fila.explicacion ?? '',
    yaRegistrada: Boolean(fila.ya_registrada),
    ...resumen,
  }
}

/**
 * Cierra el intento. El servidor calcula el resultado, actualiza el progreso
 * de la leccion y otorga la experiencia solo la primera vez que se aprueba.
 * Es idempotente: llamarla de nuevo devuelve lo mismo sin duplicar nada.
 */
export async function finalizarIntento(intentoId) {
  if (!intentoId) throw crearError('No hay un intento activo.')

  const { data, error } = await supabase.rpc('finalizar_intento', {
    p_intento_id: intentoId,
  })

  if (error) throw crearError('No se pudo finalizar el intento.', error)

  const fila = (data && data[0]) || {}
  const leccionId = leccionDeIntento.get(intentoId)
  const resumen = mapearResumen({
    cantidad_preguntas: fila.total,
    respuestas_correctas: fila.correctas,
    respuestas_incorrectas: fila.incorrectas,
    porcentaje: fila.porcentaje,
    completado: fila.completado,
    aprobado: fila.aprobado,
  })

  if (leccionId) {
    resumenPorLeccion.set(leccionId, resumen)
    // El intento quedo cerrado: la proxima vez que se repita la leccion
    // tiene que empezar uno nuevo.
    borrarClaveDeIntento(leccionId)
    intentoActivoPorLeccion.delete(leccionId)
    leccionDeIntento.delete(intentoId)
  }

  await cargarProgreso()

  return { ...resumen, xpGanado: Number(fila.xp_ganado ?? 0) }
}

/** Permite volver a practicar una leccion creando un intento nuevo. */
export function reiniciarIntentoLeccion(leccionId) {
  if (!leccionId) return null
  borrarClaveDeIntento(leccionId)
  intentoActivoPorLeccion.delete(leccionId)
  resumenPorLeccion.delete(leccionId)
  return null
}

export function obtenerResultadosLeccion(leccionId) {
  const progreso = progresoPorLeccion.get(leccionId)
  const resumen = resumenPorLeccion.get(leccionId)
  const total = resumen?.total ?? cantidadPreguntasPorLeccion.get(leccionId) ?? 0

  return {
    total,
    correctas: resumen?.correctas ?? 0,
    incorrectas: resumen?.incorrectas ?? 0,
    porcentaje: resumen?.porcentaje ?? progreso?.ultimoPorcentaje ?? 0,
    aprobada: progreso?.aprobada ?? resumen?.aprobada ?? false,
    completado: progreso?.completada ?? resumen?.completado ?? false,
  }
}

/** Historial de intentos de una leccion, del mas reciente al mas antiguo. */
export async function obtenerHistorialLeccion(leccionId) {
  if (!leccionId) return []

  const { data, error } = await supabase
    .from('intentos')
    .select(
      'id, estado, porcentaje, respuestas_correctas, respuestas_incorrectas, cantidad_preguntas, completado, aprobado, iniciado_at, finalizado_at',
    )
    .eq('leccion_id', leccionId)
    .order('iniciado_at', { ascending: false })

  if (error) throw crearError('No se pudo cargar el historial de la lección.', error)
  return (data ?? []).map((fila) => ({
    id: fila.id,
    estado: fila.estado,
    porcentaje: Math.round(Number(fila.porcentaje ?? 0)),
    correctas: fila.respuestas_correctas,
    incorrectas: fila.respuestas_incorrectas,
    total: fila.cantidad_preguntas,
    completado: Boolean(fila.completado),
    aprobada: Boolean(fila.aprobado),
    iniciadoEn: fila.iniciado_at,
    finalizadoEn: fila.finalizado_at,
  }))
}

/** Resumen global para el perfil y la pantalla de progreso. */
export function obtenerResumenProgreso() {
  let aprobadas = 0
  let completadas = 0
  let intentos = 0

  for (const progreso of progresoPorLeccion.values()) {
    if (progreso.aprobada) aprobadas += 1
    if (progreso.completada) completadas += 1
    intentos += progreso.intentos
  }

  return { aprobadas, completadas, intentos }
}
// Consultas a Supabase
// ---------------------------------------------------------------------------

function crearError(mensaje, error) {
  const detalle = error?.message ? ` (${error.message})` : ''
  return new Error(`${mensaje}${detalle}`)
}

function mapearCurso(fila) {
  return {
    id: fila.id,
    nombre: fila.nombre,
    lema: fila.lema ?? '',
    descripcion: fila.descripcion ?? '',
    monograma: fila.monograma ?? (fila.nombre || '').slice(0, 2).toUpperCase(),
    logo: fila.logo ?? null,
    colorAcento: fila.color_acento ?? '#8e05c2',
    orden: fila.orden,
    estadoPublicacion: fila.estado_publicacion,
    disponible: fila.estado_publicacion === 'publicado',
    progreso: 0,
  }
}

function mapearUnidad(fila, cantidadLecciones = 0, progreso = 0, estado = 'disponible') {
  return {
    id: fila.id,
    cursoId: fila.curso_id,
    nombre: fila.nombre,
    descripcion: fila.descripcion ?? '',
    orden: fila.orden,
    estadoPublicacion: fila.estado_publicacion,
    cantidadLecciones,
    progreso,
    estado,
  }
}

function mapearLeccion(fila, cantidadPreguntas = 0, estado = 'disponible') {
  return {
    id: fila.id,
    unidadId: fila.unidad_id,
    titulo: fila.titulo,
    explicacion: fila.explicacion,
    ejemploCodigo: fila.ejemplo_codigo ?? '',
    orden: fila.orden,
    estadoPublicacion: fila.estado_publicacion,
    cantidadPreguntas,
    estado,
  }
}

function mapearPregunta(fila, opciones) {
  return {
    id: fila.id,
    leccionId: fila.leccion_id,
    enunciado: fila.enunciado,
    orden: fila.orden,
    opciones,
  }
}

function estadoPorIntento(leccionId) {
  const intento = obtenerIntentoLeccion(leccionId)
  if (!intento || !intento.completado) return 'disponible'
  return intento.aprobada ? 'aprobada' : 'completada'
}

export async function obtenerCursos() {
  const { data, error } = await supabase
    .from('cursos')
    .select('*')
    .eq('estado_publicacion', 'publicado')
    .order('orden', { ascending: true })

  if (error) throw crearError('No se pudieron cargar los cursos.', error)

  return (data ?? []).map(mapearCurso)
}

export async function obtenerCurso(cursoId) {
  const { data, error } = await supabase
    .from('cursos')
    .select('*')
    .eq('id', cursoId)
    .eq('estado_publicacion', 'publicado')
    .maybeSingle()

  if (error) throw crearError('No se pudo cargar el curso.', error)

  return data ? mapearCurso(data) : null
}

function calcularProgresoUnidad(idsLecciones) {
  if (!idsLecciones.length) return 0
  const aprobadas = idsLecciones.filter((id) => obtenerIntentoLeccion(id)?.aprobada).length
  return Math.round((aprobadas / idsLecciones.length) * 100)
}

export async function obtenerUnidades(cursoId) {
  const { data: unidades, error } = await supabase
    .from('unidades')
    .select('*')
    .eq('curso_id', cursoId)
    .order('orden', { ascending: true })

  if (error) throw crearError('No se pudieron cargar las unidades.', error)

  const filasUnidades = unidades ?? []
  const idsUnidades = filasUnidades.map((unidad) => unidad.id)

  let filasLecciones = []
  if (idsUnidades.length) {
    const { data: lecciones, error: errorLecciones } = await supabase
      .from('lecciones')
      .select('id, unidad_id, estado_publicacion')
      .in('unidad_id', idsUnidades)

    if (errorLecciones) throw crearError('No se pudieron cargar las lecciones.', errorLecciones)
    filasLecciones = lecciones ?? []
  }

  return filasUnidades.map((unidad) => {
    const leccionesUnidad = filasLecciones.filter((leccion) => leccion.unidad_id === unidad.id)
    const idsPublicadas = leccionesUnidad
      .filter((leccion) => leccion.estado_publicacion === 'publicado')
      .map((leccion) => leccion.id)
    const cantidadLecciones = idsPublicadas.length
    const progreso = calcularProgresoUnidad(idsPublicadas)

    let estado = 'disponible'
    if (unidad.estado_publicacion !== 'publicado') estado = 'bloqueada'
    else if (progreso >= 100) estado = 'completada'

    return mapearUnidad(unidad, cantidadLecciones, progreso, estado)
  })
}

export async function obtenerUnidad(cursoId, unidadId) {
  const { data, error } = await supabase
    .from('unidades')
    .select('*')
    .eq('id', unidadId)
    .eq('curso_id', cursoId)
    .maybeSingle()

  if (error) throw crearError('No se pudo cargar la unidad.', error)

  if (!data) return null

  const estado = data.estado_publicacion === 'publicado' ? 'disponible' : 'bloqueada'
  return mapearUnidad(data, 0, 0, estado)
}

export async function obtenerUnidadPorId(unidadId) {
  const { data, error } = await supabase
    .from('unidades')
    .select('*')
    .eq('id', unidadId)
    .maybeSingle()

  if (error) throw crearError('No se pudo cargar la unidad.', error)

  if (!data) return null

  const estado = data.estado_publicacion === 'publicado' ? 'disponible' : 'bloqueada'
  return mapearUnidad(data, 0, 0, estado)
}

export async function obtenerLecciones(unidadId) {
  const { data: lecciones, error } = await supabase
    .from('lecciones')
    .select('*')
    .eq('unidad_id', unidadId)
    .eq('estado_publicacion', 'publicado')
    .order('orden', { ascending: true })

  if (error) throw crearError('No se pudieron cargar las lecciones.', error)

  const filas = lecciones ?? []
  const idsLecciones = filas.map((leccion) => leccion.id)

  let conteoPreguntas = {}
  if (idsLecciones.length) {
    const { data: preguntas, error: errorPreguntas } = await supabase
      .from('preguntas')
      .select('id, leccion_id')
      .in('leccion_id', idsLecciones)
      .eq('estado_publicacion', 'publicado')

    if (errorPreguntas) throw crearError('No se pudieron cargar las preguntas.', errorPreguntas)

    conteoPreguntas = (preguntas ?? []).reduce((conteo, pregunta) => {
      conteo[pregunta.leccion_id] = (conteo[pregunta.leccion_id] ?? 0) + 1
      return conteo
    }, {})
  }

  return filas.map((fila, index) => {
    const estado = calcularEstadoLeccion(fila, index, filas)
    return mapearLeccion(fila, conteoPreguntas[fila.id] ?? 0, estado)
  })
}

function calcularEstadoLeccion(fila, index, leccionesDeLaUnidad) {
  if (index > 0) {
    const anterior = leccionesDeLaUnidad[index - 1]
    if (!obtenerIntentoLeccion(anterior.id)?.aprobada) {
      return 'bloqueada'
    }
  }
  return estadoPorIntento(fila.id)
}

export async function obtenerLeccion(leccionId) {
  const { data, error } = await supabase
    .from('lecciones')
    .select('*')
    .eq('id', leccionId)
    .eq('estado_publicacion', 'publicado')
    .maybeSingle()

  if (error) throw crearError('No se pudo cargar la lección.', error)

  if (!data) return null

  const { count, error: errorConteo } = await supabase
    .from('preguntas')
    .select('id', { count: 'exact', head: true })
    .eq('leccion_id', leccionId)
    .eq('estado_publicacion', 'publicado')

  if (errorConteo) throw crearError('No se pudo contar las preguntas.', errorConteo)

  cantidadPreguntasPorLeccion.set(leccionId, count ?? 0)

  return mapearLeccion(data, count ?? 0, estadoPorIntento(data.id))
}

export async function obtenerPreguntas(leccionId) {
  const { data: preguntas, error } = await supabase
    .from('preguntas')
    .select('*')
    .eq('leccion_id', leccionId)
    .eq('estado_publicacion', 'publicado')
    .order('orden', { ascending: true })

  if (error) throw crearError('No se pudieron cargar las preguntas.', error)

  const filasPreguntas = preguntas ?? []
  const idsPreguntas = filasPreguntas.map((pregunta) => pregunta.id)

  let filasOpciones = []
  if (idsPreguntas.length) {
    const { data: opciones, error: errorOpciones } = await supabase
      .from('opciones')
      .select('*')
      .in('pregunta_id', idsPreguntas)
      .order('orden', { ascending: true })

    if (errorOpciones) throw crearError('No se pudieron cargar las opciones.', errorOpciones)
    filasOpciones = opciones ?? []
  }

  cantidadPreguntasPorLeccion.set(leccionId, filasPreguntas.length)

  return filasPreguntas.map((pregunta) => {
    const opciones = filasOpciones
      .filter((opcion) => opcion.pregunta_id === pregunta.id)
      .map((opcion) => ({ id: opcion.id, texto: opcion.texto }))
    return mapearPregunta(pregunta, opciones)
  })
}

export async function obtenerPreguntaPorId(preguntaId) {
  const { data, error } = await supabase
    .from('preguntas')
    .select('id, leccion_id')
    .eq('id', preguntaId)
    .eq('estado_publicacion', 'publicado')
    .maybeSingle()

  if (error) throw crearError('No se pudo cargar la pregunta.', error)

  return data ? { id: data.id, leccionId: data.leccion_id } : null
}

// Comprueba la respuesta en el servidor mediante la función comprobar_respuesta.
// Devuelve { correcta, explicacion } y NO expone la solución correcta al cliente.
export async function comprobarRespuesta(preguntaId, opcionId) {
  const { data, error } = await supabase.rpc('comprobar_respuesta', {
    p_pregunta_id: preguntaId,
    p_opcion_id: opcionId,
  })

  if (error) throw crearError('No se pudo comprobar la respuesta.', error)

  const resultado = (data && data[0]) || { correcta: false, explicacion: '' }

  return {
    correcta: Boolean(resultado.correcta),
    explicacion: resultado.explicacion ?? '',
  }
}

// ---------------------------------------------------------------------------
// Perfiles públicos (Liga de Honor / Buscar amigos)
// Solo se piden los campos que el mock muestra de otros usuarios. El correo
// nunca vive en perfiles, asi que no hay dato privado en este select.
// ---------------------------------------------------------------------------

export async function obtenerPerfilesPublicos() {
  const { data, error } = await supabase
    .from('perfiles')
    .select('id, nombre_usuario, nivel')
    .order('experiencia', { ascending: false })
    .limit(50)

  if (error) throw crearError('No se pudieron cargar los perfiles.', error)

  return (data ?? []).map((fila) => ({
    id: fila.id,
    alias: fila.nombre_usuario,
    nivel: fila.nivel,
  }))
}

export async function obtenerRanking() {
  const { data, error } = await supabase
    .from('perfiles')
    .select('id, nombre_usuario, nivel, experiencia, racha_dias')
    .order('experiencia', { ascending: false })
    .limit(20)

  if (error) throw crearError('No se pudo cargar el ranking.', error)

  return data ?? []
}

// ---------------------------------------------------------------------------
// Slugs para URLs legibles
// ---------------------------------------------------------------------------
// Las rutas usan nombres legibles ("javascript", "variables-y-datos") en vez de
// UUID. El slug se deriva del nombre y se resuelve contra la base, asi que no
// hace falta agregar columnas. Las rutas siguen aceptando UUID, de modo que los
// enlaces con los IDs continues funcionando.

export function aSlug(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function pareceUuid(valor) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(valor ?? ''))
}

// Acepta slug o UUID y devuelve el curso.
export async function resolverCurso(ref) {
  if (!ref) return null
  if (pareceUuid(ref)) return obtenerCurso(ref)
  const cursos = await obtenerCursos()
  return cursos.find((curso) => aSlug(curso.nombre) === ref) ?? null
}

// Acepta slug o UUID de unidad dentro del curso ya resuelto.
export async function resolverUnidad(curso, ref) {
  if (!curso || !ref) return null
  if (pareceUuid(ref)) return obtenerUnidad(curso.id, ref)
  const unidades = await obtenerUnidades(curso.id)
  return unidades.find((unidad) => aSlug(unidad.nombre) === ref) ?? null
}

// Acepta slug o UUID de leccion dentro de la unidad ya resuelta.
export async function resolverLeccion(unidad, ref) {
  if (!unidad || !ref) return null
  if (pareceUuid(ref)) return obtenerLeccion(ref)
  const lecciones = await obtenerLecciones(unidad.id)
  return lecciones.find((leccion) => aSlug(leccion.titulo) === ref) ?? null
}

// ---------------------------------------------------------------------------
// Helpers de navegación
// ---------------------------------------------------------------------------

export function rutaUnidad(unidad, curso) {
  return {
    name: 'unidad',
    params: { curso: aSlug(curso?.nombre), unidad: aSlug(unidad?.nombre) },
  }
}

export function rutaLeccion(leccion, unidad, curso) {
  return {
    name: 'leccion',
    params: {
      curso: aSlug(curso?.nombre),
      unidad: aSlug(unidad?.nombre),
      leccion: aSlug(leccion?.titulo),
    },
  }
}

export function rutaPregunta(leccion, unidad, curso, numeroPregunta) {
  return {
    name: 'actividad-leccion',
    params: {
      curso: aSlug(curso?.nombre),
      unidad: aSlug(unidad?.nombre),
      leccion: aSlug(leccion?.titulo),
      pregunta: String(numeroPregunta ?? 1),
    },
  }
}

export function rutaResultados(leccion, unidad, curso) {
  return {
    name: 'resultados-leccion',
    params: {
      curso: aSlug(curso?.nombre),
      unidad: aSlug(unidad?.nombre),
      leccion: aSlug(leccion?.titulo),
    },
  }
}
