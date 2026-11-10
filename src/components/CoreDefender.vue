<template>
  <div class="defensor" ref="raiz">
    <div class="defensor-hud">
      <span class="hud-item">
        <em class="hud-valor">{{ estado.puntos }}</em>
        puntos
      </span>
      <span class="hud-item">
        <em class="hud-valor">{{ Math.ceil(restante) }}</em>
        s
      </span>
      <span class="hud-item hud-vidas" :aria-label="`Vidas restantes: ${estado.vidas}`">
        <q-icon
          v-for="i in estado.totalVidas"
          :key="i"
          name="favorite"
          size="18px"
          :class="i <= estado.vidas ? 'vida-llena' : 'vida-vacia'"
        />
      </span>
    </div>

    <div class="defensor-escenario">
      <canvas
        ref="lienzo"
        class="defensor-canvas"
        width="640"
        height="480"
        aria-label="Core Defender: protegé el núcleo con el escudo"
        @mousemove="onPuntero"
        @touchmove.prevent="onToque"
        @touchstart="onToque"
      ></canvas>

      <p
        v-if="!enJuego && !estado.terminado"
        class="defensor-aviso"
      >
        Movete el puntero: el escudo te sigue. Sin toques, sin botones.
      </p>

      <div v-if="estado.terminado" class="defensor-cierre">
        <FantasmaKodigo :size="72" :variant="estado.vidas <= 0 ? 'sad' : 'happy'" />
        <p class="defensor-cierre-titulo">
          {{ estado.vidas <= 0 ? 'El núcleo cayó' : '¡Protegiste el núcleo!' }}
        </p>
        <p class="defensor-cierre-detalle">
          {{ estado.puntos }} meteoritos destruidos · {{ estado.impactos }} impactos
        </p>
        <p v-if="guardando" class="defensor-guardando">Guardando tu partida…</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import FantasmaKodigo from './FantasmaKodigo.vue'
import {
  ALTURA_JUEGO,
  ANCHURA_JUEGO,
  crearEstadoJuego,
  dibujarJuego,
  pasoJuego,
  posicionEscudo,
  resultadoFinal,
} from '@/services/coreDefender'

const props = defineProps({
  duracionSeg: {
    type: Number,
    required: true,
  },
  vidas: {
    type: Number,
    required: true,
    default: 3,
  },
  enJuego: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['terminado'])

const raiz = ref(null)
const lienzo = ref(null)
const guardando = ref(false)

const estado = reactive(
  crearEstadoJuego(props.duracionSeg, props.vidas, () => Math.random()),
)

let ctx = null
let rafId = 0
let ultimoPaso = 0
let puntero = { x: ANCHURA_JUEGO / 2, y: 40 }
let restante = ref(props.duracionSeg)
let contadoresLocales = { destruidos: 0, impactos: 0, puntos: 0 }
let finalizadoEnviado = false

const dimensiones = { ancho: ANCHURA_JUEGO, alto: ALTURA_JUEGO }

function onPuntero(evento) {
  const rect = evento.target.getBoundingClientRect()
  puntero.x = ((evento.clientX - rect.left) / rect.width) * dimensiones.ancho
  puntero.y = ((evento.clientY - rect.top) / rect.height) * dimensiones.alto
}

function onToque(evento) {
  const toque = evento.touches?.[0] || evento.changedTouches?.[0]
  if (!toque) return
  const rect = evento.target.getBoundingClientRect()
  puntero.x = ((toque.clientX - rect.left) / rect.width) * dimensiones.ancho
  puntero.y = ((toque.clientY - rect.top) / rect.height) * dimensiones.alto
}

function lazo(tiempo) {
  rafId = requestAnimationFrame(lazo)
  if (!props.enJuego) return
  if (estado.terminado) {
    // La partida ya cerró: notificar una sola vez y frenar.
    if (!finalizadoEnviado) {
      finalizadoEnviado = true
      terminoElJuego()
    }
    return
  }
  if (!ultimoPaso) ultimoPaso = tiempo
  const dt = Math.min((tiempo - ultimoPaso) / 1000, 0.1)
  ultimoPaso = tiempo

  pasoJuego(estado, dt, puntero, dimensiones)
  restante.value = Math.max(0, estado.duracion - estado.tiempo)

  if (estado.terminado) {
    finalizadoEnviado = true
    terminoElJuego()
    return
  }

  const escudo = posicionEscudo(puntero, dimensiones)
  if (ctx) dibujarJuego(ctx, estado, dimensiones, escudo)
}

function terminoElJuego() {
  if (rafId) {
    cancelAnimationFrame(rafId)
    rafId = 0
  }
  guardando.value = true
  const resumen = resultadoFinal(estado, estado.duracion)
  emit('terminado', resumen)
}

onMounted(() => {
  const canvas = lienzo.value
  if (canvas) ctx = canvas.getContext('2d')
  restante.value = props.duracionSeg
  contadoresLocales = { destruidos: 0, impactos: 0, puntos: 0 }
  finalizadoEnviado = false
  ultimoPaso = 0
  rafId = requestAnimationFrame(lazo)
})

onBeforeUnmount(() => {
  if (rafId) cancelAnimationFrame(rafId)
})

watch(
  () => props.enJuego,
  (activo) => {
    if (!activo && rafId) {
      cancelAnimationFrame(rafId)
      rafId = 0
    } else if (activo && !rafId) {
      ultimoPaso = 0
      rafId = requestAnimationFrame(lazo)
    }
  },
)

defineExpose({
  contadores: contadoresLocales,
})
</script>

<style scoped>
.defensor {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.defensor-hud {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.hud-item {
  display: inline-flex;
  align-items: baseline;
  gap: 6px;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.66);
}

.hud-valor {
  font-style: normal;
  font-weight: 700;
  font-family: var(--k-font-brand);
  font-size: 18px;
  color: #fff;
}

.hud-vidas {
  gap: 3px;
}

.vida-llena {
  color: #ff5d73;
}

.vida-vacia {
  color: rgba(255, 255, 255, 0.25);
}

.defensor-escenario {
  position: relative;
}

.defensor-canvas {
  display: block;
  width: 100%;
  max-width: 640px;
  margin: 0 auto;
  aspect-ratio: 4 / 3;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: #0d0512;
  touch-action: none;
}

.defensor-aviso {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 10px;
  text-align: center;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.55);
  pointer-events: none;
}

.defensor-cierre {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  text-align: center;
  background: rgba(13, 5, 18, 0.88);
  border-radius: var(--k-radius-sm);
  color: #fff;
}

.defensor-cierre-titulo {
  font-family: var(--k-font-brand);
  font-size: 20px;
  font-weight: 700;
  margin: 0;
}

.defensor-cierre-detalle {
  margin: 0;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.66);
}

.defensor-guardando {
  margin: 0;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.45);
}
</style>
