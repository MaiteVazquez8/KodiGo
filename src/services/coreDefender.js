// ---------------------------------------------------------------------------
// Core Defender - motor del minijuego del Desafio ExpoTecnica
//
// Modulo puro: sin DOM, sin canvas, sin timers. El componente CoreDefender.vue
// lo consume desde un requestAnimationFrame y le pasa el puntero cada frame,
// asi que la misma logica puede testearse con node:test.
//
// Reglas espejadas con el SQL (expotec_tope_destruidos y expotec_finalizar_
// juego en src/scripts/kodigo-completo.sql):
//   * El escudo (fantasma) sigue el puntero del mouse/touch sin clicks.
//   * El nucleo central es fijo; los meteoritos llegan de cualquier lado.
//   * +1 punto por meteorito destruido con el escudo; -1 vida por impacto
//     directo contra el nucleo.
//   * La velocidad sube cada 5 segundos y la cantidad de meteoritos cada 7.
//   * La duracion configurada del desafio manda: al cumplirse el tiempo o
//     perderse todas las vidas, la partida termina.
//   * Cada ~15 s se genera un checkpoint para la telemetria del servidor.
//
// Limitaciones de validacion que quedan documentadas en docs/stage7: el motor
// corre en el cliente y el confia el reporte final; el servidor aplica tope de
// destruidos (duracion * MAX_DESTRUIDOS_POR_SEGUNDO + MARGEN_DESTRUIDOS), tope
// de impactos (vidas) y tope de duracion reportada, pero no puede confirmar
// cada frame.
// ---------------------------------------------------------------------------

export const MAX_DESTRUIDOS_POR_SEGUNDO = 2.5
export const MARGEN_DESTRUIDOS = 8

const CHECKPOINT_CADA_SEG = 15
const INTERVALO_VELOCIDAD_SEG = 5
const INTERVALO_CANTIDAD_SEG = 7
const AUMENTO_VELOCIDAD_POR_NIVEL = 0.15
const CADENCIA_SPAWN_BASE_SEG = 0.75
const CADENCIA_SPAWN_MINIMA_SEG = 0.2
const RADIO_NUCLEO = 34
const RADIO_ESCUDO = 26
const RADIO_ORBITA = 132
const RADIO_METEORITO_MIN = 9
const RADIO_METEORITO_MAX = 18
const VELOCIDAD_METEORITO_BASE = 70
const VELOCIDAD_METEORITO_MAX = 460

export const ANCHURA_JUEGO = 640
export const ALTURA_JUEGO = 480

/**
 * Techo de meteoritos destruidos validado por el servidor para una duracion
 * (en segundos) del juego. Espejo exacto de expotec_tope_destruidos.
 */
export function topeDestruidos(duracionSeg) {
  const duracion = Number(duracionSeg)
  if (!Number.isFinite(duracion) || duracion < 0) return 0
  return Math.min(Math.floor(duracion * MAX_DESTRUIDOS_POR_SEGUNDO + MARGEN_DESTRUIDOS), 2000)
}

/** Nivel de velocidad segun el tiempo transcurrido: sube cada 5 segundos. */
export function nivelVelocidad(tiempoSeg) {
  return Math.max(0, Math.floor(Math.floor(tiempoSeg) / INTERVALO_VELOCIDAD_SEG))
}

/** Nivel de cantidad de meteoritos: sube cada 7 segundos. */
export function nivelCantidad(tiempoSeg) {
  return Math.max(0, Math.floor(Math.floor(tiempoSeg) / INTERVALO_CANTIDAD_SEG))
}

/** Multiplicador de velocidad al tiempo dado (crece con los niveles). */
export function multiplicadorVelocidad(tiempoSeg) {
  return 1 + nivelVelocidad(tiempoSeg) * AUMENTO_VELOCIDAD_POR_NIVEL
}

/** Segundos entre generaciones de meteoritos al tiempo dado (decrece). */
export function cadenciaSpawn(tiempoSeg) {
  const seg = Math.max(
    CADENCIA_SPAWN_MINIMA_SEG,
    CADENCIA_SPAWN_BASE_SEG - nivelCantidad(tiempoSeg) * 0.05,
  )
  return seg
}

/**
 * Estado interno nuevo.
 */
export function crearEstadoJuego(duracionSeg, vidas, semilla = Math.random) {
  const duracion = Math.max(1, Math.round(Number(duracionSeg) || 1))
  const totalVidas = Math.max(1, Math.round(Number(vidas) || 1))
  return {
    duracion,
    totalVidas,
    vidas: totalVidas,
    destruidos: 0,
    impactos: 0,
    puntos: 0,
    tiempo: 0,
    terminado: false,
    motivoFin: null,
    meteoritos: [],
    particulas: [],
    proximoSpawn: 0.35,
    proximoCheckpoint: CHECKPOINT_CADA_SEG,
    skeletonCheckpoint: { destruidos: 0, impactos: 0 },
    checkpoints: [],
    semilla,
  }
}

let contadorMeteorito = 0

/**
 * Genera un meteorito que entra por un borde aleatorio y viaja hacia el
 * nucleo (centro del tablero). `fantasma` marca los decorativos.
 */
export function generarMeteorito(estado, dimensiones) {
  const centroX = dimensiones.ancho / 2
  const centroY = dimensiones.alto / 2
  const borde = Math.floor(estado.semilla() * 4)
  const radio =
    RADIO_METEORITO_MIN + estado.semilla() * (RADIO_METEORITO_MAX - RADIO_METEORITO_MIN)

  let x
  let y
  if (borde === 0) {
    x = estado.semilla() * dimensiones.ancho
    y = -radio
  } else if (borde === 1) {
    x = dimensiones.ancho + radio
    y = estado.semilla() * dimensiones.alto
  } else if (borde === 2) {
    x = estado.semilla() * dimensiones.ancho
    y = dimensiones.alto + radio
  } else {
    x = -radio
    y = estado.semilla() * dimensiones.alto
  }

  const angulo = Math.atan2(centroY - y, centroX - x)
  const velocidad = VELOCIDAD_METEORITO_BASE + estado.semilla() * 60
  const fantasma = estado.semilla() < 0.06

  contadorMeteorito += 1
  return {
    id: contadorMeteorito,
    x,
    y,
    radio,
    angulo,
    velocidad,
    fantasma,
    vivo: true,
    color: fantasma ? '#8e05c2' : '#ffffff',
  }
}

/** Punto de orbita del escudo a partir de la posicion del puntero. */
export function posicionEscudo(puntero, dimensiones) {
  const centroX = dimensiones.ancho / 2
  const centroY = dimensiones.alto / 2
  const dx = puntero.x - centroX
  const dy = puntero.y - centroY
  const distancia = Math.hypot(dx, dy)

  // El escudo orbita al nucleo a RADIO_ORBITA: al subir el puntero hacia el
  // nucleo la orbita deja margen para los meteoritos.
  const destinoX = centroX + (distancia ? (dx / distancia) * RADIO_ORBITA : RADIO_ORBITA)
  const destinoY = centroY + (distancia ? (dy / distancia) * RADIO_ORBITA : 0)

  return {
    x: limitar(destinoX, RADIO_ESCUDO, dimensiones.ancho - RADIO_ESCUDO),
    y: limitar(destinoY, RADIO_ESCUDO, dimensiones.alto - RADIO_ESCUDO),
  }
}

function limitar(valor, min, max) {
  if (Number.isNaN(valor)) return min
  return Math.min(Math.max(valor, min), max)
}

/**
 * Avanza la simulacion un paso de `dtSeg` (0.033 maximo recomendable). El
 * estado se muta y se devuelve; `puntero` puede ser null (escudo estatico).
 */
export function pasoJuego(estado, dtSeg, puntero, dimensiones) {
  const dt = Math.min(Math.max(Number(dtSeg) || 0, 0), 0.1)
  if (estado.terminado) return estado

  const tiempoAnterior = estado.tiempo
  estado.tiempo += dt

  // Limites de tiempo: la duracion configurada manda.
  if (estado.tiempo >= estado.duracion) {
    estado.tiempo = estado.duracion
    terminarJuego(estado, 'tiempo')
    return estado
  }

  const escudo = puntero ? posicionEscudo(puntero, dimensiones) : null
  const multiplicador = multiplicadorVelocidad(estado.tiempo)
  const centroX = dimensiones.ancho / 2
  const centroY = dimensiones.alto / 2

  // Spawn de meteoritos: la cadencia decrece con el tiempo.
  estado.proximoSpawn -= dt
  if (estado.proximoSpawn <= 0) {
    estado.proximoSpawn = cadenciaSpawn(estado.tiempo)
    estado.meteoritos.push(generarMeteorito(estado, dimensiones))
  }

  // Movimiento, colision con el escudo, colision con el nucleo.
  for (const m of estado.meteoritos) {
    if (!m.vivo) continue

    const paso = m.velocidad * multiplicador * dt
    m.x += Math.cos(m.angulo) * paso
    m.y += Math.sin(m.angulo) * paso

    // Bloqueo por el escudo: el meteorito se destruye (+1 punto).
    if (escudo) {
      const distEscudo = Math.hypot(m.x - escudo.x, m.y - escudo.y)
      if (distEscudo <= m.radio + RADIO_ESCUDO) {
        m.vivo = false
        estado.destruidos += 1
        estado.puntos += 1
        generarParticulas(estado, m, escudo)
        continue
      }
    }

    // Impacto directo contra el nucleo: -1 vida y particulas rojas.
    const distanciaNucleo = Math.hypot(m.x - centroX, m.y - centroY)
    if (distanciaNucleo <= m.radio + RADIO_NUCLEO) {
      m.vivo = false
      estado.impactos += 1
      estado.vidas -= 1
      generarParticulas(estado, m, { x: centroX, y: centroY }, true)
      if (estado.vidas <= 0) {
        terminarJuego(estado, 'vidas')
        return estado
      }
    }
  }

  estado.meteoritos = estado.meteoritos.filter((m) => m.vivo)

  // Particulas decorativas: se apagan solas.
  for (const p of estado.particulas) {
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.vida -= dt
  }
  estado.particulas = estado.particulas.filter((p) => p.vida > 0)

  // Checkpoint de telemetria cada CHECKPOINT_CADA_SEG segundos.
  if (estado.tiempo >= estado.proximoCheckpoint) {
    estado.proximoCheckpoint += CHECKPOINT_CADA_SEG
    estado.checkpoints.push({
      tiempo: Math.round(estado.tiempo * 100) / 100,
      destruidos: estado.destruidos,
      impactos: estado.impactos,
    })
  }

  void tiempoAnterior
  return estado
}

function generarParticulas(estado, meteorito, origen, esImpacto = false) {
  for (let i = 0; i < 7; i += 1) {
    const angulo = estado.semilla() * Math.PI * 2
    const velocidad = 40 + estado.semilla() * 80
    estado.particulas.push({
      x: origen.x ?? meteorito.x,
      y: origen.y ?? meteorito.y,
      vx: Math.cos(angulo) * velocidad,
      vy: Math.sin(angulo) * velocidad,
      vida: 0.25 + estado.semilla() * 0.2,
      color: esImpacto ? '#ff5d73' : meteorito.color,
      radio: esImpacto ? 3 : 2,
    })
  }
}

export function terminarJuego(estado, motivo) {
  if (estado.terminado) return estado
  estado.terminado = true
  estado.motivoFin = motivo
  return estado
}

/**
 * Datos finales para expotec_finalizar_juego. El servidor aplica sus topes:
 * duracion nunca mayor que la sesion real, meteoritos acotados por
 * topeDestruidos() e impactos acotados por las vidas (least(impactos, vidas)).
 */
export function resultadoFinal(estado, duracionMaxSeg) {
  const duracionReal = Math.min(estado.tiempo, Number(duracionMaxSeg) || estado.duracion)
  const duracion = Math.round(duracionReal * 100) / 100
  return {
    duracionSeg: duracion,
    meteoritos: Math.min(estado.destruidos, topeDestruidos(duracion)),
    impactos: Math.min(estado.impactos, estado.totalVidas),
    checkpoints: estado.checkpoints,
    motivoFin: estado.motivoFin,
    puntos: estado.puntos,
  }
}

/** Dibujo encapsulado para CoreDefender.vue: backends canvas 2D. */
export function dibujarJuego(ctx, estado, dimensiones, escudo) {
  const centroX = dimensiones.ancho / 2
  const centroY = dimensiones.alto / 2

  // Fondo
  ctx.fillStyle = '#0d0512'
  ctx.fillRect(0, 0, dimensiones.ancho, dimensiones.alto)

  // Estrellas de fondo fijas (deterministas) al estilo Kodigo
  ctx.fillStyle = 'rgba(255, 255, 255, 0.15)'
  for (let i = 0; i < 40; i += 1) {
    const sx = ((i * 137) % dimensiones.ancho) + 0.5
    const sy = ((i * 199) % dimensiones.alto) + 0.5
    ctx.fillRect(sx, sy, 1.5, 1.5)
  }

  // Nucleo: caracter vivo en violeta
  ctx.beginPath()
  ctx.arc(centroX, centroY, RADIO_NUCLEO, 0, Math.PI * 2)
  ctx.fillStyle = '#3e065f'
  ctx.fill()
  ctx.beginPath()
  ctx.arc(centroX, centroY, RADIO_NUCLEO - 8, 0, Math.PI * 2)
  ctx.fillStyle = '#700b97'
  ctx.fill()

  // Particulas
  for (const p of estado.particulas) {
    ctx.globalAlpha = Math.max(0, Math.min(1, p.vida * 4))
    ctx.beginPath()
    ctx.arc(p.x, p.y, p.radio, 0, Math.PI * 2)
    ctx.fillStyle = p.color
    ctx.fill()
  }
  ctx.globalAlpha = 1

  // Meteoritos
  for (const m of estado.meteoritos) {
    if (!m.vivo) continue
    ctx.beginPath()
    ctx.arc(m.x, m.y, m.radio, 0, Math.PI * 2)
    ctx.fillStyle = m.fantasma ? 'rgba(142, 5, 194, 0.85)' : '#ffffff'
    ctx.fill()
    if (m.fantasma) {
      // Ojos del fantasma decorativo
      ctx.fillStyle = '#ffffff'
      ctx.fillRect(m.x - m.radio * 0.35, m.y - m.radio * 0.2, 3, 3)
      ctx.fillRect(m.x + m.radio * 0.35 - 3, m.y - m.radio * 0.2, 3, 3)
    }
  }

  // Escudo (fantasma):
  if (escudo) {
    ctx.beginPath()
    ctx.arc(escudo.x, escudo.y, RADIO_ESCUDO, 0, Math.PI * 2)
    ctx.fillStyle = '#8e05c2'
    ctx.globalAlpha = 0.9
    ctx.fill()
    ctx.globalAlpha = 1
    // Arco del escudo visible
    ctx.beginPath()
    ctx.arc(escudo.x, escudo.y, RADIO_ESCUDO + 4, Math.PI * 1.15, Math.PI * 1.85)
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.55)'
    ctx.lineWidth = 3
    ctx.stroke()
  }
}

export {
  CADENCIA_SPAWN_BASE_SEG,
  CADENCIA_SPAWN_MINIMA_SEG,
  CHECKPOINT_CADA_SEG,
  INTERVALO_VELOCIDAD_SEG,
  INTERVALO_CANTIDAD_SEG,
  RADIO_NUCLEO,
  RADIO_ESCUDO,
  RADIO_ORBITA,
}
