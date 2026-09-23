<template>
  <header class="app-header">
    <div class="app-header-inner" :class="{ 'is-brand': marca }">
      <button
        v-if="marca"
        type="button"
        class="brand"
        aria-label="Ir al inicio"
        @click="$router.push('/')"
      >
        <FantasmaKodigo :size="30" alt="Kodigo" />
        <span class="brand-name k-font-brand">Kodigo</span>
      </button>

      <button v-else type="button" class="back-button" aria-label="Volver" @click="volverAtras">
        <q-icon name="arrow_back" size="20px" />
      </button>

      <h1 class="app-header-title">
        {{ titulo }}
      </h1>

      <span v-if="lado" class="app-header-side">{{ lado }}</span>
      <span v-else class="app-header-spacer"></span>
    </div>
  </header>
</template>

<script setup>
import { useRouter } from 'vue-router'
import FantasmaKodigo from './FantasmaKodigo.vue'

const props = defineProps({
  titulo: {
    type: String,
    default: '',
  },
  lado: {
    type: String,
    default: '',
  },
  marca: {
    type: Boolean,
    default: false,
  },
  back: {
    type: [Object, String, Boolean],
    default: false,
  },
})

const router = useRouter()

function volverAtras() {
  if (props.back && props.back !== true) {
    router.push(props.back)
  } else if (window.history.length > 1) {
    router.back()
  } else {
    router.push('/')
  }
}
</script>

<style scoped>
.app-header {
  margin-bottom: 18px;
}

.app-header-inner {
  width: 100%;
  max-width: 460px;
  margin: 0 auto;
  padding: 12px 18px 10px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 0;
  background: transparent;
  border: 0;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.brand-name {
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--k-text);
}

.back-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(142, 5, 194, 0.06);
  color: var(--k-text);
  cursor: pointer;
  flex-shrink: 0;
  -webkit-tap-highlight-color: transparent;
}

.app-header-title {
  flex: 1;
  font-size: 18px;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--k-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.app-header-side {
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
  flex-shrink: 0;
}

.app-header-spacer {
  width: 32px;
  flex-shrink: 0;
}
</style>
