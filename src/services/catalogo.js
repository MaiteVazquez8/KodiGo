import { supabase } from '@/supabase'

// ---------------------------------------------------------------------------
// Progreso en memoria (por lección)
// ---------------------------------------------------------------------------
// Esta etapa mantiene el progreso solo en memoria durante la sesión. La
// estructura queda preparada para asociar luego cada lección a un usuario,
// cuando se incorporen usuarios y persistencia.

const intentosLeccion = new Map()
const cantidadPreguntasPorLeccion = new Map()

function crearEstadoIntento() {
  return {
    completado: false,
    aprobada: false,
    correctas: 0,
    incorrectas: 0,
    preguntasRespondidas: [],
  }
}

export function obtenerIntentoLeccion(leccionId) {
  if (!leccionId) return null
  return intentosLeccion.get(leccionId) ?? null
}

function asegurarIntentoLeccion(leccionId) {
  if (!intentosLeccion.has(leccionId)) {
    intentosLeccion.set(leccionId, crearEstadoIntento())
  }
  return intentosLeccion.get(leccionId)
}

export function reiniciarIntentoLeccion(leccionId) {
  if (!leccionId) return null
  intentosLeccion.set(leccionId, crearEstadoIntento())
  return intentosLeccion.get(leccionId)
}

export function registrarRespuestaLeccion(leccionId, preguntaId, esCorrecta) {
  const estado = asegurarIntentoLeccion(leccionId)

  // Protección contra dobles contabilizaciones: una pregunta solo se cuenta una vez.
  if (estado.preguntasRespondidas.includes(preguntaId)) {
    return estado
  }

  estado.preguntasRespondidas.push(preguntaId)
  if (esCorrecta) estado.correctas += 1
  else estado.incorrectas += 1

  const total = cantidadPreguntasPorLeccion.get(leccionId)
  if (total) {
    estado.completado = estado.preguntasRespondidas.length >= total
  }

  // Regla: una lección se aprueba con al menos 2 respuestas correctas de 3.
  estado.aprobada = estado.correctas >= 2

  return estado
}

export function obtenerResultadosLeccion(leccionId) {
  const intento = obtenerIntentoLeccion(leccionId)
  const total =
    cantidadPreguntasPorLeccion.get(leccionId) ?? intento?.preguntasRespondidas.length ?? 0
  const correctas = intento?.correctas ?? 0
  const incorrectas = intento?.incorrectas ?? 0
  const porcentaje = total ? Math.round((correctas / total) * 100) : 0

  return {
    total,
    correctas,
    incorrectas,
    porcentaje,
    aprobada: correctas >= 2,
    completado: intento?.completado ?? false,
  }
}

// ---------------------------------------------------------------------------
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
// Helpers de navegación
// ---------------------------------------------------------------------------

export function rutaUnidad(unidad) {
  return {
    name: 'unidad',
    params: { courseId: unidad.cursoId, unitId: unidad.id },
  }
}

export function rutaLeccion(leccion, unidad) {
  return {
    name: 'leccion',
    params: { courseId: unidad.cursoId, unitId: unidad.id, lessonId: leccion.id },
  }
}

export function rutaPregunta(leccion, unidad, preguntaId) {
  return {
    name: 'actividad-leccion',
    params: {
      courseId: unidad.cursoId,
      unitId: unidad.id,
      lessonId: leccion.id,
      activityId: preguntaId,
    },
  }
}

export function rutaResultados(leccion, unidad) {
  return {
    name: 'resultados-leccion',
    params: { courseId: unidad.cursoId, unitId: unidad.id, lessonId: leccion.id },
  }
}
