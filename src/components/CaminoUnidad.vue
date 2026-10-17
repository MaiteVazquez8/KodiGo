<template>
  <div class="camino">
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

    <span class="camino-linea" aria-hidden="true" />

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
  gap: var(--k-space-7);
  padding: var(--k-space-5) 0 var(--k-space-2);
  margin-top: var(--k-space-5);
}

/* Linea vertical detras de los nodos */
.camino-linea {
  position: absolute;
  top: 26px;
  bottom: 40px;
  left: 50%;
  transform: translateX(-50%);
  width: 3px;
  border-radius: 999px;
  background: rgba(210, 170, 230, 0.16);
  pointer-events: none;
}

.camino-nodo {
  position: relative;
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
