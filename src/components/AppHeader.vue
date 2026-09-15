<template>
  <header class="app-header">
    <div class="app-header-inner" :class="{ 'is-brand': brand }">
      <button
        v-if="brand"
        type="button"
        class="brand"
        aria-label="Ir al inicio"
        @click="$router.push('/')"
      >
        <KodigoGhost :size="30" alt="Kodigo" />
        <span class="brand-name k-font-brand">Kodigo</span>
      </button>

      <button v-else type="button" class="back-button" aria-label="Volver" @click="goBack">
        <q-icon name="arrow_back" size="20px" />
      </button>

      <h1 class="app-header-title">
        {{ title }}
      </h1>

      <span v-if="side" class="app-header-side">{{ side }}</span>
      <span v-else class="app-header-spacer"></span>
    </div>
  </header>
</template>

<script setup>
import { useRouter } from 'vue-router'
import KodigoGhost from './KodigoGhost.vue'

const props = defineProps({
  title: {
    type: String,
    default: '',
  },
  side: {
    type: String,
    default: '',
  },
  brand: {
    type: Boolean,
    default: false,
  },
  back: {
    type: [Object, String, Boolean],
    default: false,
  },
})

const router = useRouter()

function goBack() {
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
  margin-bottom: var(--k-space-5);
}

.app-header-inner {
  width: 100%;
  max-width: 460px;
  margin: 0 auto;
  padding: 10px 20px;
  display: flex;
  align-items: center;
  gap: var(--k-space-2);
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 0;
  background: transparent;
  border: 0;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.brand-name {
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--k-text);
}

.back-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  cursor: pointer;
  flex-shrink: 0;
  -webkit-tap-highlight-color: transparent;
}

.app-header-title {
  flex: 1;
  font-size: 17px;
  font-weight: 800;
  letter-spacing: -0.01em;
  color: var(--k-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.app-header-side {
  font-size: 13px;
  font-weight: 700;
  color: var(--k-text-3);
  flex-shrink: 0;
}

.app-header-spacer {
  width: 40px;
  flex-shrink: 0;
}
</style>
