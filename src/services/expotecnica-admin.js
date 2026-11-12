import { supabase } from '@/supabase'

// ---------------------------------------------------------------------------
// Desafio ExpoTecnica - cliente de las RPC del panel de administracion
//
// Cada operacion del panel vive en una RPC expotec_admin_* con guard interno:
// es el servidor el que decide quien es administrador (tabla expotec_admins
// poblada por SQL). El cliente solo pasa parametros y pinta errores.
// ---------------------------------------------------------------------------

function errorDe(nombre, error) {
  const mensaje = error?.message || `No se pudo ejecutar ${nombre}.`
  const e = new Error(mensaje)
  e.codigo = error?.code
  return e
}

function aNumero(valor, defecto = 0) {
  const n = Number(valor)
  return Number.isFinite(n) ? n : defecto
}

export async function esAdmin() {
  const { data, error } = await supabase.rpc('expotec_admin_es_admin')
  if (error) throw errorDe('expotec_admin_es_admin', error)
  return Boolean(data)
}

// ---------------------------------------------------------------------------
// CRUD de contenido
// ---------------------------------------------------------------------------

export async function guardarCurso(id, datos) {
  const { data, error } = await supabase.rpc('expotec_admin_guardar_curso', {
    p_id: id ?? null,
    p_datos: datos,
  })
  if (error) throw errorDe('expotec_admin_guardar_curso', error)
  return data
}

export async function guardarUnidad(id, datos) {
  const { data, error } = await supabase.rpc('expotec_admin_guardar_unidad', {
    p_id: id ?? null,
    p_datos: datos,
  })
  if (error) throw errorDe('expotec_admin_guardar_unidad', error)
  return data
}

export async function guardarLeccion(id, datos) {
  const { data, error } = await supabase.rpc('expotec_admin_guardar_leccion', {
    p_id: id ?? null,
    p_datos: datos,
  })
  if (error) throw errorDe('expotec_admin_guardar_leccion', error)
  return data
}

export async function guardarPregunta(id, datos) {
  const { data, error } = await supabase.rpc('expotec_admin_guardar_pregunta', {
    p_id: id ?? null,
    p_datos: datos,
  })
  if (error) throw errorDe('expotec_admin_guardar_pregunta', error)
  return data
}

export async function crearPreguntaCompleta({ leccionId, enunciado, opciones, indiceCorrecta, explicacion, orden }) {
  const { data, error } = await supabase.rpc('expotec_admin_crear_pregunta_completa', {
    p_leccion_id: leccionId,
    p_enunciado: enunciado,
    p_opciones: opciones,
    p_indice_correcta: indiceCorrecta,
    p_explicacion: explicacion,
    p_orden: orden ?? null,
  })
  if (error) throw errorDe('expotec_admin_crear_pregunta_completa', error)
  return data
}

export async function guardarOpcion(id, datos) {
  const { data, error } = await supabase.rpc('expotec_admin_guardar_opcion', {
    p_id: id ?? null,
    p_datos: datos,
  })
  if (error) throw errorDe('expotec_admin_guardar_opcion', error)
  return data
}

export async function definirSolucion(preguntaId, opcionId, explicacion) {
  const { error } = await supabase.rpc('expotec_admin_definir_solucion', {
    p_pregunta_id: preguntaId,
    p_opcion_id: opcionId,
    p_explicacion: explicacion,
  })
  if (error) throw errorDe('expotec_admin_definir_solucion', error)
}

export async function cambiarEstadoContenido(tipo, id, estado) {
  const { error } = await supabase.rpc('expotec_admin_cambiar_estado_contenido', {
    p_tipo: tipo,
    p_id: id,
    p_estado: estado,
  })
  if (error) throw errorDe('expotec_admin_cambiar_estado_contenido', error)
}

// ---------------------------------------------------------------------------
// Contenido para el panel (lecturas con las politicas de administrador)
// ---------------------------------------------------------------------------

export async function listarCursos() {
  const { data, error } = await supabase
    .from('cursos')
    .select('id, nombre, descripcion, lema, monograma, logo, color_acento, orden, estado_publicacion, created_at')
    .order('orden')
  if (error) throw errorDe('listarCursos', error)
  return data ?? []
}

export async function listarUnidadesPorCurso(cursoId) {
  const { data, error } = await supabase
    .from('unidades')
    .select('id, curso_id, nombre, descripcion, orden, estado_publicacion')
    .eq('curso_id', cursoId)
    .order('orden')
  if (error) throw errorDe('listarUnidadesPorCurso', error)
  return data ?? []
}

export async function listarLeccionesPorUnidad(unidadId) {
  const { data, error } = await supabase
    .from('lecciones')
    .select('id, unidad_id, titulo, explicacion, ejemplo_codigo, orden, estado_publicacion')
    .eq('unidad_id', unidadId)
    .order('orden')
  if (error) throw errorDe('listarLeccionesPorUnidad', error)
  return data ?? []
}

export async function listarPreguntasConOpciones(leccionId) {
  const { data, error } = await supabase
    .from('preguntas')
    .select(
      'id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion, opciones(id, pregunta_id, texto, orden)'
    )
    .eq('leccion_id', leccionId)
    .order('orden')
  if (error) throw errorDe('listarPreguntasConOpciones', error)
  return (data ?? []).map((p) => ({
    ...p,
    opciones: (p.opciones ?? []).slice().sort((a, b) => a.orden - b.orden),
  }))
}

export async function listarSolucionesDeLeccion(leccionId) {
  const { data, error } = await supabase
    .from('soluciones')
    .select('id, pregunta_id, opcion_correcta_id, solucion, explicacion, preguntas!inner(leccion_id)')
    .eq('preguntas.leccion_id', leccionId)
  if (error) throw errorDe('listarSolucionesDeLeccion', error)
  return (data ?? []).map((s) => ({
    id: s.id,
    preguntaId: s.pregunta_id,
    opcionCorrectaId: s.opcion_correcta_id,
    solucion: s.solucion ?? {},
    explicacion: s.explicacion,
  }))
}

/**
 * Alta y edicion de una actividad de cualquier modalidad. El servidor valida
 * la estructura, guarda en borrador y solo publica si la actividad esta
 * completa. Las opciones no se pueden cambiar si ya hay respuestas.
 */
export async function guardarActividad(datos) {
  const { data, error } = await supabase.rpc('expotec_admin_guardar_actividad', {
    p_id: datos.id ?? null,
    p_datos: datos,
  })
  if (error) throw errorDe('expotec_admin_guardar_actividad', error)
  return data
}

/**
 * Banco de actividades tipo seleccion para elegir las del desafio: recorre el
 * arbol del catalogo (cursos -> unidades -> lecciones -> preguntas). Las
 * lecturas pasan por las politicas de administrador y los borradores son
 * visibles: lo publicado lo decide el desafio al activar el evento.
 */
export async function listarBancoPreguntas() {
  const cursos = await listarCursos()
  const unidadesAplanadas = await Promise.all(
    cursos.map(async (curso) => {
      const unidades = await listarUnidadesPorCurso(curso.id)
      return unidades.map((u) => ({ ...u, cursoNombre: curso.nombre }))
    }),
  )
  const unidades = unidadesAplanadas.flat()

  const leccionesAplanadas = await Promise.all(
    unidades.map(async (unidad) => {
      const lecciones = await listarLeccionesPorUnidad(unidad.id)
      return lecciones.map((l) => ({
        ...l,
        unidadNombre: unidad.nombre,
        cursoNombre: unidad.cursoNombre,
      }))
    }),
  )
  const lecciones = leccionesAplanadas.flat()

  const preguntasAplanadas = await Promise.all(
    lecciones.map(async (leccion) => {
      const preguntas = await listarPreguntasConOpciones(leccion.id)
      return preguntas.map((p) => ({
        id: p.id,
        enunciado: p.enunciado,
        tipo: p.tipo,
        estadoPublicacion: p.estado_publicacion,
        leccionTitulo: leccion.titulo,
        cursoNombre: leccion.cursoNombre,
        opciones: p.opciones ?? [],
      }))
    }),
  )

  return preguntasAplanadas.flat().filter((p) => p.tipo === 'seleccion')
}

// ---------------------------------------------------------------------------
// Eventos
// ---------------------------------------------------------------------------

export async function listarEventos() {
  const { data, error } = await supabase
    .from('expotec_eventos')
    .select('id, nombre, descripcion, fecha_inicio, fecha_fin, estado, created_at, updated_at')
    .order('created_at', { ascending: false })
  if (error) throw errorDe('listarEventos', error)
  return (data ?? []).map(normalizarEventoAdmin)
}

export function normalizarEventoAdmin(fila) {
  return {
    id: fila.id,
    nombre: fila.nombre,
    descripcion: fila.descripcion,
    fechaInicio: fila.fecha_inicio,
    fechaFin: fila.fecha_fin,
    estado: fila.estado,
    createdAt: fila.created_at,
    updatedAt: fila.updated_at,
  }
}

export async function crearEvento({ nombre, descripcion, fechaInicio, fechaFin }) {
  const { data, error } = await supabase.rpc('expotec_admin_crear_evento', {
    p_nombre: nombre,
    p_descripcion: descripcion ?? null,
    p_fecha_inicio: fechaInicio ?? null,
    p_fecha_fin: fechaFin ?? null,
  })
  if (error) throw errorDe('expotec_admin_crear_evento', error)
  return data
}

export async function actualizarEvento(eventoId, datos) {
  const { error } = await supabase.rpc('expotec_admin_actualizar_evento', {
    p_evento_id: eventoId,
    p_datos: datos,
  })
  if (error) throw errorDe('expotec_admin_actualizar_evento', error)
}

export async function cambiarEstadoEvento(eventoId, estado) {
  const { error } = await supabase.rpc('expotec_admin_cambiar_estado_evento', {
    p_evento_id: eventoId,
    p_estado: estado,
  })
  if (error) throw errorDe('expotec_admin_cambiar_estado_evento', error)
}

// ---------------------------------------------------------------------------
// Desafio
// ---------------------------------------------------------------------------

export async function listarDesafios() {
  const { data, error } = await supabase
    .from('expotec_desafios')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw errorDe('listarDesafios', error)
  return (data ?? []).map((d) => ({
    id: d.id,
    eventoId: d.evento_id,
    nombre: d.nombre,
    version: aNumero(d.version, 1),
    cantidadPreguntas: aNumero(d.cantidad_preguntas, 10),
    puntosPorCorrecta: aNumero(d.puntos_por_correcta, 100),
    tiempoCuestionarioSeg: d.tiempo_cuestionario_seg === null ? null : aNumero(d.tiempo_cuestionario_seg),
    duracionJuegoSeg: aNumero(d.duracion_juego_seg, 180),
    vidasJuego: aNumero(d.vidas_juego, 3),
    mostrarSoluciones: Boolean(d.mostrar_soluciones),
    congeladoEn: d.congelado_en,
  }))
}

export async function listarPreguntasDelDesafio(desafioId) {
  const { data, error } = await supabase
    .from('expotec_desafio_preguntas')
    .select('pregunta_id, orden, preguntas(enunciado, estado_publicacion, tipo)')
    .eq('desafio_id', desafioId)
    .order('orden')
  if (error) throw errorDe('listarPreguntasDelDesafio', error)
  return (data ?? []).map((f) => ({
    preguntaId: f.pregunta_id,
    orden: aNumero(f.orden),
    enunciado: f.preguntas?.enunciado ?? '',
    estadoPublicacion: f.preguntas?.estado_publicacion ?? '',
    tipo: f.preguntas?.tipo ?? '',
  }))
}

export async function listarPartidasDeEvento(eventoId, estado = null, limite = 200) {
  const { data, error } = await supabase
    .from('expotec_partidas')
    .select(
      'id, alias, estado, respondidas, correctas, incorrectas, puntaje_cuestionario, puntaje_juego, puntaje_total, tiempo_cuestionario_seg, iniciado_at, finalizado_at'
    )
    .eq('evento_id', eventoId)
    .order('iniciado_at', { ascending: false })
    .limit(limite)
  if (error) throw errorDe('listarPartidasDeEvento', error)
  const filas = data ?? []
  if (estado) return filas.filter((f) => f.estado === estado)
  return filas
}

export async function cargarEstadisticas(eventoId) {
  const filas = await listarPartidasDeEvento(eventoId, null, 500)
  const porEstado = {}
  for (const f of filas) {
    porEstado[f.estado] = (porEstado[f.estado] ?? 0) + 1
  }
  const finalizadas = filas.filter((f) => f.estado === 'finalizada')
  const total = finalizadas.length
  const suma = (campo) => finalizadas.reduce((acc, f) => acc + aNumero(f[campo]), 0)
  return {
    eventosDePartidas: filas.length,
    porEstado,
    total,
    puntajePromedio: total ? Math.round(suma('puntaje_total') / total) : 0,
    puntajeMaximo: total ? Math.max(...finalizadas.map((f) => aNumero(f.puntaje_total))) : 0,
  }
}

export async function configurarDesafio(eventoId, params, preguntas) {
  const { data, error } = await supabase.rpc('expotec_admin_configurar_desafio', {
    p_evento_id: eventoId,
    p_params: params,
    p_preguntas: preguntas,
  })
  if (error) throw errorDe('expotec_admin_configurar_desafio', error)
  return data
}

export async function estadisticasEvento(eventoId) {
  const { data, error } = await supabase.rpc('expotec_admin_estadisticas_evento', {
    p_evento_id: eventoId,
  })
  if (error) throw errorDe('expotec_admin_estadisticas_evento', error)
  return data
}

export async function resultadosDelEvento(eventoId, estado = null, limite = 200) {
  const { data, error } = await supabase.rpc('expotec_admin_resultados_evento', {
    p_evento_id: eventoId,
    p_estado: estado,
    p_limite: limite,
  })
  if (error) throw errorDe('expotec_admin_resultados_evento', error)
  return (data ?? []).map((f) => ({
    partidaId: f.partida_id,
    alias: f.alias,
    estado: f.estado,
    respondidas: aNumero(f.respondidas),
    correctas: aNumero(f.correctas),
    incorrectas: aNumero(f.incorrectas),
    puntajeCuestionario: aNumero(f.puntaje_cuestionario),
    puntajeJuego: aNumero(f.puntaje_juego),
    puntajeTotal: aNumero(f.puntaje_total),
    tiempoCuestionarioSeg: f.tiempo_cuestionario_seg === null ? null : aNumero(f.tiempo_cuestionario_seg),
    iniciadoAt: f.iniciado_at,
    finalizadoAt: f.finalizado_at,
  }))
}
