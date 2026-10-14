<template>
  <label class="campo-formulario">
    <span v-if="etiqueta" class="campo-etiqueta">{{ etiqueta }}</span>
    <div class="campo-envoltorio" :class="{ 'con-ver': esClave }">
      <input
        class="campo-control"
        :class="{ 'tiene-error': mensajeAyuda && tipoMensaje === 'error' }"
        :type="tipoReal"
        :inputmode="inputmode"
        :autocomplete="autocomplete"
        :placeholder="placeholder"
        :disabled="deshabilitado"
        :value="modelValue"
        @input="$emit('update:modelValue', $event.target.value)"
        @keyup.enter="$emit('enviar')"
      />
      <button
        v-if="esClave"
        type="button"
        class="campo-ver"
        :aria-label="verClave ? 'Ocultar contraseña' : 'Mostrar contraseña'"
        @click="verClave = !verClave"
      >
        <q-icon :name="verClave ? 'visibility_off' : 'visibility'" size="18px" />
      </button>
    </div>
    <span
      v-if="mensajeAyuda"
      class="campo-ayuda"
      :class="tipoMensaje === 'error' ? 'es-error' : 'es-pista'"
      >{{ mensajeAyuda }}</span
    >
  </label>
</template>

<script setup>
import { computed, ref } from 'vue'

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  etiqueta: {
    type: String,
    default: '',
  },
  tipo: {
    type: String,
    default: 'text',
  },
  inputmode: {
    type: String,
    default: '',
  },
  autocomplete: {
    type: String,
    default: '',
  },
  placeholder: {
    type: String,
    default: '',
  },
  mensajeAyuda: {
    type: String,
    default: '',
  },
  tipoMensaje: {
    type: String,
    default: 'error',
  },
  deshabilitado: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['update:modelValue', 'enviar'])

const verClave = ref(false)

const esClave = computed(() => props.tipo === 'password')
const tipoReal = computed(() => (esClave.value && verClave.value ? 'text' : props.tipo))
</script>

<style scoped>
.campo-formulario {
  display: block;
}

.campo-etiqueta {
  display: block;
  margin-bottom: 6px;
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  color: var(--k-text-2);
}

.campo-envoltorio {
  position: relative;
}

.campo-control {
  width: 100%;
  padding: 13px 14px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-family: inherit;
  font-size: 15px;
  font-weight: 600;
  line-height: 1.4;
  outline: none;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}

.campo-envoltorio.con-ver .campo-control {
  padding-right: 44px;
}

.campo-ver {
  position: absolute;
  top: 50%;
  right: 6px;
  transform: translateY(-50%);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--k-text-3);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.campo-ver:hover {
  color: var(--k-text-2);
}

.campo-control::placeholder {
  color: var(--k-text-3);
}

.campo-control:focus {
  border-color: var(--k-accent);
  box-shadow: 0 0 0 3px rgba(142, 5, 194, 0.22);
}

.campo-control:disabled {
  opacity: 0.55;
}

.campo-control.tiene-error {
  border-color: var(--k-error);
}

.campo-ayuda {
  display: block;
  margin-top: 6px;
  font-size: 12.5px;
  font-weight: 600;
  line-height: 1.45;
}

.campo-ayuda.es-error {
  color: var(--k-error);
}

.campo-ayuda.es-pista {
  color: var(--k-text-3);
}
</style>
