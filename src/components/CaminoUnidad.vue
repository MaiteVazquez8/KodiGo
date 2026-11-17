<template>
  <div class="camino">
    <!-- Línea que une los niveles de la unidad, con el ritmo zigzag de los nodos. -->
    <svg
      v-if="nodos.length > 1"
      class="camino-conexiones"
      :viewBox="`0 0 ${ANCHO_SVG} ${altoSvg}`"
      :width="ANCHO_SVG"
      :height="altoSvg"
      preserveAspectRatio="xMidYMid meet"
      aria-hidden="true"
    >
      <path
        v-for="(segmento, i) in segmentos"
        :key="i"
        :d="segmento.d"
        class="camino-segmento"
        :class="segmento.clase"
      />
    </svg>

    <button
      v-for="nodo in nodos"
      :key="nodo.leccion.id"
      type="button"
      class="camino-nodo"
      :class="clasesNodo(nodo)"
      :style="{ transform: `translateX(${desplazamiento(nodo.index)}px)` }"
      :aria-label="etiqueta(nodo)"
      :disabled="nodo.leccion.estado === 'bloqueada'"
      @click="$emit('abrir', nodo.leccion)"
    >
      <span class="camino-anillo" />
      <span class="camino-centro">
        <q-icon
          v-if="nodo.leccion.estado === 'aprobada' || nodo.leccion.estado === 'completada'"
          name="check"
          size="24px"
        />
        <q-icon v-else-if="nodo.leccion.estado === 'bloqueada'" name="lock" size="18px" />
        <span v-else>{{ nodo.leccion.orden }}</span>
      </span>
    </button>

    <div v-if="mensaje" class="camino-mensaje">
      <span class="camino-fantasma" aria-hidden="true">o</span>
      <p>{{ mensaje }}</p>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  // [{ id, titulo, orden, cantidadPreguntas, estado }]
  // estado: disponible / completada / aprobada / bloqueada
  lecciones: {
    type: Array,
    default: () => [],
  },
  // Guia de la mascota debajo del camino (fiel al mock: burbuja con fantasma).
  mensaje: {
    type: String,
    default: '',
  },
})

defineEmits(['abrir'])

const ANCHO_SVG = 240
const RADIO_NODO = 29
const PASO = 88
const CENTRO = ANCHO_SVG / 2

// Zigzag suave: alterna el desplazamiento lateral de cada nodo (mock), con
// amplitud amplia cada 4 nodos para mantener el ritmo irregular del camino.
function desplazamiento(index) {
  const magnitud = index % 4 === 2 ? 42 : 24
  return index % 2 ? magnitud : -magnitud
}

const nodos = computed(() =>
  props.lecciones.map((leccion, index) => ({ leccion, index })),
)

const primerDisponible = computed(() =>
  props.lecciones.findIndex((leccion) => leccion.estado === 'disponible'),
)

const altoSvg = computed(() =>
  PASO * (props.lecciones.length - 1) + RADIO_NODO * 2,
)

function yNodo(index) {
  return RADIO_NODO + index * PASO
}

const segmentos = computed(() =>
  props.lecciones.slice(0, -1).map((_, i) => {
    const x1 = CENTRO + desplazamiento(i)
    const y1 = yNodo(i)
    const x2 = CENTRO + desplazamiento(i + 1)
    const y2 = yNodo(i + 1)
    const curva = PASO * 0.55
    const estadoA = props.lecciones[i].estado
    const estadoB = props.lecciones[i + 1].estado
    const vistoA = ['completada', 'aprobada'].includes(estadoA)
    const vistoB = ['completada', 'aprobada'].includes(estadoB)
    const clase = vistoA && vistoB ? 'is-visto' : vistoA ? 'is-actual' : 'is-pendiente'
    return {
      clase,
      d: `M ${x1} ${y1} C ${x1} ${y1 + curva}, ${x2} ${y2 - curva}, ${x2} ${y2}`,
    }
  }),
)

function clasesNodo(nodo) {
  return {
    'is-visto': ['completada', 'aprobada'].includes(nodo.leccion.estado),
    'is-bloqueada': nodo.leccion.estado === 'bloqueada',
    'is-actual': nodo.index === primerDisponible.value,
  }
}

function etiqueta(nodo) {
  const titulo = nodo.leccion.titulo
  if (nodo.index === primerDisponible.value) {
    return `Clase ${nodo.leccion.orden}, proxima clase: ${titulo}`
  }
  return `Clase ${nodo.leccion.orden}: ${titulo} (${nodo.leccion.estado})`
}
</script>

<style scoped>
.camino {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 30px;
  padding: 40px 0 var(--k-space-2);
  margin-top: var(--k-space-5);
}

/* Línea que conecta los nodos siguiendo el zigzag del camino. */
.camino-conexiones {
  position: absolute;
  top: 40px;
  left: 50%;
  width: 240px;
  transform: translateX(-50%);
  overflow: visible;
  pointer-events: none;
}

.camino-segmento {
  fill: none;
  stroke-width: 5;
  stroke-linecap: round;
  transition: stroke 0.18s ease;
}

.camino-segmento.is-pendiente {
  stroke: rgba(210, 170, 230, 0.14);
  stroke-dasharray: 2 10;
}

.camino-segmento.is-actual {
  stroke: rgba(210, 170, 230, 0.3);
  stroke-dasharray: 6 8;
}

.camino-segmento.is-visto {
  stroke: var(--k-accent);
  filter: drop-shadow(0 0 5px rgba(142, 5, 194, 0.45));
}

.camino-nodo {
  position: relative;
  z-index: 1;
  width: 58px;
  height: 58px;
  padding: 0;
  border: none;
  background: transparent;
  cursor: pointer;
  border-radius: 50%;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}

.camino-nodo:disabled {
  cursor: default;
}

.camino-nodo:active {
  transform: scale(0.94) !important;
}

.camino-centro {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: var(--k-surface-2);
  border: 3px solid var(--k-line);
  color: var(--k-text);
  font-size: 18px;
  font-weight: 800;
}

.camino-anillo {
  position: absolute;
  inset: -6px;
  border-radius: 50%;
  border: 2px solid transparent;
  pointer-events: none;
}

/* Clase aprobada: check dorado anillo fondo cons */
.camino-nodo.is-visto .camino-centro {
  background: var(--k-surface);
  border-color: var(--k-accent);
  color: var(--k-accent);
}

.camino-nodo.is-visto .camino-anillo {
  border-color: rgba(240, 70, 240, 0.28);
}

/* Clase actual: solida con suave halo */
.camino-nodo.is-actual .camino-centro {
  background: var(--k-accent);
  border-color: rgba(240, 70, 240, 0.55);
  color: #fff;
  box-shadow: 0 0 0 6px rgba(240, 70, 240, 0.14);
}

.camino-nodo.is-actual .camino-anillo {
  border-color: rgba(240, 70, 240, 0.5);
}

.camino-nodo.is-bloqueada .camino-centro {
  background: rgba(9, 6, 12, 0.8);
  border-color: rgba(120, 90, 170, 0.28);
  color: var(--k-text-3);
}

/* Mensaje de la mascota al pie del camino, como en el mock */

.camino-mensaje {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-top: var(--k-space-4);
  padding: 10px 14px;
  max-width: 280px;
  border-radius: 16px 16px 16px 4px;
  background: rgba(142, 5, 194, 0.12);
  border: 1px solid rgba(240, 70, 240, 0.3);
}

.camino-fantasma {
  font-size: 17px;
  color: var(--k-accent);
}

.camino-mensaje p {
  font-size: 12.5px;
  font-weight: 600;
  line-height: 1.45;
  color: var(--k-text-2);
}

@media (prefers-reduced-motion: reduce) {
  .camino-nodo,
  .camino-nodo:active {
    transition: none;
  }
}
</style>
