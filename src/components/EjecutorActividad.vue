<template>
  <div class="activity-runner">
    <h2 class="activity-statement">{{ pregunta.enunciado }}</h2>

    <div v-if="opciones.length" class="options">
      <button
        v-for="(opcion, index) in opciones"
        :key="opcion.id"
        type="button"
        class="option"
        :class="optionClasses(opcion)"
        :disabled="bloqueado"
        @click="seleccionar(opcion)"
      >
        <span class="option-letter k-mono">{{ letters[index] }}</span>
        <code class="option-text k-mono">{{ opcion.texto }}</code>
      </button>
    </div>

    <transition name="fade">
      <div v-if="devolucion" class="feedback" :class="feedbackClass">
        <q-icon :name="feedbackIcona" size="20px" />
        <div class="feedback-body">
          <strong>{{ feedbackTitulo }}</strong>
          <p>{{ feedbackMensaje }}</p>
        </div>
      </div>
    </transition>

    <button
      type="button"
      class="k-btn k-btn--primary k-btn--block action-main"
      :disabled="!puedeAccionar"
      @click="accionPrincipal"
    >
      <q-spinner v-if="corrigiendo" size="19px" class="on-left" color="white" />
      <q-icon
        v-else
        :name="actionLabel === 'Siguiente' ? 'chevron_right' : 'play_arrow'"
        size="19px"
      />
      {{ actionLabel }}
    </button>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'

const props = defineProps({
  pregunta: {
    type: Object,
    required: false,
    default: null,
  },
  corrigiendo: {
    type: Boolean,
    default: false,
  },
  devolucion: {
    type: Object,
    default: null,
  },
})

const emit = defineEmits(['comprobar', 'siguiente'])

const letters = ['A', 'B', 'C', 'D', 'E', 'F']

const seleccionId = ref(null)

const opciones = computed(() => props.pregunta?.opciones ?? [])

const haySeleccion = computed(() => seleccionId.value !== null)

const respuestaLockeada = computed(() => Boolean(props.devolucion))

const bloqueado = computed(() => props.corrigiendo || respuestaLockeada.value)

const puedeAccionar = computed(() => {
  if (props.corrigiendo) return false
  if (respuestaLockeada.value) return true
  return haySeleccion.value
})

const actionLabel = computed(() => {
  if (props.corrigiendo) return 'Comprobando…'
  if (respuestaLockeada.value && props.devolucion?.estado === 'error') return 'Reintentar'
  if (respuestaLockeada.value) return 'Siguiente'
  return 'Comprobar'
})

// Distinguimos la devolución: cualquier respuesta ya vuelve evaluada del server.
// Las incorrectas muestran "Incorrecta"; el estado 'error' significa que no se
// pudo comprobar la respuesta y se ofrece reintentar.
const feedbackClass = computed(() => {
  if (!props.devolucion) return ''
  if (props.devolucion.estado === 'correcta') return 'is-correct'
  if (props.devolucion.estado === 'error') return 'is-neutral'
  return 'is-wrong'
})

const feedbackIcona = computed(() => {
  if (props.devolucion?.estado === 'correcta') return 'check_circle'
  if (props.devolucion?.estado === 'error') return 'error_outline'
  return 'cancel'
})

const feedbackTitulo = computed(() => {
  if (props.devolucion?.estado === 'correcta') return 'Correcto'
  if (props.devolucion?.estado === 'error') return 'No se pudo comprobar'
  return 'Incorrecto'
})

const feedbackMensaje = computed(() => {
  if (props.devolucion?.estado === 'error') {
    return (
      props.devolucion.mensaje ||
      'Hubo un problema al comprobar tu respuesta. Reintentá o revisá tu conexión.'
    )
  }
  return props.devolucion?.explicacion || ''
})

function seleccionar(opcion) {
  if (bloqueado.value) return
  seleccionId.value = opcion.id
}

function optionClasses(opcion) {
  const clases = { 'is-selected': seleccionId.value === opcion.id }
  if (!props.devolucion) return clases
  if (props.devolucion.estado === 'error') return clases
  return {
    ...clases,
    'is-correct': seleccionId.value === opcion.id && props.devolucion.estado === 'correcta',
    'is-wrong': seleccionId.value === opcion.id && props.devolucion.estado === 'incorrecta',
  }
}

function accionPrincipal() {
  if (props.corrigiendo) return
  if (
    respuestaLockeada.value &&
    props.devolucion?.estado === 'error' &&
    seleccionId.value !== null
  ) {
    emit('comprobar', seleccionId.value)
    return
  }
  if (respuestaLockeada.value) {
    emit('siguiente')
    return
  }
  if (seleccionId.value !== null) {
    emit('comprobar', seleccionId.value)
  }
}

watch(
  () => props.pregunta?.id,
  () => {
    seleccionId.value = null
  },
  { immediate: true },
)
</script>

<style scoped>
.activity-runner {
  display: grid;
  gap: var(--k-space-4);
}

.activity-statement {
  font-size: 18px;
  font-weight: 700;
  line-height: 1.45;
  white-space: pre-wrap;
}

.options {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.option {
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

.option:disabled {
  cursor: default;
}

.option-letter {
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

.option-text {
  font-size: 13px;
  color: var(--k-text);
  white-space: pre-wrap;
  word-break: break-word;
}

.option.is-selected {
  border-color: var(--k-accent);
  background: var(--k-accent-soft);
}

.option.is-selected .option-letter {
  border-color: var(--k-accent);
  color: var(--k-accent);
}

.option.is-correct {
  border-color: var(--k-success);
  background: rgba(52, 211, 153, 0.12);
}

.option.is-correct .option-letter {
  border-color: var(--k-success);
  color: var(--k-success);
}

.option.is-wrong {
  border-color: var(--k-error);
  background: rgba(255, 93, 115, 0.1);
}

.option.is-wrong .option-letter {
  border-color: var(--k-error);
  color: var(--k-error);
}

.feedback {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
  padding: 14px 16px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
}

.feedback.is-correct {
  border-color: rgba(52, 211, 153, 0.4);
  background: rgba(52, 211, 153, 0.1);
}

.feedback.is-wrong {
  border-color: rgba(255, 93, 115, 0.4);
  background: rgba(255, 93, 115, 0.1);
}

.feedback.is-neutral {
  border-color: rgba(250, 204, 21, 0.4);
  background: rgba(250, 204, 21, 0.08);
}

.feedback.is-correct .q-icon {
  color: var(--k-success);
}

.feedback.is-wrong .q-icon {
  color: var(--k-error);
}

.feedback.is-neutral .q-icon {
  color: #facc14;
}

.feedback-body strong {
  display: block;
  font-size: 14px;
}

.feedback-body p {
  margin-top: var(--k-space-1);
  font-size: 13px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.action-main {
  margin-top: var(--k-space-6);
}

.action-main .on-left {
  margin-right: 8px;
}

.fade-enter-active,
.fade-leave-active {
  transition:
    opacity 0.15s ease,
    transform 0.15s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(4px);
}
</style>
