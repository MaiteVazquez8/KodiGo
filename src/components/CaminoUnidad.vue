<template>
  <div class="camino">
    <!-- Hero de unidad: número, nombre, descripción y progreso. -->
    <section class="camino-hero" aria-labelledby="unidad-titulo">
      <div class="camino-hero-top">
        <p class="camino-hero-eyebrow">Unidad {{ unidad.orden ?? props.orden }}</p>
        <span v-if="unidad.estado === 'completada'" class="camino-hero-badge">Completada</span>
        <span v-else-if="unidad.estado === 'bloqueada'" class="camino-hero-badge is-bloqueada">Bloqueada</span>
        <span v-else class="camino-hero-badge is-actual">En curso</span>
      </div>
      <h2 id="unidad-titulo" class="camino-hero-titulo">{{ unidad.nombre ?? 'Unidad' }}</h2>
      <p v-if="unidad.descripcion" class="camino-hero-desc">{{ unidad.descripcion }}</p>
      <div class="camino-hero-progreso" role="progressbar" :aria-valuenow="progreso" aria-valuemin="0" aria-valuemax="100">
        <div class="k-progress">
          <i :style="{ width: progreso + '%' }"></i>
        </div>
        <p class="camino-hero-contador">
          {{ aprobadas }} de {{ lecciones.length }} lecciones aprobadas · {{ progreso }}%
        </p>
      </div>
    </section>

    <p class="camino-guia">
      {{ mensajeGuida }}
    </p>

    <template v-for="(nodo, index) in nodos" :key="nodo.leccion.id">
      <button
        type="button"
        class="camino-nodo"
        :class="clasesNodo(nodo)"
        :style="{ '--dx': desplazamiento(index) + 'px' }"
        :aria-label="etiqueta(nodo)"
        :disabled="nodo.leccion.estado === 'bloqueada'"
        @click="$emit('abrir', nodo.leccion)"
      >
        <span class="camino-anillo" aria-hidden="true" />
        <span class="camino-centro">
          <q-icon
            v-if="nodo.leccion.estado === 'aprobada' || nodo.leccion.estado === 'completada'"
            name="check"
            size="22px"
          />
          <q-icon v-else-if="nodo.leccion.estado === 'bloqueada'" name="lock" size="17px" />
          <span v-else>{{ nodo.leccion.orden }}</span>
        </span>
        <span class="camino-numero" aria-hidden="true">{{ nodo.leccion.orden }}</span>
        <span v-if="nodo.index === primerDisponible" class="camino-nombre-nodo">{{ nombreActual }}</span>
      </button>
      <svg
        v-if="index < nodos.length - 1"
        class="camino-conexiones"
        viewBox="0 0 240 34"
        width="240"
        height="34"
        aria-hidden="true"
      >
        <path
          :d="segmentoPath(index)"
          class="camino-segmento"
          :class="segmentoClase(index)"
        />
      </svg>
    </template>
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
  lecciones: {
    type: Array,
    default: () => [],
  },
  // Unidad origen para el hero (número, nombre, descripción, estado y %).
  unidad: {
    type: Object,
    default: () => ({}),
  },
  orden: {
    type: Number,
    default: 1,
  },
  mensaje: {
    type: String,
    default: '',
  },
})

defineEmits(['abrir'])

const ANCHO_SVG = 240
const CENTRO_SVG = ANCHO_SVG / 2

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

const aprobadas = computed(
  () => props.lecciones.filter((l) => ['completada', 'aprobada'].includes(l.estado)).length,
)

const progreso = computed(() =>
  props.lecciones.length ? Math.round((aprobadas.value / props.lecciones.length) * 100) : 0,
)

const nombreActual = computed(() => {
  const l = props.lecciones[primerDisponible.value] ?? props.lecciones[props.lecciones.length - 1]
  return l?.titulo ?? ''
})

const mensajeGuida = computed(() => {
  if (props.unidad?.estado === 'bloqueada') return 'El camino está en pausa: completá la unidad anterior para seguir avanzando.'
  if (aprobadas.value === props.lecciones.length && props.lecciones.length) {
    return 'Terminaste el camino de esta unidad: ¡elegí una clase para repasarla cuando quieras!'
  }
  return 'Seguí el camino: la próxima clase es la tuya.'
})

const segmentos = computed(() =>
  props.lecciones.slice(0, -1).map((_, i) => {
    const vistoA = ['completada', 'aprobada'].includes(props.lecciones[i].estado)
    const vistoB = ['completada', 'aprobada'].includes(props.lecciones[i + 1].estado)
    const actualB = props.lecciones[i + 1].estado === 'disponible'
    const clase = vistoA && vistoB ? 'is-visto' : vistoA && actualB ? 'is-actual' : vistoA ? 'is-actual' : 'is-pendiente'
    const x1 = CENTRO_SVG + desplazamiento(i)
    const x2 = CENTRO_SVG + desplazamiento(i + 1)
    const curva = 17
    return {
      clase,
      d: `M ${x1} 0 C ${x1} ${curva}, ${x2} ${34 - curva}, ${x2} 34`,
    }
  }),
)

function segmentoPath(index) {
  return segmentos.value[index]?.d ?? ''
}

function segmentoClase(index) {
  return segmentos.value[index]?.clase ?? 'is-pendiente'
}

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
    return `Clase ${nodo.leccion.orden}, próxima clase: ${titulo}`
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
  gap: 0;
  padding: var(--k-space-2) 0 var(--k-space-4);
  margin-top: var(--k-space-4);
}

/* Hero de la unidad: número, nombre, descripción y progreso. */
.camino-hero {
  display: grid;
  gap: var(--k-space-3);
  padding: var(--k-space-5);
  border-radius: var(--k-radius);
  background: linear-gradient(165deg, #3e065f 0%, #240a34 100%);
  border: 1px solid rgba(142, 5, 194, 0.4);
  width: 100%;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
}

.camino-hero-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.camino-hero-eyebrow {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #c89be0;
}

.camino-hero-badge {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  padding: 5px 10px;
  border-radius: 999px;
  background: rgba(142, 5, 194, 0.22);
  color: #e9c5ff;
  border: 1px solid rgba(226, 176, 255, 0.35);
}

.camino-hero-badge.is-actual {
  background: var(--k-accent);
  color: #fff;
  border-color: rgba(255, 255, 255, 0.28);
}

.camino-hero-badge.is-bloqueada {
  background: rgba(24, 9, 31, 0.9);
  color: var(--k-text-3);
  border-color: rgba(120, 90, 170, 0.35);
}

.camino-hero-titulo {
  font-family: var(--k-font-brand);
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
}

.camino-hero-desc {
  font-size: 13.5px;
  line-height: 1.55;
  color: rgba(233, 197, 255, 0.85);
  max-width: 42ch;
}

.camino-hero-progreso {
  display: grid;
  gap: 8px;
  margin-top: 4px;
}

.camino-hero-progreso .k-progress {
  height: 10px;
}

.camino-hero-progreso .k-progress i {
  background: repeating-linear-gradient(
    -45deg,
    #8e05c2 0 12px,
    #a83ef0 12px 24px
  );
}

.camino-hero-contador {
  font-size: 12px;
  font-weight: 700;
  color: rgba(233, 197, 255, 0.8);
}

.camino-guia {
  font-size: 13.5px;
  font-weight: 700;
  line-height: 1.5;
  color: var(--k-text-2);
  text-align: center;
  padding: 10px 14px;
  border-radius: var(--k-radius-sm);
  background: rgba(142, 5, 194, 0.1);
  border: 1px dashed rgba(142, 5, 194, 0.3);
  max-width: 300px;
}

/* Línea que conecta los nodos siguiendo el zigzag del camino. En flujo, entre nodos. */
.camino-conexiones {
  display: block;
  flex-shrink: 0;
  width: 240px;
  height: 34px;
  overflow: visible;
  pointer-events: none;
  margin: -6px 0;
}

.camino-segmento {
  fill: none;
  stroke-width: 6;
  stroke-linecap: round;
  transition: stroke 0.18s ease;
}

.camino-segmento.is-pendiente {
  stroke: rgba(216, 180, 254, 0.22);
  stroke-dasharray: 3 12;
}

.camino-segmento.is-actual {
  stroke: rgba(200, 120, 255, 0.75);
  stroke-dasharray: 8 9;
}

.camino-segmento.is-visto {
  stroke: var(--k-accent);
  filter: drop-shadow(0 0 6px rgba(142, 5, 194, 0.45));
}

.camino-nodo {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 64px;
  height: 64px;
  padding: 0;
  border: none;
  background: transparent;
  cursor: pointer;
  border-radius: 50%;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.14s ease;
  transform: translateX(var(--dx, 0px));
}

.camino-nodo:disabled {
  cursor: default;
}

.camino-nodo:active {
  transform: translateX(var(--dx, 0px)) scale(0.92);
}

.camino-anillo {
  position: absolute;
  inset: -7px;
  border-radius: 50%;
  border: 2px solid transparent;
  pointer-events: none;
}

.camino-centro {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: radial-gradient(circle at 38% 32%, #2b113a 0%, #1e0a2a 100%);
  border: 3px solid rgba(216, 180, 254, 0.35);
  color: rgba(216, 180, 254, 0.88);
  font-size: 19px;
  font-weight: 800;
  box-shadow: 0 6px 14px rgba(0, 0, 0, 0.45);
}

.camino-numero {
  position: absolute;
  bottom: -8px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 11px;
  font-weight: 800;
  color: rgba(216, 180, 254, 0.7);
  pointer-events: none;
}

/* Nombre de la próxima clase, pegado debajo del nodo actual. */
.camino-nombre-nodo {
  position: absolute;
  top: calc(100% + 2px);
  left: 50%;
  transform: translateX(-50%);
  white-space: nowrap;
  font-size: 11px;
  font-weight: 700;
  color: rgba(216, 180, 254, 0.75);
  pointer-events: none;
  z-index: 2;
}

/* Nodo superado (aprobado): tilde violeta sobre fondo oscuro. */
.camino-nodo.is-visto .camino-centro {
  background: radial-gradient(circle at 38% 32%, #34204a 0%, #251033 100%);
  border-color: var(--k-accent);
  color: #d290ff;
}

.camino-nodo.is-visto .camino-anillo {
  border-color: rgba(240, 70, 240, 0.28);
}

/* Nodo actual: violeta sólido con halo suave */
.camino-nodo.is-actual .camino-centro {
  background: linear-gradient(170deg, #a83ef0 0%, #8e05c2 55%, #700b97 100%);
  border-color: rgba(255, 255, 255, 0.35);
  color: #fff;
  box-shadow:
    0 0 0 7px rgba(142, 5, 194, 0.18),
    0 0 28px rgba(142, 5, 194, 0.5);
}

.camino-nodo.is-actual .camino-anillo {
  border-color: rgba(226, 176, 255, 0.5);
  animation: camino-halo 1.6s ease-in-out infinite;
}

.camino-nodo.is-actual .camino-numero {
  color: #c89be0;
}

@keyframes camino-halo {
  0%, 100% { box-shadow: inset 0 0 0 0 rgba(255, 255, 255, 0.12); opacity: 1 }
  50% { box-shadow: inset 0 0 12px 0 rgba(255, 255, 255, 0.22); opacity: 0.85 }
}

/* Nodo bloqueado: apagado y con candado, pero visible (mock) */
.camino-nodo.is-bloqueada .camino-centro {
  background: radial-gradient(circle at 38% 32%, #241328 0%, #160a1c 100%);
  border-color: rgba(216, 180, 254, 0.18);
  color: rgba(178, 148, 206, 0.6);
}

.camino-nodo.is-bloqueada .camino-numero {
  color: rgba(178, 148, 206, 0.62);
}

/* Mensaje de la mascota al pie. */
.camino-mensaje {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-top: var(--k-space-4);
  padding: 10px 14px;
  max-width: 300px;
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
  .camino-nodo:active,
  .camino-nodo.is-actual .camino-anillo {
    transition: none;
    animation: none;
  }
}
</style>
