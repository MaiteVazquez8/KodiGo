import { supabase } from '@/supabase'

// ---------------------------------------------------------------------------
// Desafio ExpoTecnica - cliente de las RPC del participante
//
// Todo el estado oficial vive en el servidor: este modulo solo ejecuta las
// funciones SECURITY DEFINER del esquema expotec_* y normaliza sus respuestas
// para las vistas. El cliente nunca escribe tablas del desafio ni calcula
// puntajes: la correccion de respuestas y el orden del ranking son del
// servidor.
//
// El cronometro del cuestionario se valida contra el servidor: cada consulta
// a expotec_estado_partida devuelve servidor_at y vencimiento_at, y de ahi se
// deriva el desfase de relojes para que recargar la pagina no venza la
// partida: la fecha de vencimiento vale en la base de datos, no en la maquina
// del jugador.
// ---------------------------------------------------------------------------

function llamar(nombre, params = {}) {
  return supabase.rpc(nombre, params)
}

/** Encapsula el error de PostgREST en un Error con mensaje legible. */
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

// ---------------------------------------------------------------------------
// Evento activo
// ---------------------------------------------------------------------------

export async function obtenerEventoActivo() {
  const { data, error } = await llamar('expotec_evento_activo')
  if (error) throw errorDe('expotec_evento_activo', error)
  if (!data?.length) return null
  return normalizarEvento(data[0])
}

export function normalizarEvento(fila) {
  return {
    id: fila.id,
    nombre: fila.nombre,
    descripcion: fila.descripcion,
    fechaInicio: fila.fecha_inicio,
    fechaFin: fila.fecha_fin,
    estado: fila.estado,
    desafio: {
      id: fila.desafio_id,
      nombre: fila.desafio_nombre,
      version: aNumero(fila.version, 1),
      cantidadPreguntas: aNumero(fila.cantidad_preguntas, 10),
      puntosPorCorrecta: aNumero(fila.puntos_por_correcta, 100),
      tiempoCuestionarioSeg:
        fila.tiempo_cuestionario_seg === null ? null : aNumero(fila.tiempo_cuestionario_seg),
      duracionJuegoSeg: aNumero(fila.duracion_juego_seg, 180),
      vidasJuego: aNumero(fila.vidas_juego, 3),
    },
  }
}

// ---------------------------------------------------------------------------
// Alias
// ---------------------------------------------------------------------------

/**
 * Consulta si un alias puede usarse en el evento. Nunca es el registro
 * definitivo: expotec_iniciar_partida es la fuente de verdad.
 */
export async function verificarAlias(eventoId, alias) {
  const { data, error } = await llamar('expotec_alias_disponible', {
    p_evento_id: eventoId,
    p_alias: alias,
  })
  if (error) throw errorDe('expotec_alias_disponible', error)
  const fila = data?.[0]
  return {
    disponible: Boolean(fila?.disponible),
    aliasNormalizado: fila?.alias_normalizado ?? '',
    mensaje: fila?.mensaje ?? '',
  }
}

// ---------------------------------------------------------------------------
// Partida: iniciar y leer estado
// ---------------------------------------------------------------------------

export async function iniciarPartida(eventoId, alias) {
  const { data, error } = await llamar('expotec_iniciar_partida', {
    p_evento_id: eventoId,
    p_alias: alias,
  })
  if (error) throw errorDe('expotec_iniciar_partida', error)
  return data
}

function copiarOpciones(opciones) {
  if (!Array.isArray(opciones)) return []
  return opciones.map((o) => ({ id: o.id, texto: o.texto ?? '' }))
}

export function normalizarEstado(data) {
  if (!data) return null

  const config = data.partida?.config ?? {}
  const configDesafio = config.desafio ?? {}

  const preguntas = (data.preguntas ?? []).map((p) => ({
    asignadaId: p.id,
    orden: aNumero(p.orden),
    enunciado: p.enunciado ?? '',
    opciones: copiarOpciones(p.opciones),
  }))

  const respuestas = {}
  for (const r of data.respuestas ?? []) {
    respuestas[r.pregunta_asignada_id] = {
      opcionId: r.opcion_id,
      respondidoAt: r.respondido_at,
    }
  }

  return {
    servidorAt: new Date(data.servidor_at).getTime(),
    partida: {
      id: data.partida.id,
      estado: data.partida.estado,
      alias: data.partida.alias,
      eventoId: data.partida.evento_id,
      iniciadoAt: data.partida.iniciado_at,
      vencimientoAt: data.partida.vencimiento_at,
      completadoAt: data.partida.completado_at,
      finalizadoAt: data.partida.finalizado_at,
      respondidas: aNumero(data.partida.respondidas),
      correctas: aNumero(data.partida.correctas),
      incorrectas: aNumero(data.partida.incorrectas),
      puntajeCuestionario: aNumero(data.partida.puntaje_cuestionario),
      tiempoCuestionarioSeg:
        data.partida.tiempo_cuestionario_seg === null
          ? null
          : aNumero(data.partida.tiempo_cuestionario_seg),
    },
    config: {
      cantidadPreguntas: aNumero(configDesafio.cantidad_preguntas, 10),
      puntosPorCorrecta: aNumero(configDesafio.puntos_por_correcta, 100),
      tiempoCuestionarioSeg: configDesafio.tiempo_cuestionario_seg
        ? aNumero(configDesafio.tiempo_cuestionario_seg)
        : null,
      duracionJuegoSeg: aNumero(configDesafio.duracion_juego_seg, 180),
      vidasJuego: aNumero(configDesafio.vidas_juego, 3),
      evento: config.evento ?? {},
      desafio: configDesafio,
    },
    preguntas,
    respuestas,
  }
}

export async function estadoPartida(partidaId) {
  const { data, error } = await llamar('expotec_estado_partida', { p_partida_id: partidaId })
  if (error) throw errorDe('expotec_estado_partida', error)
  return normalizarEstado(data)
}

export async function responder(partidaId, preguntaAsignadaId, opcionId) {
  const { data, error } = await llamar('expotec_responder', {
    p_partida_id: partidaId,
    p_pregunta_asignada_id: preguntaAsignadaId,
    p_opcion_id: opcionId,
  })
  if (error) throw errorDe('expotec_responder', error)
  return {
    yaRegistrada: Boolean(data?.ya_registrada),
    respondidas: aNumero(data?.respondidas),
    pendientes: aNumero(data?.pendientes),
    completado: Boolean(data?.completado),
    respondidoAt: data?.respondido_at,
    servidorAt: data?.servidor_at ? new Date(data.servidor_at).getTime() : Date.now(),
  }
}

// ---------------------------------------------------------------------------
// Core Defender
// ---------------------------------------------------------------------------

export async function iniciarJuego(partidaId) {
  const { data, error } = await llamar('expotec_iniciar_juego', { p_partida_id: partidaId })
  if (error) throw errorDe('expotec_iniciar_juego', error)
  return {
    sesionId: data?.sesion_id,
    duracionMaxSeg: aNumero(data?.duracion_max_seg, 180),
    vidas: aNumero(data?.vidas, 3),
    reanudada: Boolean(data?.reanudada),
  }
}

export async function enviarCheckpoint(sesionId, checkpoints) {
  const { error } = await llamar('expotec_checkpoint_juego', {
    p_sesion_id: sesionId,
    p_checkpoints: checkpoints,
  })
  if (error) throw errorDe('expotec_checkpoint_juego', error)
}

export async function finalizarJuego(sesionId, resultados, checkpoints) {
  const { data, error } = await llamar('expotec_finalizar_juego', {
    p_sesion_id: sesionId,
    p_meteoritos: Math.max(0, Math.round(resultados.meteoritos)),
    p_impactos: Math.max(0, Math.round(resultados.impactos)),
    p_duracion_seg: Math.max(0, resultados.duracionSeg),
    p_checkpoints: checkpoints ?? null,
  })
  if (error) throw errorDe('expotec_finalizar_juego', error)
  return normalizarResultadoFinal(data)
}

export function normalizarResultadoFinal(data) {
  if (!data) return null
  return {
    partidaId: data.partida_id,
    estado: data.estado,
    puntajeJuego: aNumero(data.puntaje_juego),
    puntajeCuestionario: aNumero(data.puntaje_cuestionario),
    puntajeTotal: aNumero(data.puntaje_total),
    correctas: aNumero(data.correctas),
    incorrectas: aNumero(data.incorrectas),
    tiempoCuestionarioSeg:
      data.tiempo_cuestionario_seg === null ? null : aNumero(data.tiempo_cuestionario_seg),
    finalizadoAt: data.finalizado_at,
  }
}

export async function abandonarPartida(partidaId) {
  const { data, error } = await llamar('expotec_abandonar', { p_partida_id: partidaId })
  if (error) throw errorDe('expotec_abandonar', error)
  return {
    estado: data?.estado,
    abandonada: Boolean(data?.abandonada),
    servidorAt: data?.servidor_at ? new Date(data.servidor_at).getTime() : null,
  }
}

// ---------------------------------------------------------------------------
// Resultados y solucionario
// ---------------------------------------------------------------------------

export async function obtenerSoluciones(partidaId) {
  const { data, error } = await llamar('expotec_obtener_soluciones', { p_partida_id: partidaId })
  if (error) throw errorDe('expotec_obtener_soluciones', error)
  const preguntas = (data?.preguntas ?? []).map((p) => ({
    orden: aNumero(p.orden),
    enunciado: p.enunciado ?? '',
    elegida: p.elegida,
    correcta: p.correcta,
    acerto: Boolean(p.acerto),
    sinRespuesta: Boolean(p.sin_respuesta),
    explicacion: p.explicacion ?? '',
  }))
  return { preguntas }
}

export async function resultadoPropio(partidaId) {
  const { data, error } = await llamar('expotec_resultado_propio', { p_partida_id: partidaId })
  if (error) throw errorDe('expotec_resultado_propio', error)
  const partida = data?.partida ?? {}
  return {
    partida: {
      id: partida.id,
      estado: partida.estado,
      alias: partida.alias,
      correctas: aNumero(partida.correctas),
      incorrectas: aNumero(partida.incorrectas),
      respondidas: aNumero(partida.respondidas),
      puntajeCuestionario: aNumero(partida.puntaje_cuestionario),
      puntajeJuego: aNumero(partida.puntaje_juego),
      puntajeTotal: aNumero(partida.puntaje_total),
      tiempoCuestionarioSeg:
        partida.tiempo_cuestionario_seg === null
          ? null
          : aNumero(partida.tiempo_cuestionario_seg),
      iniciadoAt: partida.iniciado_at,
      finalizadoAt: partida.finalizado_at,
    },
    puesto: partida.estado === 'finalizada' ? aNumero(data?.puesto, 0) : null,
  }
}

export async function misPartidas(eventoId) {
  const { data, error } = await llamar('expotec_mis_partidas', { p_evento_id: eventoId })
  if (error) throw errorDe('expotec_mis_partidas', error)
  return (data ?? []).map((f) => ({
    id: f.id,
    estado: f.estado,
    alias: f.alias,
    iniciadoAt: f.iniciado_at,
    finalizadoAt: f.finalizado_at,
    respondidas: aNumero(f.respondidas),
    cantidadPreguntas: aNumero(f.cantidad_preguntas),
    correctas: aNumero(f.correctas),
    incorrectas: aNumero(f.incorrectas),
    puntajeCuestionario: aNumero(f.puntaje_cuestionario),
    puntajeJuego: aNumero(f.puntaje_juego),
    puntajeTotal: aNumero(f.puntaje_total),
  }))
}

export async function ranking(eventoId, limite = 100) {
  const { data, error } = await llamar('expotec_ranking', {
    p_evento_id: eventoId,
    p_limite: limite,
  })
  if (error) throw errorDe('expotec_ranking', error)
  return (data ?? []).map((f) => ({
    puesto: aNumero(f.puesto),
    alias: f.alias,
    puntajeTotal: aNumero(f.puntaje_total),
    puntajeCuestionario: aNumero(f.puntaje_cuestionario),
    puntajeJuego: aNumero(f.puntaje_juego),
    correctas: aNumero(f.correctas),
    incorrectas: aNumero(f.incorrectas),
    tiempoCuestionarioSeg:
      f.tiempo_cuestionario_seg === null ? null : aNumero(f.tiempo_cuestionario_seg),
    finalizadoAt: f.finalizado_at,
  }))
}

// ---------------------------------------------------------------------------
// Tiempo real del ranking
//
// La tabla publica expotec_resultados_publicos alimenta la pantalla del
// ranking. El canal de Supabase Realtime notifica filas nuevas y el filtro
// honra el evento: los rankings de eventos distintos nunca se mezclan.
// ---------------------------------------------------------------------------

export function suscribirseARanking(eventoId, { onInsert, onError } = {}) {
  const canal = supabase
    .channel(`expotec-ranking-${eventoId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'expotec_resultados_publicos',
        filter: `evento_id=eq.${eventoId}`,
      },
      (mensaje) => {
        if (onInsert) onInsert(mensaje.new)
      },
    )
    .subscribe((status) => {
      if (onError && (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT')) {
        onError(new Error(`Estado del canal de ranking: ${status}`))
      }
    })

  return () => {
    try {
      supabase.removeChannel(canal)
    } catch {
      // el canal puede ya haberse cerrado
    }
  }
}
