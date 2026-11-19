<template>
  <div class="lb-juego">
    <div class="lb-accBar">
      <p class="lb-eyebrow">Pensamiento Lógico</p>
      <div class="lb-accBar-meta">
        <span class="lb-chip lb-chip-meta"><span class="lb-chip-icono">★</span> Meta</span>
      </div>
    </div>

    <div class="lb-escena" aria-label="Tablero del nivel en perspectiva 3D">
      <div class="lb-glow lb-glow-cyan" aria-hidden="true" />
      <div class="lb-glow lb-glow-violeta" aria-hidden="true" />
      <div class="lb-tablero">
        <div
          v-for="n in 25"
          :key="n"
          class="lb-baldosa"
          :class="{
            'es-muro': muros.includes(n - 1),
            'es-meta': meta === n - 1,
            'es-energizada': huellas.includes(n - 1) && casilla !== n - 1,
            'es-inicio': inicio === n - 1 && casilla !== n - 1,
          }"
          :aria-label="describirCasilla(n - 1)"
        >
          <span class="lb-baldosa-nucleo">
            <span class="lb-baldosa-brillo" aria-hidden="true" />
            <template v-if="meta === n - 1">
              <span class="lb-antena" aria-hidden="true">
                <span class="lb-antena-arco" />
                <span class="lb-antena-centro" />
              </span>
            </template>
            <template v-else-if="muros.includes(n - 1)">
              <span class="lb-muro" />
            </template>
          </span>
        </div>

        <div class="lb-robot" :class="`mira-${rumbo}`" :style="estiloRobot" aria-hidden="true">
          <div class="lb-robot-sombra" />
          <div class="lb-robot-cuerpo">
            <span class="lb-robot-antena" />
            <span class="lb-robot-visera">
              <span class="lb-robot-ojo" />
              <span class="lb-robot-ojo" />
            </span>
            <span class="lb-robot-raya" />
          </div>
        </div>
      </div>
    </div>

    <div class="lb-panel">
      <div class="lb-tabs" role="tablist" aria-label="Elegir qué programa estás editando">
        <button
          type="button"
          role="tab"
          class="lb-tab"
          :class="{ activo: modoPrograma === 'principal' }"
          :aria-selected="modoPrograma === 'principal'"
          @click="modoPrograma = 'principal'"
        >
          Programa
          <span class="lb-tab-contador k-mono">{{ secuencia.length }}/{{ maxSecuencia }}</span>
        </button>
        <button
          v-if="permiteProcedimientos"
          type="button"
          role="tab"
          class="lb-tab"
          :class="{ activo: modoPrograma === 'procedimiento' }"
          :aria-selected="modoPrograma === 'procedimiento'"
          @click="modoPrograma = 'procedimiento'"
        >
          Procedimiento F
          <span class="lb-tab-contador k-mono">{{ procedimientoF.length }}/{{ MAX_PROCEDIMIENTO }}</span>
        </button>
      </div>

      <div class="lb-paleta" role="toolbar" aria-label="Instrucciones">
        <button
          v-for="inst in instruccionesDisponibles"
          :key="inst.id"
          type="button"
          class="lb-instruccion"
          :disabled="!editable || secuenciaActiva.length >= maxActivo"
          @click="agregar(inst.id)"
        >
          <span class="lb-instruccion-simbolo" aria-hidden="true">{{ inst.simbolo }}</span>
          <span class="lb-instruccion-texto">{{ inst.texto }}</span>
        </button>
      </div>

      <div class="lb-ranura">
        <div class="lb-ranura-cabecera">
          <p class="lb-ranura-titulo">{{ modoPrograma === 'principal' ? 'PROGRAMA' : 'PROCEDIMIENTO F' }}</p>
          <span class="lb-ranura-contador k-mono">{{ secuenciaActiva.length }}/{{ maxActivo }}</span>
        </div>
        <div class="lb-casilleros" :class="{ 'es-compacto': maxActivo > 14 }" role="list" :aria-label="(modoPrograma === 'principal' ? 'Programa principal' : 'Procedimiento F') + ': ' + secuenciaActiva.length + ' instrucciones'">
          <button
            v-for="i in maxActivo"
            :key="i"
            type="button"
            class="lb-casillero"
            :class="{ 'tiene-instruccion': Boolean(secuenciaActiva[i - 1]) }"
            :aria-label="secuenciaActiva[i - 1] ? `Paso ${i}: ${instruccionTexto(secuenciaActiva[i - 1])}` : `Paso ${i}, vacío`"
            @click="tocarCasillero(i - 1)"
          >
            <span v-if="secuenciaActiva[i - 1]" class="lb-casillero-simbolo">{{ simboloDe(secuenciaActiva[i - 1]) }}</span>
            <span v-else class="lb-casillero-hueco">·</span>
          </button>
        </div>
        <div class="lb-acciones">
          <button type="button" class="lb-boton lb-boton--fantasma" :disabled="!editable || secuenciaActiva.length === 0" @click="quitarUltima">
            <q-icon name="undo" size="18px" />
            Deshacer
          </button>
          <button type="button" class="lb-boton lb-boton--fantasma" :disabled="!editable || secuenciaActiva.length === 0" @click="borrarTodo">
            <q-icon name="delete_sweep" size="18px" />
            Borrar
          </button>
          <button type="button" class="lb-boton lb-boton--correr" :disabled="!editable || (secuencia.length === 0 && procedimientoF.length === 0)" @click="ejecutar">
            <q-icon name="play_arrow" size="20px" />
            Ejecutar
          </button>
        </div>
      </div>
    </div>

    <div class="lb-feedback" :class="claseFeedback" role="status">
      <q-icon v-if="tipoFeedback === 'exito'" name="celebration" size="20px" />
      <q-icon v-else-if="tipoFeedback === 'error'" name="error_outline" size="20px" />
      <q-icon v-else name="lightbulb" size="20px" />
      <span>{{ mensaje }}</span>
      <button type="button" class="lb-ayuda-boton" :aria-label="mostrarAyuda ? 'Ocultar ayuda' : 'Mostrar ayuda'" @click="mostrarAyuda = !mostrarAyuda">
        <q-icon :name="mostrarAyuda ? 'expand_less' : 'help_outline'" size="18px" />
        {{ mostrarAyuda ? 'Ocultar' : 'Ayuda' }}
      </button>
    </div>

    <transition name="fade">
      <div v-if="mostrarAyuda" class="lb-ayuda-panel">
        <p class="lb-ayuda-titulo">¿Necesitás una pista?</p>
        <p>{{ pregunta?.datos?.ayuda || 'Mirá desde dónde arranca el robot (casilla con varios puntos) y hacia dónde apunta la antena. Pensá ruta a ruta: girá primero, avanzá después. Cada casilla pisada se enciende.' }}</p>
        <p v-if="pregunta?.datos?.pasos" class="lb-ayuda-pista">{{ pregunta.datos.pasos }}</p>
      </div>
    </transition>

    <transition name="fade">
      <div v-if="mostrarTutorial && tutorialDatos" class="lb-tutorial" role="dialog" aria-modal="true" :aria-label="'Tutorial: ' + tutorialDatos.titulo">
        <div class="lb-tutorial-card">
          <button type="button" class="lb-tutorial-cerrar" aria-label="Cerrar tutorial" @click="cerrarTutorial">
            <q-icon name="close" size="20px" />
          </button>
          <p class="lb-tutorial-eyebrow">Tutorial</p>
          <h3 class="lb-tutorial-titulo">{{ tutorialDatos.titulo }}</h3>
          <p class="lb-tutorial-resumen">{{ tutorialDatos.resumen }}</p>
          <ol class="lb-tutorial-lista">
            <li v-for="(paso, i) in tutorialDatos.pasos" :key="i" class="lb-tutorial-paso" :class="{ activo: tutorialPaso === i }">
              <button type="button" class="lb-tutorial-boton" @click="tutorialPaso = i">
                <span class="lb-tutorial-indice k-mono">{{ i + 1 }}</span>
                <span>{{ paso.titulo }}</span>
              </button>
              <p v-if="tutorialPaso === i" class="lb-tutorial-texto">{{ paso.texto }}</p>
            </li>
          </ol>
          <div class="lb-tutorial-acciones">
            <button type="button" class="lb-boton lb-boton--fantasma" :disabled="tutorialPaso === 0" @click="irPasoTutorial(-1)">
              <q-icon name="chevron_left" size="18px" />
              Anterior
            </button>
            <button v-if="tutorialPaso < tutorialDatos.pasos.length - 1" type="button" class="lb-boton lb-boton--correr" @click="irPasoTutorial(1)">
              Siguiente
              <q-icon name="chevron_right" size="18px" />
            </button>
            <button v-else type="button" class="lb-boton lb-boton--correr" @click="cerrarTutorial">
              <q-icon name="play_arrow" size="18px" />
              A jugar
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
  emit('programa', { robot: [...secuencia.value], robotProc: [...procedimientoF.value] })
}

const TUTORIALES = {
  'tutorial-robot': {
    titulo: 'Conocé al robot',
    resumen: 'Cada nivel tiene un tablero con casillas, un robot y un punto de partida. Tu trabajo: escribir el programa que hace que el robot encienda todas las baldosas y llegue a la antena.',
    pasos: [
      { titulo: 'El tablero', texto: 'La cuadrícula tiene casillas. La casilla de arranque está marcada con varios puntos y la meta es la antena brillante.' },
      { titulo: 'La orientación', texto: 'La ventanita del robot muestra a dónde mira: ↑, →, ↓ o ←. Las instrucciones actúan sobre esa orientación.' },
      { titulo: 'Avanzar y girar', texto: 'Avanzar mueve una casilla hacia donde mira. Girar a la izquierda (↶) o a la derecha (↷) cambia la orientación sin moverse.' },
      { titulo: 'Construí tu programa', texto: 'Agregá instrucciones a los casilleros y pulsá Ejecutar. Vas a ver cómo el robot recorre el tablero paso a paso.' },
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
  'tutorial-salto': {
    titulo: 'El salto',
    resumen: 'Habrá veces que el camino tenga un obstáculo infranqueable. El salto supera una casilla bloqueada aterrizando dos casillas adelante.',
    pasos: [
      { titulo: 'Qué hace', texto: 'Saltar mueve al robot 2 casillas en la dirección a la que mira, saltando por encima de la casilla intermedia aunque esté bloqueada.' },
      { titulo: 'Cuándo conviene', texto: 'Ideal cuando el camino está cortado por un muro puntual y más allá hay espacio libre.' },
      { titulo: 'Dónde aterriza', texto: 'La casilla de aterrizaje debe estar libre: si es un obstáculo o queda fuera del tablero, el robot no puede saltar ahí.' },
    ],
  },
  'tutorial-procedimientos': {
    titulo: 'Procedimientos F',
    resumen: 'Si un patrón de instrucciones aparece varias veces, lo convertís en un procedimiento: una sub-secuencia separada que invocás con Llamar F.',
    pasos: [
      { titulo: 'Qué es', texto: 'Un procedimiento (F) es una secuencia de instrucciones separada del programa principal. Se construye una vez y se reutiliza todas las veces que haga falta.' },
      { titulo: 'Cuándo conviene', texto: 'Cuando el mismo patrón aparece repetido dentro del camino. En vez de escribirlo 2-3 veces, lo guardás en F y lo invocás con Llamar F.' },
      { titulo: 'Cómo se usa', texto: 'Cambiá a la pestaña «Procedimiento F», armá el patrón y volvé a «Programa». Agregá «Llamar F» donde lo necesites. El robot ejecuta F en ese punto del camino.' },
    ],
  },
  'tutorial-buclebloque': {
    titulo: 'Bucles de bloque',
    resumen: 'Si un grupo de instrucciones se repite, lo encerrás en un bucle para ejecutarlo N veces sin escribirlo una y otra vez.',
    pasos: [
      { titulo: 'Qué es', texto: 'Un bucle ejecuta la secuencia encerrada entre BucleN y Fin, N veces. Con Bucle3 repetís ese bloque tres veces sin copiar las instrucciones.' },
      { titulo: 'Cómo se construye', texto: 'Abres el bloque con BucleN (por ejemplo Bucle3), escribís la secuencia a repetir y lo cerrás con Fin. Lo que está adentro se ejecuta N veces.' },
      { titulo: 'Cuándo conviene', texto: 'Cuando detectás un grupo de instrucciones que se repite exactamente (por ejemplo «avanzar, girar, avanzar») y querés ahorrar espacio y claridad.' },
    ],
  },
  'tutorial-obstaculos': {
    titulo: 'Muros y obstáculos',
    resumen: 'Las casillas altas bloqueadas te marcan por dónde no puede pasar el robot. Hay que planificar la ruta por los espacios libres.',
    pasos: [
      { titulo: 'Qué son', texto: 'Los bloques de color oscuro son obstáculos que nadie atraviesa. Si el robot intentara, se detiene ahí.' },
      { titulo: 'Qué pasa si choca', texto: 'La ejecución se corta justo antes de cruzar el muro o el borde. Pila saltamontes: girar no mueve, hay que cambiar de idea.' },
      { titulo: 'Planificá otra ruta', texto: 'Mirá el mapa, identificá los muros y pensá una ruta alternativa antes de programar.' },
    ],
  },
  'tutorial-bucles': {
    titulo: 'Repetir instrucciones (bucles)',
    resumen: '¿Cuatro avances seguidos? Un bucle ×3 ejecuta la siguiente instrucción tres veces seguidas y te ahorra casilleros.',
    pasos: [
      { titulo: 'Qué es un bucle', texto: 'Un bucle agrupa la instrucción siguiente para ejecutarla tres veces sin repetirla una por una.' },
      { titulo: 'Cuándo conviene', texto: 'Cuando necesitás repetir la misma instrucción varias veces seguidas: avanzar, girar… lo que sea.' },
      { titulo: 'Ejemplo', texto: 'En lugar de Avanzar + Avanzar + Avanzar, agregá Repetir → Avanzar. Ocupa un solo casillero y ahorra espacio.' },
    ],
  },
  'tutorial-decisiones': {
    titulo: 'Tomar decisiones',
    resumen: 'El robot todavía no entiende la palabra "si", pero vos sí: mirar la orientación y lo que tenés adelante te ayuda a elegir el próximo giro.',
    pasos: [
      { titulo: 'Mirar antes de actuar', texto: 'Pensá qué orientación tiene el robot y qué hay adelante antes de agregar la siguiente instrucción.' },
      { titulo: 'Decidir el giro', texto: 'Si adelante hay un muro o el borde, conviene girar antes de avanzar. Si el camino está libre, avanzás.' },
      { titulo: 'Anticipar', texto: 'Los mejores recorridos se piensan paso a paso antes de pulsar Ejecutar.' },
    ],
  },
}

const FLECHAS = ['↑', '→', '↓', '←']
const TAMANO = 5
const PASO = 100 / TAMANO

const datos = computed(() => props.pregunta?.datos ?? {})
const tutorialDatos = computed(() => TUTORIALES[datos.value.tutorial] ?? null)
const mostrarTutorial = ref(false)
const tutorialPaso = ref(0)

const tablero = computed(() => datos.value.tablero ?? {})
const inicio = computed(() => tablero.value.inicio ?? 20)
const casaInicial = computed(() => ({ pos: tablero.value.inicio ?? 20, rumbo: tablero.value.rumbo ?? 0 }))
const meta = computed(() => tablero.value.meta ?? 0)
const muros = computed(() => tablero.value.muros ?? [])
const maxSecuencia = computed(() => Math.min(Number(datos.value.maxInstrucciones ?? 10), 30))

const INSTRUCCIONES = [
  { id: 'avanzar', texto: 'Avanzar', simbolo: '↑' },
  { id: 'izquierda', texto: 'Girar izquierda', simbolo: '↶' },
  { id: 'derecha', texto: 'Girar derecha', simbolo: '↷' },
  { id: 'saltar', texto: 'Saltar', simbolo: '⤴' },
  { id: 'repetir', texto: 'Repetir ×3', simbolo: '↻' },
  { id: 'llamar', texto: 'Llamar F', simbolo: 'ƒ' },
  { id: 'bucle2', texto: 'Bucle ×2', simbolo: '⟳2' },
  { id: 'bucle3', texto: 'Bucle ×3', simbolo: '⟳3' },
  { id: 'bucle5', texto: 'Bucle ×5', simbolo: '⟳5' },
  { id: 'fin', texto: 'Fin bucle', simbolo: '⏏' },
]

const MAX_PROCEDIMIENTO = 12

const instruccionesDisponibles = computed(() => {
  const permitidas = datos.value.instrucciones
  if (!permitidas || !Array.isArray(permitidas)) return INSTRUCCIONES
  return INSTRUCCIONES.filter((i) => permitidas.includes(i.id))
})

const casilla = ref(casaInicial.value.pos)
const rumbo = ref(casaInicial.value.rumbo)
const huellas = ref([casaInicial.value.pos])
const secuencia = ref([])                      // programa principal
const procedimientoF = ref([])                 // procedimiento F
const modoPrograma = ref('principal')          // 'principal' | 'procedimiento'
const ejecutando = ref(false)
const mostrarAyuda = ref(false)
const mensaje = ref(datos.value.objetivo ?? 'Programá al robot y pulsá Ejecutar.')
const tipoFeedback = ref('info')
let temporizador = null
let pasoActual = 0

// Listado sobre el que estoy actuando según pestaña activa.
const secuenciaActiva = computed(() => (modoPrograma.value === 'principal' ? secuencia : procedimientoF))
const maxActivo = computed(() => (modoPrograma.value === 'principal' ? maxSecuencia.value : MAX_PROCEDIMIENTO))

const editable = computed(() => !props.corrigiendo && !ejecutando.value && !props.devolucion)

const claseFeedback = computed(() => {
  if (props.devolucion?.estado === 'correcta') return 'lb-feedback-exito'
  if (props.devolucion?.estado === 'incorrecta') return 'lb-feedback-error'
  if (tipoFeedback.value === 'exito') return 'lb-feedback-exito'
  if (tipoFeedback.value === 'error') return 'lb-feedback-error'
  return 'lb-feedback-info'
})

const estiloRobot = computed(() => {
  const fila = Math.floor(casilla.value / TAMANO)
  const col = casilla.value % TAMANO
  const left = col * PASO + PASO / 2
  const top = fila * PASO + PASO / 2
  return { left: `${left}%`, top: `${top}%` }
})

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

function describirCasilla(n) {
  if (casilla.value === n) return 'Robot ' + FLECHAS[rumbo.value]
  if (meta.value === n) return 'Meta'
  if (muros.value.includes(n)) return 'Muro'
  if (inicio.value === n) return 'Inicio'
  return 'Libre'
}

function instruccionTexto(id) {
  return INSTRUCCIONES.find((i) => i.id === id)?.texto ?? id
}

function simboloDe(id) {
  return INSTRUCCIONES.find((i) => i.id === id)?.simbolo ?? id
}

function agregar(id) {
  if (!editable.value || secuenciaActiva.value.length >= maxActivo.value) return
  secuenciaActiva.value.push(id)
  notificarPrograma()
}

function tocarCasillero(indice) {
  if (!editable.value || indice < 0 || indice >= secuenciaActiva.value.length) return
  secuenciaActiva.value.splice(indice, 1)
  notificarPrograma()
}

function quitarUltima() {
  if (!editable.value) return
  secuenciaActiva.value.pop()
  notificarPrograma()
}

function borrarTodo() {
  if (!editable.value) return
  secuenciaActiva.value = []
  resetear()
  notificarPrograma()
}

function resetear() {
  casilla.value = casaInicial.value.pos
  rumbo.value = casaInicial.value.rumbo
  huellas.value = [casaInicial.value.pos]
  mensaje.value = 'Probá otra ruta.'
  tipoFeedback.value = 'info'
}

const MOVIMIENTOS = [{ fila: -1, col: 0 }, { fila: 0, col: 1 }, { fila: 1, col: 0 }, { fila: 0, col: -1 }]

function pasoDe(posicion, direccion, metros) {
  const d = MOVIMIENTOS[direccion]
  const fila = Math.floor(posicion / TAMANO) + d.fila * metros
  const col = (posicion % TAMANO) + d.col * metros
  if (fila < 0 || fila >= TAMANO || col < 0 || col >= TAMANO) return null
  const siguiente = fila * TAMANO + col
  if (muros.value.includes(siguiente)) return null
  return siguiente
}



// A partir de una instrucción aplica el efecto y devuelve si tuvo éxito.
// 'saltar' mueve 2 casillas enfrentadas: salta la casilla intermedia aunque
// sea un muro; la casilla de aterrizaje debe estar libre y dentro del tablero.
function aplicarInstruccion(inst) {
  if (inst === 'izquierda') {
    rumbo.value = (rumbo.value + 3) % 4
    return true
  }
  if (inst === 'derecha') {
    rumbo.value = (rumbo.value + 1) % 4
    return true
  }
  if (inst === 'avanzar') {
    const siguiente = pasoDe(casilla.value, rumbo.value, 1)
    if (siguiente === null) return false
    casilla.value = siguiente
    huellas.value.push(casilla.value)
    return true
  }
  if (inst === 'saltar') {
    const siguiente = pasoDe(casilla.value, rumbo.value, 2)
    if (siguiente === null) return false
    casilla.value = siguiente
    huellas.value.push(casilla.value)
    return true
  }
  return false
}

function bucleCount(token) {
  const m = /^bucle([2-5])$/.exec(String(token))
  return m ? Number(m[1]) : null
}

// Expande un programa recursivamente:
//   repetir  → la instrucción siguiente ×3
//   llamar   → el cuerpo completo del procedimiento F
//   bucleN   → el bloque hasta 'fin', N veces (anidado hasta 2 niveles)
// Devuelve un array plano de tokens atómicos: avanzar | izquierda | derecha | saltar.
function expandirTokens(tokens, proc, depth = 0) {
  if (depth > 2) throw new Error('Anidamiento demasiado profundo en el programa')
  if (!Array.isArray(tokens)) return []

  const out = []
  let i = 0
  while (i < tokens.length) {
    const inst = tokens[i]

    if (inst === 'repetir') {
      const next = tokens[i + 1]
      if (!next) throw new Error('Repetir no tiene instrucción siguiente')
      for (let k = 0; k < 3; k += 1) out.push(next)
      i += 2
      continue
    }

    if (inst === 'llamar') {
      if (!Array.isArray(proc) || proc.length === 0) {
        throw new Error('Llamar requiere un procedimiento F vacío o terminar su definición')
      }
      const expandido = expandirTokens(proc, proc, depth + 1) // el propio proc puede tener bucles
      // pero no una llamada anidada recursiva
      out.push(...expandido)
      i += 1
      continue
    }

    const count = bucleCount(inst)
    if (count !== null) {
      // buscar el fin correspondiente
      let balance = 1
      let j = i + 1
      while (j < tokens.length) {
        const ajeno = bucleCount(tokens[j])
        if (ajeno !== null) balance += 1
        else if (tokens[j] === 'fin') balance -= 1
        if (balance === 0) break
        j += 1
      }
      if (balance !== 0) throw new Error('Bucle sin fin correspondiente')
      const cuerpo = tokens.slice(i + 1, j)
      const cuerpoExpandido = expandirTokens(cuerpo, proc, depth + 1)
      for (let k = 0; k < count; k += 1) out.push(...cuerpoExpandido)
      i = j + 1
      continue
    }

    if (inst === 'fin') throw new Error('Fin sin bucle que lo abra')
    out.push(inst)
    i += 1
  }
  return out
}

function expandir(tokens) {
  return expandirTokens(tokens, procedimientoF.value, 0)
}

const permiteProcedimientos = computed(() => instruccionesDisponibles.value.some((i) => i.id === 'llamar'))

function ejecutar() {
  if (ejecutando.value || props.corrigiendo) return
  if (!secuencia.value.length && !procedimientoF.value.length) return
  resetear()

  let programa = []
  try {
    programa = expandir(secuencia.value)
  } catch (error) {
    tipoFeedback.value = 'error'
    mensaje.value = `Programa inválido: ${error.message}`
    return
  }

  const reduceMovimiento =
    typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  pasoActual = 0

  if (reduceMovimiento) {
    ejecutando.value = true
    for (const inst of programa) {
      if (!aplicarInstruccion(inst)) {
        ejecutando.value = false
        mensaje.value = 'El robot no puede pasar por ahí. Probá otra ruta.'
        tipoFeedback.value = 'error'
        return
      }
    }
    ejecutando.value = false
    if (casilla.value === meta.value) {
      mensaje.value = `¡Nivel completado en ${secuencia.value.length} instrucciones! Pulsá Comprobar para validar tu solución.`
      tipoFeedback.value = 'exito'
    } else {
      mensaje.value = 'La antena sigue apagada. Faltó llegar a la meta.'
      tipoFeedback.value = 'error'
    }
    return
  }

  ejecutando.value = true
  mensaje.value = 'Ejecutando programa…'
  tipoFeedback.value = 'info'
  clearInterval(temporizador)
  temporizador = setInterval(() => {
    if (pasoActual >= programa.length) {
      finalizar()
      return
    }
    const inst = programa[pasoActual]
    if (!aplicarInstruccion(inst)) {
      clearInterval(temporizador)
      ejecutando.value = false
      mensaje.value = 'El robot chocó contra un muro. Revisá la secuencia.'
      tipoFeedback.value = 'error'
      return
    }
    pasoActual += 1
  }, 260)
}

function finalizar() {
  clearInterval(temporizador)
  ejecutando.value = false
  if (casilla.value === meta.value) {
    mensaje.value = `¡Antena encendida! Llegaste en ${secuencia.value.length} instrucciones. Pulsá Comprobar.`
    tipoFeedback.value = 'exito'
  } else {
    mensaje.value = 'La antena sigue apagada. Probá una ruta que llegue a la meta.'
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
  procedimientoF.value = []
  mensaje.value = datos.value.objetivo ?? 'Programá al robot y pulsá Ejecutar.'
  tipoFeedback.value = 'info'
  pasoActual = 0
  notificarPrograma()
})
</script>

<style scoped>
.lb-juego {
  display: grid;
  gap: var(--k-space-4);
  color: var(--k-text);
}

.lb-accBar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 0 2px;
}

.lb-eyebrow {
  font-size: 11px;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  color: #7dd3fc;
  font-weight: 800;
}

.lb-accBar-meta {
  flex-shrink: 0;
}

.lb-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.04em;
}

.lb-chip-meta {
  color: #7dd3fc;
  border: 1px solid rgba(125, 211, 252, 0.4);
  background: rgba(125, 211, 252, 0.08);
}

.lb-chip-icono {
  color: #fde68a;
  text-shadow: 0 0 8px rgba(253, 230, 138, 0.65);
}

/* ---------- Escena con el tablero en perspectiva ---------- */

.lb-escena {
  position: relative;
  display: grid;
  place-items: center;
  padding: 28px 12px 36px;
  border-radius: var(--k-radius);
  border: 1px solid rgba(125, 211, 252, 0.15);
  background:
    radial-gradient(ellipse at 50% 120%, rgba(194, 65, 12, 0.25), transparent 60%),
    radial-gradient(ellipse at 50% -40%, rgba(34, 211, 238, 0.28), transparent 60%),
    linear-gradient(180deg, #1b1040 0%, #130c29 100%);
  overflow: hidden;
  perspective: 900px;
}

.lb-glow {
  position: absolute;
  width: 60%;
  height: 60%;
  border-radius: 50%;
  filter: blur(60px);
  opacity: 0.5;
  pointer-events: none;
}

.lb-glow-cyan {
  background: radial-gradient(circle, rgba(34, 211, 238, 0.35), transparent 70%);
  top: -20%;
  left: -10%;
}

.lb-glow-violeta {
  background: radial-gradient(circle, rgba(142, 5, 194, 0.4), transparent 70%);
  bottom: -30%;
  right: -10%;
}

.lb-tablero {
  position: relative;
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 7px;
  width: min(100%, 380px);
  aspect-ratio: 1 / 1;
  padding: 10px;
  transform: rotateX(18deg);
  transform-style: preserve-3d;
}

.lb-baldosa {
  position: relative;
  border-radius: 10px;
  height: 100%;
  display: grid;
  place-items: center;
  background:
    linear-gradient(145deg, #3f2f68 0%, #2d2154 45%, #241a43 100%);
  border: 1px solid rgba(148, 163, 184, 0.25);
  box-shadow:
    0 8px 0 #1b1233,
    0 14px 18px rgba(0, 0, 0, 0.45),
    inset 0 1px 0 rgba(255, 255, 255, 0.12);
  transition: background 0.18s ease, box-shadow 0.18s ease, transform 0.18s ease;
}

.lb-baldosa-nucleo {
  display: grid;
  place-items: center;
  width: 100%;
  height: 100%;
  position: relative;
}

.lb-baldosa-brillo {
  position: absolute;
  inset: 12%;
  border-radius: 8px;
  background: radial-gradient(ellipse at 50% 10%, rgba(255, 255, 255, 0.15), transparent 60%);
  pointer-events: none;
}

.lb-baldosa.es-energizada {
  background:
    radial-gradient(circle at 50% 50%, rgba(34, 211, 238, 0.5), rgba(14, 116, 144, 0.55) 70%);
  border-color: rgba(34, 211, 238, 0.6);
  box-shadow:
    0 8px 0 #083345,
    0 14px 18px rgba(0, 0, 0, 0.45),
    inset 0 0 22px rgba(34, 211, 238, 0.5),
    0 0 22px rgba(34, 211, 238, 0.35);
}

.lb-baldosa.es-muro {
  background:
    linear-gradient(145deg, #574a7a 0%, #453a63 45%, #382e52 100%);
  border-color: rgba(148, 163, 184, 0.18);
}

.lb-muro {
  width: 78%;
  height: 78%;
  border-radius: 8px;
  background:
    linear-gradient(145deg, #6b5f92 0%, #544875 45%, #433a63 100%);
  box-shadow:
    0 4px 0 #241c3d,
    inset 0 2px 0 rgba(255, 255, 255, 0.22),
    inset 0 -6px 8px rgba(0, 0, 0, 0.35);
}

.lb-baldosa.es-meta {
  border-color: rgba(253, 230, 138, 0.55);
  background:
    radial-gradient(circle at 50% 50%, rgba(253, 230, 138, 0.3), rgba(120, 53, 15, 0.5) 75%);
  box-shadow:
    0 8px 0 #33240a,
    0 14px 18px rgba(0, 0, 0, 0.45),
    inset 0 0 22px rgba(253, 230, 138, 0.35),
    0 0 26px rgba(253, 230, 138, 0.3);
}

.lb-baldosa.es-inicio {
  background: linear-gradient(145deg, #3f2f68 0%, #2d2154 45%, #241a43 100%);
}

.lb-baldosa.es-inicio .lb-baldosa-nucleo::after {
  content: '';
  width: 34%;
  height: 34%;
  border-radius: 50%;
  background: rgba(125, 211, 252, 0.18);
  border: 2px dashed rgba(125, 211, 252, 0.5);
}

/* Antena de la meta, inspirada en LightBot */
.lb-antena {
  position: relative;
  display: grid;
  place-items: center;
  width: 80%;
  height: 80%;
}

.lb-antena-centro {
  width: 34%;
  height: 34%;
  border-radius: 50%;
  background: radial-gradient(circle at 40% 35%, #fef9c3, #fde047 45%, #a16207 100%);
  box-shadow:
    0 0 10px rgba(253, 230, 138, 0.8),
    0 0 26px rgba(253, 230, 138, 0.45);
}

.lb-antena-arco {
  position: absolute;
  width: 78%;
  height: 78%;
  border-radius: 50%;
  border: 3px solid rgba(253, 230, 138, 0.75);
  border-bottom-color: transparent;
  border-left-color: transparent;
  animation: lb-antena-gira 3s linear infinite;
}

@keyframes lb-antena-gira {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* ---------- Robot ---------- */

.lb-robot {
  position: absolute;
  z-index: 5;
  width: 13%;
  height: 13%;
  transform: translate(-50%, -58%);
  display: grid;
  place-items: center;
  transition: left 0.26s cubic-bezier(0.22, 1.2, 0.36, 1), top 0.26s cubic-bezier(0.22, 1.2, 0.36, 1);
}

.lb-robot-sombra {
  position: absolute;
  bottom: -18%;
  width: 80%;
  height: 22%;
  border-radius: 50%;
  background: radial-gradient(ellipse, rgba(0, 0, 0, 0.55), transparent 70%);
}

.lb-robot-cuerpo {
  position: relative;
  width: 100%;
  height: 100%;
  border-radius: 22%;
  background:
    linear-gradient(160deg, #f97316 0%, #ea580c 40%, #c2410c 100%);
  border: 1.5px solid rgba(255, 255, 255, 0.22);
  box-shadow:
    0 4px 0 #7c2d12,
    0 6px 14px rgba(0, 0, 0, 0.5),
    inset 0 2px 0 rgba(255, 255, 255, 0.35);
  display: grid;
  place-items: center;
  transform: rotate(0deg);
  transition: transform 0.18s ease;
}

/* El robot apunta siempre hacia donde mira (arriba = norte) */
.lb-robot.mira-0 .lb-robot-cuerpo { transform: rotate(0deg); }
.lb-robot.mira-1 .lb-robot-cuerpo { transform: rotate(90deg); }
.lb-robot.mira-2 .lb-robot-cuerpo { transform: rotate(180deg); }
.lb-robot.mira-3 .lb-robot-cuerpo { transform: rotate(270deg); }

.lb-robot-visera {
  display: flex;
  gap: 18%;
  align-items: center;
  justify-content: center;
  width: 70%;
  height: 34%;
  border-radius: 999px;
  background: #111827;
  border: 1px solid rgba(125, 211, 252, 0.4);
  box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.8), 0 0 8px rgba(34, 211, 238, 0.35);
}

.lb-robot-ojo {
  width: 18%;
  height: 62%;
  border-radius: 999px;
  background: radial-gradient(circle at 35% 35%, #a5f3fc, #22d3ee 60%, #0e7490 100%);
  box-shadow: 0 0 6px rgba(34, 211, 238, 0.9);
}

.lb-robot-raya {
  position: absolute;
  bottom: 16%;
  width: 34%;
  height: 3px;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.45);
}

.lb-robot-antena {
  position: absolute;
  top: -16%;
  width: 4px;
  height: 22%;
  border-radius: 999px;
  background: #9a3412;
}

.lb-robot-antena::after {
  content: '';
  position: absolute;
  top: -45%;
  left: 50%;
  transform: translateX(-50%);
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: radial-gradient(circle, #fda4af, #e11d48 70%);
  box-shadow: 0 0 6px rgba(225, 29, 72, 0.9);
}

/* ---------- Panel táctil: paleta + casilleros ---------- */

.lb-tabs {
  display: flex;
  gap: 8px;
}

.lb-tab {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 8px;
  border-radius: 12px;
  border: 1.5px solid rgba(125, 211, 252, 0.22);
  background: #101a2e;
  color: #93c5fd;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.04em;
  cursor: pointer;
  transition: border-color 0.14s ease, background 0.14s ease, color 0.14s ease;
  -webkit-tap-highlight-color: transparent;
}

.lb-tab:hover {
  border-color: rgba(34, 211, 238, 0.35);
  color: #e0f2fe;
}

.lb-tab.activo {
  border-color: rgba(34, 211, 238, 0.6);
  background: rgba(34, 211, 238, 0.12);
  color: #e0f2fe;
  box-shadow: inset 0 2px 4px rgba(34, 211, 238, 0.12);
}

.lb-tab-contador {
  font-size: 11px;
  color: inherit;
  opacity: 0.8;
}

.lb-panel {
  display: grid;
  grid-template-columns: 1fr;
  gap: 14px;
}

.lb-paleta {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: center;
}

.lb-instruccion {
  display: grid;
  justify-items: center;
  gap: 4px;
  padding: 10px 14px;
  border-radius: 14px;
  border: 1.5px solid rgba(125, 211, 252, 0.3);
  background: linear-gradient(160deg, #253154 0%, #1b2340 100%);
  color: #e0f2fe;
  cursor: pointer;
  transition: border-color 0.14s ease, transform 0.08s ease, box-shadow 0.18s ease;
  box-shadow: 0 3px 0 #10172b;
  -webkit-tap-highlight-color: transparent;
}

.lb-instruccion:hover:not(:disabled) {
  border-color: rgba(34, 211, 238, 0.6);
  box-shadow: 0 3px 0 #10172b, 0 0 16px rgba(34, 211, 238, 0.25);
}

.lb-instruccion:active:not(:disabled) {
  transform: translateY(2px);
  box-shadow: 0 1px 0 #10172b;
}

.lb-instruccion:disabled {
  opacity: 0.42;
  cursor: not-allowed;
}

.lb-instruccion-simbolo {
  font-size: 26px;
  line-height: 1;
  color: #7dd3fc;
}

.lb-instruccion-texto {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.lb-ranura {
  display: grid;
  gap: 10px;
  padding: 12px;
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(125, 211, 252, 0.18);
  background: rgba(15, 23, 42, 0.55);
}

.lb-ranura-cabecera {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.lb-ranura-titulo {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.12em;
  color: var(--k-text-2);
}

.lb-ranura-contador {
  font-size: 12px;
  color: var(--k-text-2);
}

.lb-casilleros {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  justify-content: center;
}

.lb-casilleros.es-compacto .lb-casillero {
  width: 36px;
  height: 36px;
  border-radius: 9px;
}

.lb-casilleros.es-compacto .lb-casillero-simbolo {
  font-size: 18px;
}

.lb-casillero {
  width: 46px;
  height: 46px;
  border-radius: 12px;
  border: 1.5px dashed rgba(125, 211, 252, 0.22);
  background: #0b1220;
  display: grid;
  place-items: center;
  color: rgba(125, 211, 252, 0.32);
  cursor: pointer;
  transition: border-color 0.12s ease, background 0.12s ease;
  -webkit-tap-highlight-color: transparent;
}

.lb-casillero.tiene-instruccion {
  border-color: rgba(34, 211, 238, 0.45);
  background: #12233a;
  box-shadow: inset 0 2px 4px rgba(34, 211, 238, 0.12), 0 0 10px rgba(34, 211, 238, 0.16);
}

.lb-casillero-simbolo {
  font-size: 24px;
  line-height: 1;
}

.lb-casillero-hueco {
  color: rgba(125, 211, 252, 0.2);
  font-size: 20px;
}

.lb-acciones {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: space-between;
}

.lb-boton {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 10px 14px;
  border-radius: 12px;
  font-size: 13px;
  font-weight: 800;
  cursor: pointer;
  border: none;
  transition: transform 0.08s ease, box-shadow 0.16s ease, opacity 0.12s ease;
  -webkit-tap-highlight-color: transparent;
}

.lb-boton--fantasma {
  background: #1e293b;
  color: #cbd5e1;
  box-shadow: 0 3px 0 #0f172a;
}

.lb-boton--fantasma:hover:not(:disabled) {
  color: #f1f5f9;
}

.lb-boton--correr {
  background: linear-gradient(160deg, #22d3ee 0%, #0891b2 100%);
  color: #083344;
  box-shadow: 0 4px 0 #155e75, 0 6px 16px rgba(34, 211, 238, 0.35);
  padding-left: 16px;
  padding-right: 20px;
}

.lb-boton--correr:active:not(:disabled) {
  transform: translateY(2px);
  box-shadow: 0 1px 0 #155e75;
}

.lb-boton:disabled {
  opacity: 0.38;
  cursor: not-allowed;
}

.lb-feedback {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  font-size: 13px;
  line-height: 1.45;
}

.lb-feedback-exito {
  border-color: rgba(34, 197, 94, 0.35);
  background: rgba(34, 197, 94, 0.12);
  color: #86efac;
}

.lb-feedback-error {
  border-color: rgba(248, 113, 113, 0.32);
  background: rgba(248, 113, 113, 0.1);
  color: #fca5a5;
}

.lb-feedback-info {
  border-color: rgba(34, 211, 238, 0.3);
  background: rgba(34, 211, 238, 0.08);
  color: #bae6fd;
}

.lb-ayuda-boton {
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

.lb-ayuda-panel {
  display: grid;
  gap: var(--k-space-2);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px dashed rgba(34, 211, 238, 0.3);
  background: rgba(15, 23, 42, 0.65);
  font-size: 13px;
  color: var(--k-text-2);
  line-height: 1.5;
}

.lb-ayuda-titulo {
  font-weight: 800;
  color: #7dd3fc;
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.07em;
}

.lb-ayuda-pista {
  color: var(--k-text);
}

.lb-tutorial {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 20px;
  background: rgba(0, 0, 0, 0.72);
  backdrop-filter: blur(3px);
}

.lb-tutorial-card {
  position: relative;
  width: 100%;
  max-width: 460px;
  display: grid;
  gap: var(--k-space-3);
  padding: var(--k-space-4) var(--k-space-5);
  border-radius: var(--k-radius);
  background: #0f2137;
  border: 1px solid rgba(34, 211, 238, 0.3);
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.6);
}

.lb-tutorial-cerrar {
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

.lb-tutorial-eyebrow {
  font-size: 10px;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  color: #7dd3fc;
  font-weight: 800;
}

.lb-tutorial-titulo {
  font-size: 22px;
  font-weight: 800;
  line-height: 1.25;
}

.lb-tutorial-resumen {
  font-size: 13px;
  color: var(--k-text-2);
  line-height: 1.55;
}

.lb-tutorial-lista {
  list-style: none;
  display: grid;
  gap: 8px;
}

.lb-tutorial-boton {
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

.lb-tutorial-paso.activo .lb-tutorial-boton {
  border-color: rgba(34, 211, 238, 0.45);
  background: rgba(34, 211, 238, 0.1);
}

.lb-tutorial-indice {
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: rgba(34, 211, 238, 0.15);
  color: #7dd3fc;
  font-size: 12px;
  font-weight: 800;
}

.lb-tutorial-texto {
  margin-top: 6px;
  font-size: 12.5px;
  color: var(--k-text-2);
  line-height: 1.6;
  padding: 0 6px 6px;
}

.lb-tutorial-acciones {
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

@media (prefers-reduced-motion: reduce) {
  .lb-baldosa,
  .lb-robot,
  .lb-instruccion,
  .lb-casillero,
  .lb-boton {
    transition: none;
  }

  .lb-antena-arco {
    animation: none;
  }
}
</style>
