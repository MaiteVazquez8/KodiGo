<template>
  <div class="robot-juego">
    <div class="robot-objetivo">
      <p class="robot-eyebrow">★ {{ pregunta?.datos?.objetivo || 'Llegá a la meta' }}</p>
      <h3 class="robot-titulo">{{ pregunta?.enunciado }}</h3>
      <p class="robot-instrucciones">{{ pregunta?.datos?.instruccionesTexto || 'Programá al robot para llegar a la meta. Cada giro y avance cuenta como una instrucción.' }}</p>
    </div>

    <div class="robot-tablero" aria-label="Tablero de 5 por 5 casillas">
      <div
        v-for="n in (datos?.tablero?.dimensiones ?? 5) * (datos?.tablero?.dimensiones ?? 5)"
        :key="n"
        class="robot-casilla"
        :class="{
          'es-muro': muros.includes(n - 1),
          'es-meta': meta === n - 1,
          'es-paso': huellas.includes(n - 1),
          'es-robot': casilla === n - 1,
          'es-inicio': inicio === n - 1 && casilla !== n - 1,
        }"
        :aria-label="describirCasilla(n - 1)"
      >
        <span class="robot-casilla-contenido">{{ contenidoCasilla(n - 1) }}</span>
      </div>
    </div>

    <div class="robot-paneles">
      <div class="robot-paleta">
        <p class="robot-paleta-titulo">Instrucciones disponibles</p>
        <div class="robot-paleta-botones">
          <button
            v-for="inst in instruccionesDisponibles"
            :key="inst.id"
            type="button"
            class="robot-instruccion"
            :disabled="!editable || secuencia.length >= maxSecuencia"
            @click="agregar(inst.id)"
          >
            <span class="robot-instruccion-simbolo k-mono">{{ inst.simbolo }}</span>
            <span>{{ inst.texto }}</span>
          </button>
        </div>
      </div>

      <div class="robot-secuencia-panel">
        <p class="robot-paleta-titulo">Tu programa ({{ secuencia.length }}/{{ maxSecuencia }})</p>
        <ol v-if="secuencia.length" class="robot-secuencia">
          <li v-for="(instId, i) in secuencia" :key="i" class="robot-instruccion-valor" :class="`paso-${i + 1}`">
            <span class="robot-secuencia-indice k-mono">{{ i + 1 }}.</span>
            {{ instruccionTexto(instId) }}
          </li>
        </ol>
        <p v-else class="robot-vacio">Todavía no agregaste instrucciones.</p>
        <div class="robot-acciones">
          <button type="button" class="k-btn k-btn--ghost" :disabled="!editable || secuencia.length === 0" @click="quitarUltima">
            <q-icon name="backspace" size="18px" />
            Quitar última
          </button>
          <button type="button" class="k-btn k-btn--ghost" :disabled="!editable || secuencia.length === 0" @click="borrarTodo">
            <q-icon name="delete_sweep" size="18px" />
            Borrar todo
          </button>
          <button type="button" class="k-btn k-btn--primary" :disabled="!editable || secuencia.length === 0" @click="ejecutar">
            <q-icon name="play_arrow" size="18px" />
            Ejecutar
          </button>
        </div>
      </div>
    </div>

    <div class="robot-feedback" :class="claseFeedback" role="status">
      <q-icon v-if="tipoFeedback === 'exito'" name="celebration" size="20px" />
      <q-icon v-else-if="tipoFeedback === 'error'" name="error_outline" size="20px" />
      <q-icon v-else name="info" size="20px" />
      <span>{{ mensaje }}</span>
      <button type="button" class="robot-ayuda" :aria-label="mostrarAyuda ? 'Ocultar ayuda' : 'Mostrar ayuda contextual'" @click="mostrarAyuda = !mostrarAyuda">
        <q-icon :name="mostrarAyuda ? 'expand_less' : 'help_outline'" size="18px" />
        {{ mostrarAyuda ? 'Ocultar ayuda' : 'Ayuda' }}
      </button>
    </div>

    <transition name="fade">
      <div v-if="mostrarAyuda" class="robot-ayuda-panel">
        <p class="robot-ayuda-titulo">¿Necesitás una pista?</p>
        <p>{{ pregunta?.datos?.ayuda || 'Mirá cuál es la meta (⭐) y desde dónde empieza el robot (I). Pensá qué instrucciones necesitás para llegar hasta ahí.' }}</p>
        <p v-if="pregunta?.datos?.pasos" class="robot-ayuda-pista">{{ pregunta.datos.pasos }}</p>
      </div>
    </transition>

    <transition name="fade">
      <div v-if="mostrarTutorial && tutorialDatos" class="robot-tutorial" role="dialog" aria-modal="true" :aria-label="'Tutorial: ' + tutorialDatos.titulo">
        <div class="robot-tutorial-card">
          <button type="button" class="robot-tutorial-cerrar" aria-label="Cerrar tutorial" @click="cerrarTutorial">
            <q-icon name="close" size="20px" />
          </button>
          <p class="robot-tutorial-eyebrow">Tutorial</p>
          <h3 class="robot-tutorial-titulo">{{ tutorialDatos.titulo }}</h3>
          <p class="robot-tutorial-resumen">{{ tutorialDatos.resumen }}</p>
          <ol class="robot-tutorial-lista">
            <li v-for="(paso, i) in tutorialDatos.pasos" :key="i" class="robot-tutorial-paso" :class="{ activo: tutorialPaso === i }">
              <button type="button" class="robot-tutorial-boton" @click="tutorialPaso = i">
                <span class="robot-tutorial-indice k-mono">{{ i + 1 }}</span>
                <span>{{ paso.titulo }}</span>
              </button>
              <p v-if="tutorialPaso === i" class="robot-tutorial-texto">{{ paso.texto }}</p>
            </li>
          </ol>
          <div class="robot-tutorial-acciones">
            <button type="button" class="k-btn k-btn--ghost" :disabled="tutorialPaso === 0" @click="irPasoTutorial(-1)">
              <q-icon name="chevron_left" size="18px" />
              Anterior
            </button>
            <button v-if="tutorialPaso < tutorialDatos.pasos.length - 1" type="button" class="k-btn k-btn--primary" @click="irPasoTutorial(1)">
              Siguiente
              <q-icon name="chevron_right" size="18px" />
            </button>
            <button v-else type="button" class="k-btn k-btn--primary" @click="cerrarTutorial">
              <q-icon name="play_arrow" size="18px" />
              Empezar a jugar
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue'

const props = defineProps({
  pregunta: { type: Object, required: true },
  corrigiendo: { type: Boolean, default: false },
  devolucion: { type: Object, default: null },
})

const emit = defineEmits(['programa'])

function notificarPrograma() {
  emit('programa', { robot: [...secuencia.value] })
}

const TUTORIALES = {
  'tutorial-robot': {
    titulo: 'Conocé al robot',
    resumen: 'El tablero es un mundo de 5 × 5. El robot sale de la letra I, la meta es la estrella, y cada casilla con una × es un obstáculo que nadie puede atravesar.',
    pasos: [
      { titulo: 'El tablero', texto: 'El tablero tiene 5 × 5 casillas. La I marca desde dónde arranca el robot y la ★ señala dónde tiene que terminar.' },
      { titulo: 'La orientación', texto: 'La flecha indica hacia dónde mira el robot: ↑, →, ↓ o ←. Las instrucciones actúan sobre esa orientación.' },
      { titulo: 'Avanzar y girar', texto: 'Avanzar mueve una casilla hacia donde mira el robot. Girar a la izquierda (↶) o a la derecha (↷) cambia la orientación sin moverse.' },
      { titulo: 'Construí tu programa', texto: 'Agregá las instrucciones en orden y pulsá Ejecutar para ver moverse al robot paso a paso.' },
    ],
  },
  'tutorial-giros': {
    titulo: 'Giros: cambiá la dirección',
    resumen: 'Girar no mueve al robot de casilla: sólo cambia hacia dónde mira. Orientá primero y después avanzá.',
    pasos: [
      { titulo: 'Girar a la izquierda ↶', texto: 'El robot gira 90° hacia la izquierda. De ↑ pasa a ←, de ← pasa a ↓, de ↓ pasa a → y de → pasa a ↑.' },
      { titulo: 'Girar a la derecha ↷', texto: 'El robot gira 90° hacia la derecha. De ↑ pasa a →, de → pasa a ↓, de ↓ pasa a ← y de ← pasa a ↑.' },
      { titulo: 'Girar no desplaza', texto: 'Después de girar, la posición del robot queda igual: sólo cambia la orientación.' },
    ],
  },
  'tutorial-obstaculos': {
    titulo: 'Obstáculos',
    resumen: 'Las casillas con × son obstáculos: el robot no puede entrar en ellas. Hay que planificar el recorrido por los espacios libres.',
    pasos: [
      { titulo: 'Qué son', texto: 'Cada × marca una casilla bloqueada. Un recorrido con instrucciones que chocan contra un obstáculo no llega a la estrella.' },
      { titulo: 'Qué pasa si choca', texto: 'Si el robot intenta avanzar contra un obstáculo (o contra el borde del tablero), la ejecución se detiene ahí mismo.' },
      { titulo: 'Planificá otra ruta', texto: 'Mirá el mapa, identificá los obstáculos y pensá una ruta alternativa antes de agregar tus instrucciones.' },
    ],
  },
  'tutorial-bucles': {
    titulo: 'Repetir instrucciones (bucles)',
    resumen: '¿Cuatro avances seguidos? Podés escribirlos como un bucle de repetición: un bucle ×3 ejecuta la siguiente instrucción tres veces seguidas.',
    pasos: [
      { titulo: 'Qué es un bucle', texto: 'Un bucle agrupa una instrucción para ejecutarla varias veces sin repetirla una por una.' },
      { titulo: 'Cuándo conviene', texto: 'Cuando necesitás repetir la misma instrucción varias veces seguidas: izquierda, derecha, avanzar… lo que sea.' },
      { titulo: 'Ejemplo', texto: 'En lugar de Avanzar + Avanzar + Avanzar, agregá Repetir → Avanzar. Ocupa menos espacio y se entiende mejor.' },
    ],
  },
  'tutorial-decisiones': {
    titulo: 'Tomar decisiones',
    resumen: 'El robot todavía no entiende la palabra "si", pero vos sí: mirar la orientación y lo que tenés adelante te ayuda a elegir el próximo giro.',
    pasos: [
      { titulo: 'Mirar antes de actuar', texto: 'Pensá qué orientación tiene el robot y qué hay adelante antes de agregar la siguiente instrucción.' },
      { titulo: 'Decidir el giro', texto: 'Si adelante hay un obstáculo o el borde, conviene girar antes de avanzar. Si el camino está libre, podés avanzar.' },
      { titulo: 'Anticipar', texto: 'Los mejores recorridos se piensan paso a paso antes de pulsar Ejecutar.' },
    ],
  },
}

const tutorialDatos = computed(() => TUTORIALES[datos.value.tutorial] ?? null)
const mostrarTutorial = ref(false)
const tutorialPaso = ref(0)

watch([tutorialDatos, () => props.pregunta?.id], () => {
  if (!tutorialDatos.value) {
    mostrarTutorial.value = false
    return
  }
  const clave = `pl-tutorial:${props.pregunta?.id}`
  let visto = false
  try { visto = sessionStorage.getItem(clave) === '1' } catch { visto = false }
  mostrarTutorial.value = !visto
  tutorialPaso.value = 0
}, { immediate: true })

function cerrarTutorial() {
  mostrarTutorial.value = false
  if (tutorialDatos.value && props.pregunta?.id) {
    try { sessionStorage.setItem(`pl-tutorial:${props.pregunta.id}`, '1') } catch { /* sin almacenamiento */ }
  }
}

function irPasoTutorial(delta) {
  const total = tutorialDatos.value?.pasos.length ?? 1
  tutorialPaso.value = (tutorialPaso.value + delta + total) % total
}

const FLECHAS = ['↑', '→', '↓', '←']

const datos = computed(() => props.pregunta?.datos ?? {})
const tablero = computed(() => datos.value.tablero ?? {})
const inicio = computed(() => tablero.value.inicio ?? 20)
const casaInicial = computed(() => ({ pos: tablero.value.inicio ?? 20, rumbo: tablero.value.rumbo ?? 0 }))
const meta = computed(() => tablero.value.meta ?? 0)
const muros = computed(() => tablero.value.muros ?? [])
const maxSecuencia = computed(() => Math.min(Number(datos.value.maxInstrucciones ?? 30), 30))

const INSTRUCCIONES = [
  { id: 'avanzar', texto: 'Avanzar', simbolo: '↑' },
  { id: 'izquierda', texto: 'Girar a la izquierda', simbolo: '↶' },
  { id: 'derecha', texto: 'Girar a la derecha', simbolo: '↷' },
  { id: 'repetir', texto: 'Repetir ×3', simbolo: '↻' },
]

const instruccionesDisponibles = computed(() => {
  const permitidas = datos.value.instrucciones
  if (!permitidas || !Array.isArray(permitidas)) return INSTRUCCIONES
  return INSTRUCCIONES.filter(i => permitidas.includes(i.id))
})

const casilla = ref(casaInicial.value.pos)
const rumbo = ref(casaInicial.value.rumbo)
const huellas = ref([casaInicial.value.pos])
const secuencia = ref([])
const ejecutando = ref(false)
const mostrarAyuda = ref(false)
const mensaje = ref(datos.value.objetivo ?? 'Construí la secuencia y pulsá Ejecutar.')
const tipoFeedback = ref('info')
let temporizador = null
let pasoActual = 0

const editable = computed(() => !props.corrigiendo && !ejecutando.value && !props.devolucion)

const claseFeedback = computed(() => {
  if (props.devolucion?.estado === 'correcta') return 'robot-feedback-exito'
  if (props.devolucion?.estado === 'incorrecta') return 'robot-feedback-error'
  if (tipoFeedback.value === 'exito') return 'robot-feedback-exito'
  if (tipoFeedback.value === 'error') return 'robot-feedback-error'
  return 'robot-feedback-info'
})

function describirCasilla(n) {
  if (casilla.value === n) return 'Robot ' + FLECHAS[rumbo.value]
  if (meta.value === n) return 'Meta'
  if (muros.value.includes(n)) return 'Obstáculo'
  if (inicio.value === n) return 'Inicio'
  return 'Libre'
}

function contenidoCasilla(n) {
  if (casilla.value === n) return FLECHAS[rumbo.value]
  if (meta.value === n) return '★'
  if (muros.value.includes(n)) return '×'
  if (inicio.value === n) return 'I'
  return ''
}

function instruccionTexto(id) {
  const inst = INSTRUCCIONES.find(i => i.id === id)
  return inst?.texto ?? id
}

function agregar(id) {
  if (!editable.value || secuencia.value.length >= maxSecuencia.value) return
  secuencia.value.push(id)
  notificarPrograma()
}

function quitarUltima() {
  if (!editable.value) return
  secuencia.value.pop()
  notificarPrograma()
}

function borrarTodo() {
  if (!editable.value) return
  secuencia.value = []
  resetear()
  notificarPrograma()
}

function resetear() {
  casilla.value = casaInicial.value.pos
  rumbo.value = casaInicial.value.rumbo
  huellas.value = [casaInicial.value.pos]
  mensaje.value = 'Tu decisión: probá de nuevo.'
  tipoFeedback.value = 'info'
}

const MOVIMIENTOS = [ { fila: -1, col: 0 }, { fila: 0, col: 1 }, { fila: 1, col: 0 }, { fila: 0, col: -1 } ]

function mover(posicion, direccion) {
  const d = MOVIMIENTOS[direccion]
  const fila = Math.floor(posicion / 5) + d.fila
  const col = (posicion % 5) + d.col
  if (fila < 0 || fila > 4 || col < 0 || col > 4) return null
  const siguiente = fila * 5 + col
  if (muros.value.includes(siguiente)) return null
  return siguiente
}

function expandir(tokens) {
  const out = []
  let i = 0
  while (i < tokens.length) {
    if (tokens[i] === 'repetir') {
      const next = tokens[i + 1]
      if (!next) break
      for (let k = 0; k < 3; k += 1) out.push(next)
      i += 2
    } else {
      out.push(tokens[i])
      i += 1
    }
  }
  return out
}

function ejecutar() {
  if (ejecutando.value || !secuencia.value.length || props.corrigiendo) return
  resetear()
  const reduceMovimiento =
    typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  pasoActual = 0

  if (reduceMovimiento) {
    const programa = expandir(secuencia.value)
    ejecutando.value = true
    for (const inst of programa) {
      if (inst === 'izquierda') {
        rumbo.value = (rumbo.value + 3) % 4
      } else if (inst === 'derecha') {
        rumbo.value = (rumbo.value + 1) % 4
      } else if (inst === 'avanzar') {
        const siguiente = mover(casilla.value, rumbo.value)
        if (siguiente === null) {
          ejecutando.value = false
          mensaje.value = 'El robot chocó. Revisá la secuencia y probá otra vez.'
          tipoFeedback.value = 'error'
          return
        }
        casilla.value = siguiente
      }
    }
    ejecutando.value = false
    if (casilla.value === meta.value) {
      mensaje.value = `¡Llegaste a la estrella en ${secuencia.value.length} instrucciones! Pulsa Comprobar para validar.`
      tipoFeedback.value = 'exito'
    } else {
      mensaje.value = 'La secuencia terminó antes de llegar a la estrella.'
      tipoFeedback.value = 'error'
    }
    return
  }

  ejecutando.value = true
  mensaje.value = 'Ejecutando…'
  tipoFeedback.value = 'info'
  clearInterval(temporizador)
  const programa = expandir(secuencia.value)
  temporizador = setInterval(() => {
    if (pasoActual >= programa.length) {
      finalizar()
      return
    }
    const inst = programa[pasoActual]
    if (inst === 'izquierda') {
      rumbo.value = (rumbo.value + 3) % 4
      huellas.value.push(casilla.value)
    } else if (inst === 'derecha') {
      rumbo.value = (rumbo.value + 1) % 4
      huellas.value.push(casilla.value)
    } else if (inst === 'avanzar') {
      const siguiente = mover(casilla.value, rumbo.value)
      if (siguiente === null) {
        clearInterval(temporizador)
        ejecutando.value = false
        mensaje.value = 'El robot chocó. Revisá la secuencia y probá otra vez.'
        tipoFeedback.value = 'error'
        return
      }
      casilla.value = siguiente
      huellas.value.push(casilla.value)
    }
    pasoActual += 1
  }, 280)
}

function finalizar() {
  clearInterval(temporizador)
  ejecutando.value = false
  if (casilla.value === meta.value) {
    mensaje.value = `¡Llegaste a la estrella en ${secuencia.value.length} instrucciones! Pulsa Comprobar para validar.`
    tipoFeedback.value = 'exito'
  } else {
    mensaje.value = 'La secuencia terminó antes de llegar a la estrella.'
    tipoFeedback.value = 'error'
  }
}

onBeforeUnmount(() => {
  clearInterval(temporizador)
})

watch(() => props.pregunta?.id, () => {
  clearInterval(temporizador)
  ejecutando.value = false
  mostrarAyuda.value = false
  casilla.value = casaInicial.value.pos
  rumbo.value = casaInicial.value.rumbo
  huellas.value = [casaInicial.value.pos]
  secuencia.value = []
  mensaje.value = datos.value.objetivo ?? 'Construí la secuencia y pulsá Ejecutar.'
  tipoFeedback.value = 'info'
  pasoActual = 0
  notificarPrograma()
})
</script>

<style scoped>
.robot-juego {
  display: grid;
  gap: var(--k-space-4);
  color: var(--k-text);
}

.robot-objetivo {
  display: grid;
  gap: 6px;
}

.robot-eyebrow {
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--k-accent);
  font-weight: 800;
}

.robot-titulo {
  font-size: 18px;
  font-weight: 700;
  line-height: 1.35;
}

.robot-instrucciones {
  font-size: 13px;
  color: var(--k-text-2);
  line-height: 1.5;
}

.robot-tablero {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 4px;
  padding: 8px;
  border-radius: var(--k-radius);
  border: 1px solid var(--k-line);
  background: rgba(23, 23, 36, 0.9);
  aspect-ratio: 1 / 1;
  max-width: 390px;
  margin: 0 auto;
  width: 100%;
}

.robot-casilla {
  display: grid;
  place-items: center;
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(126, 34, 206, 0.18);
  background: var(--k-surface-2);
  color: #d8b4fe;
  font-size: clamp(16px, 6vw, 24px);
  font-weight: 800;
  transition: transform 0.16s ease, background 0.16s ease, color 0.16s ease;
}

.robot-casilla.es-paso {
  background: rgba(142, 5, 194, 0.16);
  border-color: rgba(142, 5, 194, 0.32);
}

.robot-casilla.es-meta {
  background: rgba(22, 163, 74, 0.14);
  color: #86efac;
  border-color: rgba(34, 197, 94, 0.32);
}

.robot-casilla.es-muro {
  background: rgba(51, 65, 85, 0.85);
  color: #94a3b8;
  border-color: rgba(71, 85, 105, 0.55);
}

.robot-casilla.es-robot {
  background: var(--k-accent);
  color: #ffffff;
  border-color: var(--k-accent);
  box-shadow: 0 0 18px rgba(142, 5, 194, 0.45);
  transform: scale(1.05);
}

.robot-casilla.es-inicio:not(.es-robot) {
  color: var(--k-text-3);
  font-size: clamp(16px, 5vw, 20px);
}

.robot-paneles {
  display: grid;
  gap: var(--k-space-4);
  grid-template-columns: 1fr;
}

@media (min-width: 900px) {
  .robot-paneles {
    grid-template-columns: 1fr 1.1fr;
  }
}

.robot-paleta,
.robot-secuencia-panel {
  display: grid;
  gap: var(--k-space-3);
}

.robot-paleta-titulo {
  font-size: 11px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--k-text-2);
  font-weight: 800;
}

.robot-paleta-botones {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.robot-instruccion {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 12px;
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  cursor: pointer;
  transition: border-color 0.14s ease, background 0.14s ease, transform 0.08s ease;
  font-size: 14px;
  font-weight: 700;
}

.robot-instruccion:hover:not(:disabled) {
  border-color: var(--k-accent);
  background: rgba(142, 5, 194, 0.12);
}

.robot-instruccion:disabled {
  opacity: 0.48;
  cursor: not-allowed;
}

.robot-instruccion-simbolo {
  font-size: 18px;
  color: var(--k-accent);
}

.robot-secuencia {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 6px;
  max-height: 220px;
  overflow: auto;
}

.robot-instruccion-valor {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(142, 5, 194, 0.18);
  background: rgba(142, 5, 194, 0.08);
  font-size: 13px;
}

.robot-secuencia-indice {
  color: var(--k-text-2);
  font-weight: 700;
}

.robot-vacio {
  font-size: 13px;
  color: var(--k-text-2);
  padding: 10px 0;
}

.robot-acciones {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.robot-feedback {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  font-size: 13px;
}

.robot-feedback-exito {
  border-color: rgba(34, 197, 94, 0.35);
  background: rgba(34, 197, 94, 0.12);
  color: #86efac;
}

.robot-feedback-error {
  border-color: rgba(248, 113, 113, 0.32);
  background: rgba(248, 113, 113, 0.1);
  color: #fca5a5;
}

.robot-feedback-info {
  border-color: rgba(142, 5, 194, 0.28);
  background: rgba(142, 5, 194, 0.1);
}

.robot-ayuda {
  margin-left: auto;
  background: transparent;
  border: 1px solid var(--k-line);
  color: var(--k-text-2);
  border-radius: var(--k-radius-sm);
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  font-size: 12px;
  cursor: pointer;
}

.robot-ayuda-panel {
  display: grid;
  gap: var(--k-space-2);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px dashed rgba(142, 5, 194, 0.35);
  background: rgba(23, 23, 36, 0.65);
  font-size: 13px;
  color: var(--k-text-2);
  line-height: 1.5;
}

.robot-ayuda-titulo {
  font-weight: 800;
  color: var(--k-accent);
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.06em;
}

.robot-ayuda-pista {
  color: var(--k-text);
}

.robot-tutorial {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 20px;
  background: rgba(0, 0, 0, 0.72);
  backdrop-filter: blur(3px);
}

.robot-tutorial-card {
  position: relative;
  width: 100%;
  max-width: 460px;
  display: grid;
  gap: var(--k-space-3);
  padding: var(--k-space-4) var(--k-space-5);
  border-radius: var(--k-radius);
  background: #170724;
  border: 1px solid rgba(142, 5, 194, 0.4);
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.6);
}

.robot-tutorial-cerrar {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  border: none;
  color: var(--k-text-2);
  border-radius: var(--k-radius-sm);
  padding: 6px;
  cursor: pointer;
}

.robot-tutorial-eyebrow {
  font-size: 10px;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  color: var(--k-accent);
  font-weight: 800;
}

.robot-tutorial-titulo {
  font-size: 22px;
  font-weight: 800;
  line-height: 1.25;
}

.robot-tutorial-resumen {
  font-size: 13px;
  color: var(--k-text-2);
  line-height: 1.55;
}

.robot-tutorial-lista {
  list-style: none;
  display: grid;
  gap: 8px;
}

.robot-tutorial-boton {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 8px 10px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 13px;
  font-weight: 700;
  text-align: left;
  cursor: pointer;
}

.robot-tutorial-paso.activo .robot-tutorial-boton {
  border-color: var(--k-accent);
  background: rgba(142, 5, 194, 0.14);
}

.robot-tutorial-indice {
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: rgba(142, 5, 194, 0.22);
  color: var(--k-accent);
  font-size: 12px;
  font-weight: 800;
}

.robot-tutorial-texto {
  margin-top: 6px;
  font-size: 12.5px;
  color: var(--k-text-2);
  line-height: 1.6;
  padding: 0 6px 6px;
}

.robot-tutorial-acciones {
  display: flex;
  gap: 8px;
  justify-content: space-between;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
