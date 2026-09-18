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
        <span class="brand-name k-font-brand"><b>KODI</b><strong>GO</strong></span>
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
  margin-bottom: var(--k-space-3);
}

.app-header-inner {
  width: 100%;
  max-width: 390px;
  margin: 0 auto;
  padding: 8px 16px;
  display: flex;
  align-items: center;
  gap: var(--k-space-2);
}

.brand {
  display: inline-flex;
  align-items: center;
  padding: 0;
  background: transparent;
  border: 0;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.brand-name {
  font-size: 24px;
  font-weight: 700;
  letter-spacing: 0;
  color: var(--k-text);
}

.brand-name strong {
  color: var(--k-accent);
}

.back-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 28px;
  border: 0;
  background: transparent;
  color: var(--k-text);
  cursor: pointer;
  flex-shrink: 0;
  -webkit-tap-highlight-color: transparent;
}

.app-header-title {
  flex: 1;
  font-size: 18px;
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
