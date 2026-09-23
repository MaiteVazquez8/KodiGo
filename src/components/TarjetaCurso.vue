<template>
  <article
    class="course-card"
    :class="{ 'is-locked': !cursoDisponible }"
    role="button"
    tabindex="0"
    aria-label="Abrir curso {{ curso.name }}"
    @click="emitir('select', curso.id)"
    @keyup.enter="emitir('select', curso.id)"
  >
    <LogoCurso :curso="curso" />

    <div class="course-card-body">
      <div class="course-card-head">
        <h2 class="course-card-title">{{ curso.name }}</h2>
        <span class="course-badge" :class="{ 'badge-locked': !cursoDisponible }">
          {{ cursoDisponible ? 'Disponible' : 'Próximamente' }}
        </span>
      </div>
      <p class="course-card-tagline">{{ curso.tagline }}</p>

      <div v-if="cursoDisponible" class="course-card-progress">
        <div class="k-progress">
          <i :style="{ width: curso.progress + '%' }"></i>
        </div>
        <span class="course-card-percent">{{ curso.progress }}%</span>
      </div>
    </div>

    <q-icon v-if="cursoDisponible" name="chevron_right" size="20px" class="course-card-chev" />
  </article>
</template>

<script setup>
import { computed } from 'vue'
import LogoCurso from './LogoCurso.vue'

const props = defineProps({
  curso: {
    type: Object,
    required: true,
  },
})

const emit = defineEmits(['select'])

const cursoDisponible = computed(() => props.curso.status === 'available')

function emitir(evento, valor) {
  emit(evento, valor)
}
</script>

<style scoped>
.course-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 18px;
  background: linear-gradient(180deg, rgba(53, 16, 71, 0.96), rgba(24, 9, 31, 0.98));
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 20px;
  cursor: pointer;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
  transition:
    border-color 0.15s ease,
    transform 0.08s ease,
    box-shadow 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}

.course-card:active {
  transform: scale(0.985);
}

.course-card.is-locked {
  cursor: default;
  opacity: 0.55;
}

.course-card.is-locked:active {
  transform: none;
}

.course-card-body {
  flex: 1;
  min-width: 0;
}

.course-card-head {
  display: flex;
  align-items: center;
  gap: 10px;
}

.course-card-title {
  font-size: 18px;
  font-weight: 800;
  letter-spacing: -0.01em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.course-badge {
  flex-shrink: 0;
  padding: 4px 8px;
  border-radius: 999px;
  background: rgba(142, 5, 194, 0.16);
  color: var(--k-accent);
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.badge-locked {
  background: var(--k-surface);
  color: var(--k-text-3);
}

.course-card-tagline {
  margin-top: 3px;
  font-size: 13px;
  font-weight: 600;
  color: var(--k-text-2);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.course-card-progress {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-3);
}

.course-card-progress .k-progress {
  flex: 1;
}

.course-card-percent {
  font-size: 12px;
  font-weight: 800;
  color: var(--k-text-2);
  flex-shrink: 0;
}

.course-card-chev {
  flex-shrink: 0;
  color: var(--k-text-3);
}
</style>
