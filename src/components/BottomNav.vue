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
    <RouterLink to="/ranking" class="nav-item" :class="{ 'is-active': active === 'ranking' }" aria-label="Ranking">
      <q-icon name="leaderboard" size="22px" />
      <span class="nav-label">Ranking</span>
    </RouterLink>
    <RouterLink to="/friends" class="nav-item" :class="{ 'is-active': active === 'friends' }" aria-label="Amigos">
      <q-icon name="group" size="22px" />
      <span class="nav-label">Amigos</span>
    </RouterLink>
    <RouterLink to="/profile" class="nav-item" :class="{ 'is-active': active === 'profile' }" aria-label="Perfil">
      <q-icon name="person" size="22px" />
      <span class="nav-label">Perfil</span>
    </RouterLink>
  </nav>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const active = computed(() => {
  if (route.name === 'courses' || route.name === 'course') return 'courses'
  if (route.name === 'ranking') return 'ranking'
  if (route.name === 'friends') return 'friends'
  if (route.name === 'profile') return 'profile'
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
  justify-content: space-around;
  gap: 0;
  padding: 8px 8px calc(8px + env(safe-area-inset-bottom));
  background: #07000d;
  border: 1px solid var(--k-deep);
  border-radius: 24px 24px 0 0;
}

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--k-space-1);
  width: 20%;
  padding: 4px 2px;
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
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.02em;
}
</style>
