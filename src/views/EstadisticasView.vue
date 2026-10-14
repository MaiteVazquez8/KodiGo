<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Mis Estadísticas</p>
      <p class="pantalla-subtitulo">Tu progreso diario y consistencia</p>

      <section class="stats-grid">
        <div class="stats-tile">
          <p class="stats-etiqueta">PRECISIÓN</p>
          <p class="stats-valor">—</p>
        </div>
        <div class="stats-tile">
          <p class="stats-etiqueta">TOTAL XP</p>
          <p class="stats-valor es-acento">{{ perfil?.experiencia ?? 0 }}</p>
        </div>
        <div class="stats-tile">
          <p class="stats-etiqueta">RACHA</p>
          <p class="stats-valor">{{ perfil?.racha_dias ?? 0 }}d</p>
        </div>
      </section>

      <EstadoPantalla
        tipo="vacio"
        titulo="Todavía no hay historial"
        mensaje="A medida que completes lecciones vas a ver acá tu evolución."
      />
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { estado as estadoAuth } from '@/services/auth'

const perfil = computed(() => estadoAuth.perfil)
</script>

<style scoped>
.pantalla {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.pantalla-titulo {
  margin-top: var(--k-space-2);
}

.pantalla-subtitulo {
  margin-top: var(--k-space-2);
  font-size: 14px;
  color: var(--k-text-2);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.stats-tile {
  padding: var(--k-space-4) var(--k-space-2);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  text-align: center;
}

.stats-etiqueta {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: var(--k-text-3);
}

.stats-valor {
  margin-top: 4px;
  font-size: 19px;
  font-weight: 800;
}

.stats-valor.es-acento {
  color: var(--k-accent);
}
</style>
