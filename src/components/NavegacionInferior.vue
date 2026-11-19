<template>
  <nav class="bottom-nav">
    <RouterLink
      v-for="pestana in pestanas"
      :key="pestana.clave"
      :to="pestana.ruta"
      class="nav-item"
      :class="{ 'is-active': activo === pestana.clave }"
      :aria-label="pestana.etiqueta"
    >
      <svg
        viewBox="0 0 24 24"
        class="nav-icono"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <template v-if="pestana.icono === 'prender'">
          <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" />
          <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
        </template>
        <template v-else-if="pestana.icono === 'buscar'">
          <circle cx="11" cy="11" r="7" />
          <path d="m21 21-4.3-4.3" />
        </template>
        <template v-else-if="pestana.icono === 'repaso'">
          <path d="M23 4v6h-6" />
          <path d="M1 20v-6h6" />
          <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
          <path d="M3.51 9a9 9 0 0 1 2.13-9.36L1 10" />
        </template>
        <template v-else-if="pestana.icono === 'diccionario'">
          <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
          <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
        </template>
        <template v-else-if="pestana.icono === 'mas'">
          <circle cx="5" cy="12" r="1.4" fill="currentColor" stroke="none" />
          <circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none" />
          <circle cx="19" cy="12" r="1.4" fill="currentColor" stroke="none" />
        </template>
      </svg>
      <span class="nav-label">{{ pestana.etiqueta }}</span>
    </RouterLink>
  </nav>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const pestanas = [
  { clave: 'learn', etiqueta: 'Aprender', icono: 'prender', ruta: '/learn' },
  { clave: 'search', etiqueta: 'Buscar', icono: 'buscar', ruta: '/courses' },
  { clave: 'review', etiqueta: 'Repaso', icono: 'repaso', ruta: '/review' },
  { clave: 'dictionary', etiqueta: 'Diccionario', icono: 'diccionario', ruta: '/diccionario' },
  { clave: 'more', etiqueta: 'Más', icono: 'mas', ruta: '/mas' },
]

const activo = computed(() => {
  const porRuta = {
    learn: 'learn',
    unidad: 'learn',
    leccion: 'learn',
    'leccion-legada': 'learn',
    'actividad-leccion': 'learn',
    actividad: 'learn',
    'resultados-leccion': 'learn',
    cursos: 'search',
    curso: 'search',
    review: 'review',
    diccionario: 'dictionary',
    mas: 'more',
    perfil: 'more',
    configuracion: 'more',
  }
  return porRuta[route.name] || 'learn'
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
  justify-content: space-between;
  gap: 4px;
  padding: 10px 14px calc(12px + env(safe-area-inset-bottom));
  background: rgba(10, 4, 16, 0.96);
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.nav-item {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  min-width: 0;
  padding: 6px 2px;
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

.nav-icono {
  width: 22px;
  height: 22px;
  stroke: currentColor;
  transition: transform 0.15s ease;
}

.nav-item.is-active .nav-icono {
  transform: translateY(-1px);
}

.nav-label {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.01em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}
</style>
