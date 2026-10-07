<template>
  <div class="estado-pantalla" :class="`es-${tipo}`" role="status">
    <FantasmaKodigo :size="88" :variant="variant" class="estado-avatar" />

    <template v-if="tipo === 'cargando'">
      <p class="estado-titulo">Cargando contenido…</p>
      <p class="estado-detalle">Consultando la base de datos de Kodigo.</p>
    </template>

    <template v-else>
      <p class="k-eyebrow estado-eyebrow">{{ eyebrow }}</p>
      <h1 class="k-h1 estado-titulo">{{ titulo }}</h1>
      <p class="estado-detalle">{{ mensaje }}</p>

      <button
        v-if="accionLabel"
        type="button"
        class="k-btn k-btn--primary k-btn--block k-btn--lg estado-accion"
        @click="$emit('accion')"
      >
        <q-icon name="refresh" size="19px" />
        {{ accionLabel }}
      </button>
    </template>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import FantasmaKodigo from './FantasmaKodigo.vue'

const props = defineProps({
  tipo: {
    type: String,
    default: 'cargando',
  },
  titulo: {
    type: String,
    default: '',
  },
  mensaje: {
    type: String,
    default: '',
  },
  accionLabel: {
    type: String,
    default: '',
  },
})

defineEmits(['accion'])

const variant = computed(() => {
  if (props.tipo === 'cargando') return 'normal'
  if (props.tipo === 'error') return 'sad'
  return 'normal'
})

const eyebrow = computed(() => {
  const encabezados = {
    error: 'Ocurrió un problema',
    vacio: 'Sin contenido',
    inexistente: 'No encontrado',
  }
  return encabezados[props.tipo] || 'Kodigo'
})
</script>

<style scoped>
.estado-pantalla {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 40px 20px;
}

.estado-avatar {
  opacity: 0.85;
}

.estado-pantalla.es-cargando .estado-avatar {
  animation: estado-flotar 1.6s ease-in-out infinite;
}

@keyframes estado-flotar {
  0%,
  100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-6px);
  }
}

.estado-eyebrow {
  margin-top: var(--k-space-4);
}

.estado-titulo {
  margin-top: var(--k-space-2);
}

.estado-detalle {
  margin-top: var(--k-space-3);
  max-width: 300px;
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.estado-accion {
  margin-top: var(--k-space-5);
  max-width: 280px;
}
</style>
