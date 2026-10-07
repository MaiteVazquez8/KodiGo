<template>
  <nav class="bottom-nav">
    <RouterLink
      to="/"
      class="nav-item"
      :class="{ 'is-active': activo === 'inicio' }"
      aria-label="Inicio"
    >
      <q-icon name="home" size="22px" />
      <span class="nav-label">Inicio</span>
    </RouterLink>
    <RouterLink
      to="/courses"
      class="nav-item"
      :class="{ 'is-active': activo === 'cursos' }"
      aria-label="Cursos"
    >
      <q-icon name="school" size="22px" />
      <span class="nav-label">Cursos</span>
    </RouterLink>
  </nav>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const activo = computed(() => {
  if (route.name === 'cursos' || route.name === 'curso') return 'cursos'
  return 'inicio'
})
</script>

<style scoped>
.bottom-nav {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 30;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 10px 20px calc(12px + env(safe-area-inset-bottom));
  background: rgba(10, 4, 16, 0.96);
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  min-width: 94px;
  padding: 8px 12px;
  border-radius: 14px;
  color: rgba(255, 255, 255, 0.72);
  text-decoration: none;
  transition:
    color 0.15s ease,
    background 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}

.nav-item.is-active {
  color: var(--k-accent);
  background: rgba(142, 5, 194, 0.08);
}

.nav-label {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.02em;
}
</style>
