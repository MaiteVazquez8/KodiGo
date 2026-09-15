<template>
  <nav class="bottom-nav">
    <RouterLink
      to="/"
      class="nav-item"
      :class="{ 'is-active': active === 'home' }"
      aria-label="Inicio"
    >
      <q-icon name="home" size="22px" />
      <span class="nav-label">Inicio</span>
    </RouterLink>
    <RouterLink
      to="/courses"
      class="nav-item"
      :class="{ 'is-active': active === 'courses' }"
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

const active = computed(() => {
  if (route.name === 'courses' || route.name === 'course') return 'courses'
  return 'home'
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
  gap: var(--k-space-3);
  padding: 10px 20px calc(10px + env(safe-area-inset-bottom));
  background: rgba(0, 0, 0, 0.92);
  border-top: 1px solid var(--k-line);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--k-space-1);
  padding: 8px 28px;
  border-radius: 14px;
  color: var(--k-text-3);
  text-decoration: none;
  transition: color 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}

.nav-item.is-active {
  color: var(--k-accent);
}

.nav-label {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.02em;
}
</style>
