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
      <q-icon :name="pestana.icono" size="21px" />
      <span class="nav-label">{{ pestana.etiqueta }}</span>
    </RouterLink>
  </nav>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const pestanas = [
  { clave: 'learn', etiqueta: 'Learn', icono: 'school', ruta: '/learn' },
  { clave: 'search', etiqueta: 'Search', icono: 'search', ruta: '/courses' },
  { clave: 'review', etiqueta: 'Review', icono: 'refresh', ruta: '/review' },
  { clave: 'dictionary', etiqueta: 'Dictionary', icono: 'menu_book', ruta: '/diccionario' },
  { clave: 'more', etiqueta: 'More', icono: 'more_horiz', ruta: '/mas' },
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
