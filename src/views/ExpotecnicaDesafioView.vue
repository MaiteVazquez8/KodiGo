<template>
  <div class="k-screen">
    <EncabezadoApp :titulo="tituloFase" :back="null" :lado="ladoDerecho" />

    <main class="k-container desafio">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar el desafío"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <!-- El orden importa: los cierres por servidor se evalúan antes de las fases. -->
      <EstadoPantalla
        v-else-if="estado === 'sin-evento'"
        variant="bored"
        titulo="No hay desafío activo"
        mensaje="El próximo Desafío ExpoTécnica todavía no arrancó. Cuando el evento se active, vas a poder entrar desde acá o desde la tarjeta del inicio."
        accion-label="Volver al inicio"
        @accion="volverSinAbandono"
      />

      <EstadoPantalla
        v-else-if="estado === 'vencida'"
        variant="bored"
        eyebrow="Se acabó el tiempo"
        titulo="Tu partida quedó vencida"
        mensaje="El cronómetro corre en el servidor y se venció antes de completar el cuestionario. No hay resultado oficial de un intento incompleto: al iniciar de nuevo vas a partir de cero."
        accion-label="Volver al inicio"
        @accion="volverSinAbandono"
      />

      <EstadoPantalla
        v-else-if="estado === 'abandonada'"
        variant="bored"
        eyebrow="Partida abandonada"
        titulo="El intento quedó abandonado"
        mensaje="Abandonaste la partida y no queda registrado ningún resultado oficial. Si querés, podés arrancar otra vez desde el desafío."
        accion-label="Volver al inicio"
        @accion="volverSinAbandono"
      />

      <!-- Fase 1: alias con validacion de disponibilidad en vivo. -->
      <template v-else-if="fase === 'alias'">
        <section class="alias-card">
          <p class="k-eyebrow">Tu nombre en el ranking</p>
          <p class="alias-ayuda">
            Con este nombre vas a aparecer en el ranking del evento. Un alias solo lo puede usar
            una persona por evento, y la unicidad la cobra el servidor, nunca tu navegador.
          </p>

          <input
            v-model="alias"
            type="text"
            class="campo-alias k-mono"
            maxlength="20"
            placeholder="Tu nombre en la ExpoTécnica"
            autocomplete="off"
            @input="revisarAliasLocal"
          />

          <p class="alias-obligatorio">El nombre es obligatorio: sin él no se puede entrar al cuestionario.</p>

          <p v-if="verificacionAlias && !verificacionAlias.valido" class="alias-estado is-error">
            {{ verificacionAlias.mensaje }}
          </p>
          <p v-else-if="verificacionAlias?.valido && verificacionAlias.disponible" class="alias-estado is-ok">
            <q-icon name="check_circle" size="15px" />
            Nombre disponible en este evento
          </p>
          <p v-else-if="verificacionAlias?.valido" class="alias-estado is-error">
            {{ verificacionAlias.mensaje }}
          </p>
          <p v-else class="alias-estado"></p>

          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            :disabled="!aliasListoLocal || enviando"
            @click="iniciarCuestionario"
          >
            <q-icon name="rocket_launch" size="19px" />
            Iniciar cuestionario
          </button>
        </section>
      </template>

      <!-- Fase 2: cuestionario, una pregunta por pantalla. -->
      <template v-else-if="fase === 'cuestionario' && preguntaActual">
        <section class="quiz-cabecera">
          <p class="quiz-contador">
            Pregunta {{ indiceActual + 1 }} de {{ basePartida.config.cantidadPreguntas }}
          </p>
          <div class="k-progress quiz-progreso">
            <i :style="{ width: progresoPct + '%' }"></i>
          </div>
        </section>

        <h2 class="quiz-enunciado">{{ preguntaActual.enunciado }}</h2>

        <div class="options quiz-opciones">
          <button
            v-for="(opcion, i) in preguntaActual.opciones"
            :key="opcion.id"
            type="button"
            class="option"
            :class="{ 'is-seleccionada': seleccionada?.id === opcion.id }"
            :disabled="enviandoRespuesta"
            @click="elegirOpcion(opcion)"
          >
            <span class="option-letter k-mono">{{ letras[i] }}</span>
            <code class="option-text k-mono">{{ opcion.texto }}</code>
          </button>
        </div>

        <p class="quiz-nota">
          El servidor marca la respuesta en cuanto apretás y no se puede volver atrás. Las
          respuestas correctas se muestran recién al final del intento, sin excepciones.
        </p>
      </template>

      <!-- Fase 3: parcial al completar el cuestionario. -->
      <template v-else-if="fase === 'parcial'">
        <section class="parcial-card">
          <FantasmaKodigo :size="84" variant="happy" />
          <p class="k-eyebrow">Cuestionario completo</p>
          <h2 class="parcial-titulo">Terminaste el cuestionario</h2>
          <div class="parcial-datos">
            <div class="parcial-dato">
              <span class="parcial-valor">{{ basePartida.partida.correctas }}</span>
              <span class="parcial-etiqueta">correctas</span>
            </div>
            <div class="parcial-dato">
              <span class="parcial-valor">{{ basePartida.partida.incorrectas }}</span>
              <span class="parcial-etiqueta">incorrectas</span>
            </div>
            <div class="parcial-dato">
              <span class="parcial-valor">{{ basePartida.partida.puntajeCuestionario }}</span>
              <span class="parcial-etiqueta">puntos</span>
            </div>
            <div class="parcial-dato">
              <span class="parcial-valor">{{ tiempoRespuestaTexto }}</span>
              <span class="parcial-etiqueta">tiempo</span>
            </div>
          </div>

          <p class="parcial-juego">
            Para completar tu resultado te espera <strong>Core Defender</strong>:
            {{ basePartida.config.duracionJuegoSeg }} segundos defendiendo el núcleo con
            {{ basePartida.config.vidasJuego }} {{ basePartida.config.vidasJuego === 1 ? 'vida' : 'vidas' }}
            en juego.
          </p>

          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            :disabled="enviando"
            @click="irIntroJuego"
          >
            <q-icon name="shield" size="19px" />
            Ver cómo se juega
          </button>
        </section>
      </template>

      <!-- Fase 4: intro de Core Defender. -->
      <template v-else-if="fase === 'core-intro'">
        <section class="core-intro">
          <FantasmaKodigo :size="92" variant="normal" />
          <h2 class="core-titulo">Core Defender</h2>
          <ol class="core-pasos">
            <li>El escudo (tu fantasma) sigue el puntero: sin clicks y sin botones.</li>
            <li>Los meteoritos llegan de todos lados hacia el núcleo central.</li>
            <li>Con el escudo los bloqueás: cada bloqueado suma un punto.</li>
            <li>Si uno golpea el núcleo perdés una vida: con vidas en cero, la partida termina.</li>
            <li>La velocidad sube cada 5 segundos y la cantidad cada 7: más meteoritos, más rápidos.</li>
            <li>
              Aguantá {{ datosJuegoConfig.duracionSeg }} segundos y tu puntaje oficial queda en el
              ranking del evento.
            </li>
          </ol>
          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            :disabled="enviando"
            @click="iniciarNucleo"
          >
            <q-icon name="play_arrow" size="19px" />
            Iniciar juego
          </button>
        </section>
      </template>

      <!-- Fase 5: juego. -->
      <template v-else-if="fase === 'juego'">
        <CoreDefender
          :duracion-seg="datosJuego.duracionSeg"
          :vidas="datosJuego.vidas"
          :en-juego="true"
          @terminado="onJuegoTerminado"
        />
        <p v-if="errorJuego" class="juego-error">{{ errorJuego }}</p>
      </template>

      <!-- Fase 6: final con resultado oficial y soluciones autorizadas. -->
      <template v-else-if="fase === 'final' && resultado">
        <section class="final-cabecera">
          <FantasmaKodigo :size="88" variant="happy" />
          <p class="k-eyebrow">Resultado oficial</p>
          <h2 class="final-alias">{{ resultado.partida.alias }}</h2>
          <p v-if="resultado.puesto" class="final-puesto">
            Puesto {{ resultado.puesto }} en el ranking del evento
          </p>
        </section>

        <section class="final-datos">
          <div class="final-dato">
            <span class="final-valor">{{ resultado.partida.puntajeTotal }}</span>
            <span class="final-etiqueta">total</span>
          </div>
          <div class="final-dato">
            <span class="final-valor">{{ resultado.partida.puntajeCuestionario }}</span>
            <span class="final-etiqueta">cuestionario</span>
          </div>
          <div class="final-dato">
            <span class="final-valor">{{ resultado.partida.puntajeJuego }}</span>
            <span class="final-etiqueta">juego</span>
          </div>
        </section>

        <section v-if="soluciones.preguntas.length" class="final-soluciones">
          <p class="k-eyebrow">Revisión del cuestionario</p>
          <div
            v-for="item in soluciones.preguntas"
            :key="item.orden"
            class="solucion"
            :class="item.acerto ? 'is-ok' : 'is-error'"
          >
            <div class="solucion-cabecera">
              <q-icon :name="item.acerto ? 'check_circle' : 'cancel'" size="17px" />
              <span class="solucion-enunciado">{{ item.enunciado }}</span>
            </div>
            <p v-if="item.elegida" class="solucion-linea">
              Elegiste: <strong>{{ item.elegida.texto }}</strong>
              <template v-if="!item.acerto && item.correcta">
                · Correcta: <strong>{{ item.correcta.texto }}</strong>
              </template>
            </p>
            <p v-else class="solucion-linea">
              Sin respuesta
              <template v-if="item.correcta">
                · Correcta: <strong>{{ item.correcta.texto }}</strong>
              </template>
            </p>
            <p v-if="item.explicacion" class="solucion-explicacion">{{ item.explicacion }}</p>
          </div>
        </section>

        <div class="final-acciones">
          <router-link class="k-btn k-btn--primary k-btn--block k-btn--lg" to="/expotecnica/ranking">
            <q-icon name="leaderboard" size="19px" />
            Ver ranking
          </router-link>
          <button type="button" class="k-btn k-btn--ghost k-btn--block" @click="volverInicio">
            <q-icon name="home" size="18px" />
            Volver al inicio
          </button>
        </div>
      </template>

      <!-- Modal de abandono: cuidado antes de salir sin terminar. -->
      <div v-if="modalAbandono" class="modal-abandono" role="dialog" aria-modal="true">
        <div class="modal-abandono-caja">
          <p class="modal-titulo">¿Seguro que querés terminar tu intento?</p>
          <p class="modal-detalle">{{ resumenAbandono }}</p>
          <p class="modal-aviso">
            Si terminás ahora, la partida queda abandonada y no se publica ningún puntaje oficial
            en el ranking.
          </p>
          <div class="modal-acciones">
            <button type="button" class="k-btn k-btn--ghost" @click="continuarIntento">Continuar</button>
            <button type="button" class="k-btn k-btn--primary" @click="terminarIntento">Terminar intento</button>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { onBeforeRouteLeave, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import CoreDefender from '@/components/CoreDefender.vue'
import {
  abandonarPartida,
  estadoPartida,
  finalizarJuego,
  iniciarJuego,
  iniciarPartida,
  obtenerEventoActivo,
  obtenerSoluciones,
  responder,
  resultadoPropio,
  verificarAlias,
} from '@/services/expotecnica'

const CLAVE_PARTIDA = 'kodigo.expotec.partida'

const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const fase = ref('alias')
const eventoId = ref(null)
const alias = ref('')
const verificacionAlias = ref(null)

const basePartida = ref(null)
const indiceActual = ref(0)
const seleccionada = ref(null)
const restante = ref(null)
const resultado = ref(null)
const soluciones = ref({ preguntas: [] })
const enviando = ref(false)
const enviandoRespuesta = ref(false)
const errorJuego = ref('')
const datosJuego = ref({ sesionId: null, duracionSeg: 180, vidas: 3 })
const modalAbandono = ref(false)

let destinoPendiente = null
let timerId = 0
let timerAliasId = 0

const letras = ['A', 'B', 'C', 'D', 'E']

const preguntaActual = computed(() => basePartida.value?.preguntas?.[indiceActual.value] ?? null)
const progresoPct = computed(() => {
  const total = basePartida.value?.config?.cantidadPreguntas || 1
  const respondidas = basePartida.value?.partida?.respondidas ?? 0
  return Math.min(100, Math.round((respondidas / total) * 100))
})

const tituloFase = computed(() => {
  if (fase.value === 'cuestionario') return 'Cuestionario'
  if (fase.value === 'core-intro' || fase.value === 'juego') return 'Core Defender'
  if (fase.value === 'final') return 'Resultado'
  if (fase.value === 'parcial') return 'Cuestionario completo'
  return 'Desafío ExpoTécnica'
})

const enFaseTemporal = computed(
  () => fase.value === 'cuestionario' && typeof restante.value === 'number',
)

// EncabezadoApp no tiene slot: el cronometro pasa como prop de texto.
const ladoDerecho = computed(() => {
  if (!enFaseTemporal.value) return ''
  return restante.value <= 30 ? `¡${tiempoRestanteTexto.value}!` : tiempoRestanteTexto.value
})

const tiempoRestanteTexto = computed(() => {
  const s = restante.value ?? 0
  const mm = Math.floor(s / 60)
  const ss = Math.floor(s % 60)
  return `${mm}:${String(ss).padStart(2, '0')}`
})

const tiempoRespuestaTexto = computed(() => {
  const t = basePartida.value?.partida?.tiempoCuestionarioSeg
  if (t == null) return '—'
  const min = Math.floor(t / 60)
  const sec = Math.round(t % 60)
  return `${min}:${String(sec).padStart(2, '0')}`
})

const aliasListoLocal = computed(() => revisionAlias(alias.value).valido)

/** Espejo local de la validacion del SQL: feedback inmediato mientras se escribe. */
function revisionAlias(texto) {
  const v = String(texto ?? '').trim().toLowerCase().replace(/\s+/g, ' ')
  if (!v) return { valido: false, mensaje: 'El nombre es obligatorio.' }
  if (v.length < 3) return { valido: false, mensaje: 'El nombre debe tener al menos 3 caracteres.' }
  if (v.length > 20) return { valido: false, mensaje: 'El nombre debe tener hasta 20 caracteres.' }
  if (!/^[a-z0-9áéíóúüñ. _-]+$/.test(v)) {
    return {
      valido: false,
      mensaje: 'Solo letras, números, espacios, puntos, guiones bajos y guiones.',
    }
  }
  if (/^[ .-]/.test(v) || /[ .-]$/.test(v)) {
    return {
      valido: false,
      mensaje: 'El nombre no puede empezar ni terminar con un símbolo o espacio.',
    }
  }
  return { valido: true, mensaje: '' }
}

const resumenAbandono = computed(() => {
  if (!basePartida.value) return 'Vas a abandonar el desafío.'
  if (fase.value === 'cuestionario') {
    return `Llevás ${basePartida.value.partida.respondidas} de ${basePartida.value.config.cantidadPreguntas} respuestas registradas.`
  }
  if (fase.value === 'juego') {
    return 'Estás en plena partida de Core Defender: el escudo, el puntaje y el cuota lo controla el servidor.'
  }
  return 'Vas a abandonar el desafío.'
})

const datosJuegoConfig = computed(() => ({
  duracionSeg: basePartida.value?.config?.duracionJuegoSeg ?? 180,
  vidas: basePartida.value?.config?.vidasJuego ?? 3,
}))

// ---------------------------------------------------------------------------
// Persistencia local del intento: reanudar tras recarga o reconexion
// ---------------------------------------------------------------------------

function limpiarPartida() {
  try {
    localStorage.removeItem(CLAVE_PARTIDA)
  } catch {
    // sin almacenamiento el servidor es quien recuerda
  }
}

function guardarPartida(partidaId, aliasGuardado) {
  try {
    localStorage.setItem(CLAVE_PARTIDA, JSON.stringify({ partidaId, alias: aliasGuardado }))
  } catch {
    // sin almacenamiento el servidor es quien recuerda
  }
}

function leerPartida() {
  try {
    return JSON.parse(localStorage.getItem(CLAVE_PARTIDA) ?? 'null')
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Carga e inicio del flujo
// ---------------------------------------------------------------------------

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    const activo = await obtenerEventoActivo()
    if (!activo) {
      estado.value = 'sin-evento'
      return
    }
    eventoId.value = activo.id

    // Reanuda una partida propia si existe: recargar la pagina no crea otra.
    const guardada = leerPartida()
    if (guardada?.partidaId) {
      const reanudo = await interpretarEstado(guardada.partidaId)
      if (reanudo) return
    }

    fase.value = 'alias'
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

async function interpretarEstado(partidaId) {
  const data = await estadoPartida(partidaId)
  basePartida.value = data

  const estadoActual = data.partida.estado

  // El vencimiento es del servidor: restante = vencimiento_at - servidor_at,
  // ambos relojes de la base de datos. Recargar no acorta ni alarga nada.
  if (estadoActual === 'en_cuestionario' || estadoActual === 'creada') {
    fase.value = 'cuestionario'
    if (data.partida.vencimientoAt && data.servidorAt) {
      restante.value = Math.max(
        0,
        (new Date(data.partida.vencimientoAt) - new Date(data.servidorAt)) / 1000,
      )
      arrancarReservaTimer()
    }
    indiceActual.value = primerPendiente(data)
    estado.value = 'listo'
    return true
  }

  if (estadoActual === 'cuestionario_completado') {
    fase.value = 'parcial'
    estado.value = 'listo'
    return true
  }

  if (estadoActual === 'en_juego') {
    fase.value = 'core-intro'
    datosJuego.value = {
      sesionId: null,
      duracionSeg: data.config.duracionJuegoSeg,
      vidas: data.config.vidasJuego,
    }
    estado.value = 'listo'
    return true
  }

  if (estadoActual === 'vencida') {
    limpiarPartida()
    estado.value = 'vencida'
    return true
  }
  if (estadoActual === 'abandonada') {
    limpiarPartida()
    estado.value = 'abandonada'
    return true
  }
  if (estadoActual === 'finalizada') {
    await mostrarFinal(data.partida.id)
    return true
  }
  return false
}

/** La restauración del relé del servidor: solo el estado en cuestionario resta. */
function arrancarReservaTimer() {
  if (timerId) clearInterval(timerId)
  timerId = setInterval(() => {
    if (fase.value !== 'cuestionario') return
    if (typeof restante.value !== 'number') return
    restante.value = Math.max(0, restante.value - 1)
    if (restante.value <= 0) {
      void revisarVencimiento()
    }
  }, 1000)
}

/** El servidor cierra la partida; el cliente solo consulta el veredito. */
async function revisarVencimiento() {
  if (timerId) clearInterval(timerId)
  timerId = 0
  try {
    if (!basePartida.value) return
    const data = await estadoPartida(basePartida.value.partida.id)
    if (data.partida.estado === 'vencida') {
      limpiarPartida()
      estado.value = 'vencida'
      return
    }
    basePartida.value = data
    indiceActual.value = primerPendiente(data)
  } catch {
    todoErrorSinSalida()
  }
}

function primerPendiente(data) {
  const idx = data.preguntas.findIndex((p) => !data.respuestas[p.asignadaId])
  return idx >= 0 ? idx : 0
}

// ---------------------------------------------------------------------------
// Alias -> servidor hace el resto innit.
// ---------------------------------------------------------------------------

function revisarAliasLocal() {
  const revision = revisionAlias(alias.value)
  if (!revision.valido) {
    verificacionAlias.value = null
    return
  }

  if (timerAliasId) clearTimeout(timerAliasId)
  timerAliasId = setTimeout(async () => {
    if (!eventoId.value) return
    try {
      const data = await verificarAlias(eventoId.value, alias.value)
      verificacionAlias.value = {
        valido: Boolean(data.disponible),
        disponible: Boolean(data.disponible),
        mensaje: data.disponible ? '' : data.mensaje || 'Ese nombre no está disponible.',
      }
    } catch {
      verificacionAlias.value = null
    }
  }, 400)
}

async function iniciarCuestionario() {
  const revision = revisionAlias(alias.value)
  if (!revision.valido) {
    verificacionAlias.value = { valido: false, mensaje: revision.mensaje, disponible: false }
    return
  }

  enviando.value = true
  try {
    const disponibilidad = await verificarAlias(eventoId.value, alias.value)
    if (!disponibilidad.disponible) {
      verificacionAlias.value = {
        valido: false,
        mensaje: disponibilidad.mensaje || 'Ese nombre no está disponible.',
        disponible: false,
      }
      return
    }

    const partidaId = await iniciarPartida(eventoId.value, alias.value)
    guardarPartida(partidaId, alias.value)
    const reanudo = await interpretarEstado(partidaId)
    if (!reanudo) {
      throw new Error('El servidor no pudo abrir la partida. Intentá de nuevo.')
    }
  } catch (error) {
    verificacionAlias.value = { valido: false, mensaje: error.message, disponible: false }
  } finally {
    enviando.value = false
  }
}

// ---------------------------------------------------------------------------
// Cuestionario
// ---------------------------------------------------------------------------

async function elegirOpcion(opcion) {
  if (enviandoRespuesta.value || !preguntaActual.value) return
  seleccionada.value = opcion
  enviandoRespuesta.value = true

  try {
    const res = await responder(
      basePartida.value.partida.id,
      preguntaActual.value.asignadaId,
      opcion.id,
    )
    basePartida.value.partida.respondidas = res.respondidas
    basePartida.value.respuestas[preguntaActual.value.asignadaId] = {
      opcionId: opcion.id,
      respondidoAt: res.respondidoAt,
    }

    if (res.pendientes === 0 || res.completado) {
      const data = await estadoPartida(basePartida.value.partida.id)
      await interpretarEstado(basePartida.value.partida.id)
      void data
      return
    }

    indiceActual.value = primerPendiente(basePartida.value)
    seleccionada.value = null
  } catch (error) {
    if (String(error.message).includes('Se acabó el tiempo')) {
      await revisarVencimiento()
      return
    }
    mensajeError.value = error.message
    estado.value = 'error'
  } finally {
    enviandoRespuesta.value = false
  }
}

// ---------------------------------------------------------------------------
// Core Defender
// ---------------------------------------------------------------------------

function irIntroJuego() {
  fase.value = 'core-intro'
}

async function iniciarNucleo() {
  enviando.value = true
  errorJuego.value = ''
  try {
    const sesion = await iniciarJuego(basePartida.value.partida.id)
    datosJuego.value = {
      sesionId: sesion.sesionId,
      duracionSeg: sesion.duracionMaxSeg,
      vidas: sesion.vidas,
    }
    fase.value = 'juego'
  } catch (error) {
    errorJuego.value = error.message
  } finally {
    enviando.value = false
  }
}

async function onJuegoTerminado(resumen) {
  enviando.value = true
  errorJuego.value = ''
  try {
    // El servidor valida la duracion contra la sesion REAL, aplica el tope de
    // meteoritos (duracion * 2.5 + 8), acota los impactos a las vidas y, con
    // la partida oficialmente finalizada, publica el resultado.
    await finalizarJuego(datosJuego.value.sesionId, resumen, resumen.checkpoints ?? null)
    await mostrarFinal(basePartida.value.partida.id)
  } catch (error) {
    // Un rechazo de validacion no debloquea el jugador: se muestra y puede
    // reintentar la limpieza con el servidor.
    errorJuego.value = error.message
    try {
      const data = await estadoPartida(basePartida.value.partida.id)
      if (data.partida.estado === 'finalizada') {
        await mostrarFinal(data.partida.id)
      }
    } catch {
      // la partida sigue abierta en el servidor; se puede reintentar
    }
  } finally {
    enviando.value = false
  }
}

async function mostrarFinal(partidaId) {
  const data = await resultadoPropio(partidaId)
  resultado.value = data

  // El servidor las autoriza solo si la partida esta FINALIZADA.
  try {
    soluciones.value = await obtenerSoluciones(partidaId)
  } catch {
    soluciones.value = { preguntas: [] }
  }

  // El alias queda loco en el dispositivo para que el ranking publique (vos),
  // aunque la partida ya no este abierta.
  try {
    localStorage.setItem('kodigo.expotec.ultimo-alias', JSON.stringify(data.partida.alias))
  } catch {
    // sin almacenamiento simplemente no se destaca en el ranking
  }

  limpiarPartida()
  fase.value = 'final'
  estado.value = 'listo'
}

// ---------------------------------------------------------------------------
// Navegacion segura
// ---------------------------------------------------------------------------

onBeforeRouteLeave(async (destino) => {
  if (fase.value === 'final' || estado.value !== 'listo') return true

  const partidaViva =
    basePartida.value &&
    (fase.value === 'cuestionario' || fase.value === 'parcial' || fase.value === 'juego')
  if (!partidaViva) return true

  destinoPendiente = destino
  modalAbandono.value = true
  return false
})

function continuarIntento() {
  modalAbandono.value = false
  destinoPendiente = null
}

async function terminarIntento() {
  modalAbandono.value = false
  enviando.value = true
  try {
    await abandonarPartida(basePartida.value.partida.id)
  } catch {
    // Si el servidor ya la cerro, el intento igual queda abandonado.
  } finally {
    enviando.value = false
  }
  basePartida.value = null
  limpiarPartida()
  estado.value = 'abandonada'
}

function volverSinAbandono() {
  basePartida.value = null
  router.push('/expotecnica')
}

function volverInicio() {
  basePartida.value = null
  router.push('/learn')
}

function todoErrorSinSalida() {
  mensajeError.value = 'No pudimos reanudar el desafío. Volvé a intentar desde la presentación.'
}

const onBeforeUnload = (event) => {
  if (
    basePartida.value &&
    (fase.value === 'cuestionario' || fase.value === 'juego' || fase.value === 'parcial')
  ) {
    event.preventDefault()
    event.returnValue = ''
  }
}

onMounted(() => {
  window.addEventListener('beforeunload', onBeforeUnload)
  void cargar()
})

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', onBeforeUnload)
  if (timerId) clearInterval(timerId)
  if (timerAliasId) clearTimeout(timerAliasId)
})
</script>

<style scoped>
.desafio {
  display: flex;
  flex-direction: column;
  gap: var(--k-space-5);
  padding-bottom: var(--k-space-7);
}

/* Espejo de las opciones de actividad: las clases .options/.option* viven
   scoped en EjecutorActividad.vue y no aplican aca, se replican tal cual con
   is-selected renombrada a is-seleccionada. Durante el cuestionario nunca se
   marcan correctas/incorrectas: las soluciones llegan solo al final. */
.quiz-opciones {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.quiz-opciones .option {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 100%;
  padding: 14px 16px;
  border-radius: 16px;
  border: 2px solid var(--k-line);
  background: linear-gradient(180deg, rgba(24, 9, 31, 0.96), rgba(12, 6, 17, 1));
  color: var(--k-text);
  cursor: pointer;
  text-align: left;
  transition:
    border-color 0.12s ease,
    background 0.12s ease,
    transform 0.08s ease;
  -webkit-tap-highlight-color: transparent;
}

.quiz-opciones .option:disabled {
  cursor: default;
}

.quiz-opciones .option-letter {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  flex-shrink: 0;
  border-radius: 9px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  font-size: 13px;
  font-weight: 600;
  color: var(--k-text-2);
}

.quiz-opciones .option-text {
  font-size: 13px;
  color: var(--k-text);
  white-space: pre-wrap;
  word-break: break-word;
}

.quiz-opciones .option.is-seleccionada {
  border-color: var(--k-accent);
  background: var(--k-accent-soft);
}

.quiz-opciones .option.is-seleccionada .option-letter {
  border-color: var(--k-accent);
  color: var(--k-accent);
}

.alias-card,
.parcial-card,
.core-intro {
  display: flex;
  flex-direction: column;
  gap: var(--k-space-4);
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius);
  padding: var(--k-space-6) var(--k-space-5);
}

.alias-ayuda {
  color: var(--k-text-2);
  font-size: 14px;
  line-height: 1.6;
  margin: 0;
}

.alias-obligatorio {
  font-size: 12.5px;
  color: var(--k-text-3);
  margin: -8px 0 0;
}

.campo-alias {
  padding: 14px 16px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 15px;
  outline: none;
}

.campo-alias:focus {
  border-color: var(--k-accent);
}

.alias-estado {
  margin: 0;
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 6px;
  min-height: 18px;
}

.alias-estado.is-ok {
  color: var(--k-success);
}

.alias-estado.is-error {
  color: var(--k-error);
}

.quiz-cabecera {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.quiz-contador {
  color: var(--k-text-2);
  font-size: 13px;
  margin: 0;
}

.quiz-enunciado {
  font-size: 20px;
  line-height: 1.4;
  margin: 0;
  color: var(--k-text);
}

.quiz-nota {
  color: var(--k-text-3);
  font-size: 12.5px;
  margin: 0;
}

.parcial-titulo {
  margin: 0;
  font-size: 22px;
}

.parcial-datos {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
}

.parcial-dato {
  background: var(--k-surface-2);
  border-radius: var(--k-radius-sm);
  padding: 12px 8px;
  text-align: center;
  display: flex;
  flex-direction: column;
}

.parcial-valor {
  font-family: var(--k-font-brand);
  font-weight: 700;
  font-size: 20px;
}

.parcial-etiqueta {
  font-size: 11px;
  color: var(--k-text-3);
}

.parcial-juego {
  font-size: 14px;
  color: var(--k-text-2);
  line-height: 1.6;
  margin: 0;
}

.core-titulo {
  margin: 0;
  font-size: 26px;
  font-family: var(--k-font-brand);
}

.core-pasos {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-left: 20px;
  color: var(--k-text-2);
  font-size: 14px;
  line-height: 1.55;
}

.juego-error {
  color: var(--k-error);
  font-size: 13px;
  margin: 0;
}

.final-cabecera {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 6px;
}

.final-alias {
  margin: 0;
  font-size: 24px;
  font-family: var(--k-font-brand);
}

.final-puesto {
  margin: 0;
  color: var(--k-accent);
  font-weight: 700;
  font-size: 14px;
}

.final-datos {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

.final-dato {
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 14px 8px;
  display: flex;
  flex-direction: column;
  text-align: center;
}

.final-valor {
  font-family: var(--k-font-brand);
  font-weight: 700;
  font-size: 22px;
}

.final-etiqueta {
  font-size: 11px;
  color: var(--k-text-3);
}

.final-soluciones {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.solucion {
  border: 1px solid var(--k-line);
  border-left: 3px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 12px 14px;
}

.solucion.is-ok .solucion-cabecera {
  color: var(--k-success);
}

.solucion.is-error .solucion-cabecera {
  color: var(--k-error);
}

.solucion-cabecera {
  display: flex;
  gap: 8px;
  align-items: flex-start;
  margin-bottom: 6px;
}

.solucion-enunciado {
  font-size: 14px;
  font-weight: 600;
  color: var(--k-text);
}

.solucion-linea,
.solucion-explicacion {
  font-size: 13px;
  color: var(--k-text-2);
  margin: 4px 0 0;
  line-height: 1.55;
}

.final-acciones {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.modal-abandono {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.75);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 60;
  padding: 20px;
}

.modal-abandono-caja {
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius);
  max-width: 400px;
  width: 100%;
  padding: var(--k-space-6) var(--k-space-5);
  display: flex;
  flex-direction: column;
  gap: var(--k-space-4);
}

.modal-titulo {
  font-size: 18px;
  font-weight: 700;
  font-family: var(--k-font-brand);
  margin: 0;
}

.modal-detalle {
  font-size: 14px;
  color: var(--k-text-2);
  margin: 0;
}

.modal-aviso {
  font-size: 13px;
  color: var(--k-text-3);
  margin: 0;
}

.modal-acciones {
  display: flex;
  gap: 10px;
}

.modal-acciones .k-btn {
  flex: 1;
}
</style>
