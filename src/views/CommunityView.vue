<template>
  <div class="k-screen">
    <AppHeader :title="title" :back="true" />
    <main class="k-container community">
      <section class="community-profile">
        <KodigoGhost :size="76" variant="happy" />
        <div><h1>{{ heading }}</h1><p>{{ subtitle }}</p></div>
      </section>
      <section class="community-panel">
        <div class="panel-head"><h2>{{ panelTitle }}</h2><span>{{ panelValue }}</span></div>
        <div class="k-progress"><i style="width: 42%"></i></div>
      </section>
      <div class="community-list">
        <article v-for="item in items" :key="item.name" class="community-row">
          <span class="row-avatar">{{ item.initial }}</span>
          <span><b>{{ item.name }}</b><small>{{ item.detail }}</small></span>
          <q-icon name="chevron_right" size="18px" />
        </article>
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import KodigoGhost from '@/components/KodigoGhost.vue'

const route = useRoute()
const content = {
  ranking: { title: 'Ranking', heading: 'Tabla semanal', subtitle: 'Compará tu progreso con la comunidad.', panelTitle: 'Tu posición', panelValue: '#12' },
  friends: { title: 'Amigos', heading: 'Tu comunidad', subtitle: 'Aprender acompañado hace la diferencia.', panelTitle: 'Amigos activos', panelValue: '3' },
  profile: { title: 'Perfil', heading: 'dev_juan', subtitle: 'Seguimiento de tu camino en Kodigo.', panelTitle: 'Progreso general', panelValue: '18%' },
  achievements: { title: 'Logros', heading: 'Colección', subtitle: 'Tus hitos de aprendizaje.', panelTitle: 'Desbloqueados', panelValue: '4' },
  settings: { title: 'Configuración', heading: 'Preferencias', subtitle: 'Personalizá tu experiencia.', panelTitle: 'Cuenta', panelValue: 'Activa' },
}
const current = computed(() => content[route.name] || content.profile)
const title = computed(() => current.value.title)
const heading = computed(() => current.value.heading)
const subtitle = computed(() => current.value.subtitle)
const panelTitle = computed(() => current.value.panelTitle)
const panelValue = computed(() => current.value.panelValue)
const items = computed(() => route.name === 'ranking'
  ? [{ initial: '1', name: 'ana_code', detail: '1.240 XP' }, { initial: '2', name: 'lucas.dev', detail: '980 XP' }, { initial: '3', name: 'mar_programa', detail: '850 XP' }]
  : [{ initial: 'A', name: 'ana_code', detail: 'En racha de 7 días' }, { initial: 'L', name: 'lucas.dev', detail: 'Última actividad hoy' }])
</script>

<style scoped>
.community { padding-top: 12px; }
.community-profile { display: flex; align-items: center; gap: 14px; }
.community-profile h1 { font-size: 21px; font-weight: 800; }
.community-profile p { margin-top: 4px; color: var(--k-text-2); font-size: 12px; }
.community-panel { margin-top: 24px; padding: 15px; border: 1px solid var(--k-deep); border-radius: 10px; background: var(--k-surface-2); }
.panel-head { display: flex; justify-content: space-between; margin-bottom: 12px; }
.panel-head h2 { font-size: 14px; }
.panel-head span { color: var(--k-accent); font-size: 12px; font-weight: 800; }
.community-list { display: grid; gap: 8px; margin-top: 16px; }
.community-row { display: flex; align-items: center; gap: 12px; padding: 12px; border: 1px solid var(--k-deep); border-radius: 9px; background: var(--k-surface-2); }
.row-avatar { display: grid; place-items: center; width: 32px; height: 32px; border-radius: 50%; background: var(--k-deep); color: var(--k-accent); font-weight: 800; }
.community-row span:nth-child(2) { display: grid; flex: 1; gap: 2px; }
.community-row small { color: var(--k-text-3); font-size: 10px; }
.community-row .q-icon { color: var(--k-text-3); }
</style>
