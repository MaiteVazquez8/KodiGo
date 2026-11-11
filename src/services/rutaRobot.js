//
// Motor puro de "Ruta del robot": tablero de 5 x 5, instrucciones y niveles.
// Sin Vue ni Quasar: la vista consume funciones y datos planos, igual que
// coreDefender.js hace con el minijuego de la ExpoTécnica. Sumar un nivel
// nuevo es agregar una entrada a NIVELES; nada del motor cambia.
//
// Reglas (spec de la sección Pensamiento lógico):
//   * Tablero de 25 casillas indexadas 0..24 (fila por fila, arriba a abajo).
//   * Instrucciones: avanzar, girar-izquierda y girar-derecha.
//   * Avanzar mueve una casilla en la dirección del robot; girar solo rota.
//   * Salir del tablero o empujarse contra un obstáculo corta la ejecución.
//   * La meta corta con éxito; si la secuencia termina sin meta, queda
//     incompleta.
//

export const LADO = 5
export const CASILLAS = LADO * LADO
export const MAX_INSTRUCCIONES = 30

/** Instrucciones disponibles, en el orden en que se ofrecen en la vista. */
export const TIPOS_INSTRUCCION = ['avanzar', 'girar-izquierda', 'girar-derecha']

export const ETIQUETA_INSTRUCCION = {
  avanzar: 'Avanzar',
  'girar-izquierda': 'Girar a la izquierda',
  'girar-derecha': 'Girar a la derecha',
}

export const ICONO_INSTRUCCION = {
  avanzar: 'arrow_upward',
  'girar-izquierda': 'rotate_left',
  'girar-derecha': 'rotate_right',
}

const DELTAS = {
  arriba: -LADO,
  abajo: LADO,
  izquierda: -1,
  derecha: 1,
}

/** Ángulo del indicador de dirección para cada orientación (0 = arriba). */
const GRADOS = {
  arriba: 0,
  derecha: 90,
  abajo: 180,
  izquierda: 270,
}

const GIROS = {
  arriba: { 'girar-izquierda': 'izquierda', 'girar-derecha': 'derecha' },
  izquierda: { 'girar-izquierda': 'abajo', 'girar-derecha': 'arriba' },
  abajo: { 'girar-izquierda': 'derecha', 'girar-derecha': 'izquierda' },
  derecha: { 'girar-izquierda': 'arriba', 'girar-derecha': 'abajo' },
}

/**
 * Niveles de Ruta del robot. Los índices son casillas del tablero de 25
 * (0 arriba-izquierda). `segundosLímite` null = sin tiempo (nivel práctica).
 */
export const NIVELES = [
  {
    id: 'practica',
    nombre: 'Práctica',
    descripcion: 'Sin límite de tiempo: probá y corregí hasta que salga.',
    posicionInicial: 20,
    orientacionInicial: 'arriba',
    meta: 4,
    obstaculos: [16, 13],
    segundosLimite: null,
  },
  {
    id: 'desempate-1',
    nombre: 'Desempate 1',
    descripcion: '60 segundos para armar y ejecutar tu secuencia.',
    posicionInicial: 20,
    orientacionInicial: 'derecha',
    meta: 4,
    obstaculos: [22, 7],
    segundosLimite: 60,
  },
  {
    id: 'desempate-2',
    nombre: 'Desempate 2',
    descripcion: '60 segundos y el punto de partida más lejano a la meta.',
    posicionInicial: 24,
    orientacionInicial: 'izquierda',
    meta: 0,
    obstaculos: [22, 10],
    segundosLimite: 60,
  },
]

export function definicionDeNivel(nivelId) {
  return NIVELES.find((n) => n.id === nivelId) ?? NIVELES[0]
}

/** Fila (0..4) de una casilla dada. */
export function filaDe(casilla) {
  return Math.floor(casilla / LADO)
}

/** Columna (0..4) de una casilla dada. */
export function columnaDe(casilla) {
  return casilla % LADO
}

/** Estado de arranque de un nivel, listo para consumir en la vista. */
export function estadoInicial(nivel) {
  const definicion = definicionDeNivel(typeof nivel === 'string' ? nivel : nivel.id)
  return {
    posicion: definicion.posicionInicial,
    orientacion: definicion.orientacionInicial,
  }
}

/** Ángulo en grados del indicador del robot para una orientación. */
export function gradosDeOrientacion(orientacion) {
  return GRADOS[orientacion] ?? 0
}

/**
 * Avanza una casilla en la dirección indicada. Devuelve `borde` cuando el
 * movimiento cae fuera del tablero (la casilla no cambia).
 */
export function avanzar(posicion, orientacion) {
  const destino = posicion + DELTAS[orientacion]
  const borde = destino < 0 || destino >= CASILLAS
  return { posicion: borde ? posicion : destino, borde }
}

/** Rota la orientación 90 grados a la izquierda o derecha, sin moverse. */
export function girar(orientacion, instruccion) {
  const hacia = GIROS[orientacion]?.[instruccion]
  return hacia ?? orientacion
}

/** Valida la secuencia armada por el jugador antes de ejecutarla. */
export function validarSecuencia(instrucciones) {
  const lista = Array.isArray(instrucciones) ? instrucciones : []
  if (!lista.length) {
    return { valido: false, mensaje: 'Agregá al menos una instrucción.' }
  }
  if (lista.length > MAX_INSTRUCCIONES) {
    return {
      valido: false,
      mensaje: `Máximo ${MAX_INSTRUCCIONES} instrucciones por secuencia.`,
    }
  }
  if (lista.some((i) => !TIPOS_INSTRUCCION.includes(i))) {
    return { valido: false, mensaje: 'Hay una instrucción que no se reconoce.' }
  }
  return { valido: true, mensaje: '' }
}

/**
 * Ejecuta la secuencia contra un nivel y devuelve la traza completa para que
 * la vista la anime paso a paso (el motor no pinta nada).
 *
 * Devuelve { pasos, exito, motivo, usadas, trayecto }:
 *  - pasos: [{ evento, posicion, orientacion, instruccion? }]
 *    evento: 'inicio' | 'avanza' | 'girar-izquierda' | 'girar-derecha'
 *            | 'meta' | 'borde' | 'obstaculo'
 *  - motivo: 'meta' | 'borde' | 'obstaculo' | 'incompleto'
 *  - usadas: instrucciones efectivamente ejecutadas (contando la que llega
 *    a la meta).
 *  - trayecto: [{ casilla, numero }] con la salida (numero 0) y cada casilla
 *    pisada por un avance, en orden; sirve para dibujar el recorrido.
 */
export function ejecutarSecuencia(nivel, instrucciones) {
  const definicion = definicionDeNivel(typeof nivel === 'string' ? nivel : nivel.id)
  let posicion = definicion.posicionInicial
  let orientacion = definicion.orientacionInicial

  const obstaculos = new Set(definicion.obstaculos)
  const pasos = [{ evento: 'inicio', posicion, orientacion }]
  const trayecto = [{ casilla: posicion, numero: 0 }]

  let usadas = 0
  let exito = false
  let motivo = 'incompleto'

  for (const instruccion of instrucciones) {
    if (instruccion === 'avanzar') {
      const resultado = avanzar(posicion, orientacion)
      usadas += 1

      if (resultado.borde) {
        pasos.push({
          evento: 'borde',
          posicion,
          orientacion,
          instruccion,
        })
        motivo = 'borde'
        break
      }

      posicion = resultado.posicion

      if (obstaculos.has(posicion)) {
        pasos.push({
          evento: 'obstaculo',
          posicion,
          orientacion,
          instruccion,
        })
        trayecto.push({ casilla: posicion, numero: usadas })
        motivo = 'obstaculo'
        break
      }

      trayecto.push({ casilla: posicion, numero: usadas })

      if (posicion === definicion.meta) {
        pasos.push({
          evento: 'meta',
          posicion,
          orientacion,
          instruccion,
        })
        exito = true
        motivo = 'meta'
        break
      }

      pasos.push({
        evento: 'avanza',
        posicion,
        orientacion,
        instruccion,
      })
    } else {
      orientacion = girar(orientacion, instruccion)
      usadas += 1
      pasos.push({ evento: instruccion, posicion, orientacion, instruccion })
    }
  }

  return { pasos, exito, motivo, usadas, trayecto }
}

// ---------------------------------------------------------------------------
// Registro de mejores recorridos (por nivel, en memoria de la sesión).
// El proyecto no tiene backend para esta sección todavía: mientras no exista
// persistencia definida, el récord vive solo durante la sesión abierta.
// ---------------------------------------------------------------------------

const mejores = new Map()

/** Menor número de instrucciones logrado en un nivel (null si no hay). */
export function mejorRecorrido(nivelId) {
  return mejores.get(nivelId) ?? null
}

/**
 * Registra un intento exitoso y devuelve si quedó como nuevo mejor recorrido
 * ({ esMejor: true, mejor: n }) o no ({ esMejor: false, mejor: n }).
 */
export function registrarRecorrido(nivelId, usadas) {
  const valor = Math.max(1, Math.round(Number(usadas) || 0))
  const previo = mejores.get(nivelId)
  if (previo === undefined || valor < previo) {
    mejores.set(nivelId, valor)
    return { esMejor: true, mejor: valor }
  }
  return { esMejor: false, mejor: previo }
}

/** Niveles con al menos un logro registrado, para "N/3 completados". */
export function nivelesCompletados() {
  let conteo = 0
  for (const nivel of NIVELES) {
    if (mejores.has(nivel.id)) conteo += 1
  }
  return conteo
}

/** Limpia el registro (uso de pruebas; no forma parte de la interfaz). */
export function reiniciarRegistros() {
  mejores.clear()
}
