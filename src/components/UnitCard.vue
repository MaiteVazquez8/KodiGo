<template>
  <article
    class="unit-card"
    :class="[`is-${unit.status}`, { 'is-clickable': unit.status !== 'locked' }]"
    :role="unit.status === 'locked' ? undefined : 'button'"
    :tabindex="unit.status === 'locked' ? -1 : 0"
    aria-label="Abrir unidad {{ unit.title }}"
    @click="onSelect"
    @keyup.enter="onSelect"
  >
    <div class="unit-card-top">
      <span class="unit-tag">Unidad {{ unit.id }}</span>
      <span class="unit-state" :class="`state-${unit.status}`">{{ stateLabel }}</span>
    </div>

    <h2 class="unit-card-title">{{ unit.title }}</h2>
    <p class="unit-card-desc">{{ unit.description }}</p>

    <div v-if="unit.status !== 'locked'" class="unit-card-progress">
      <div class="k-progress">
        <i :style="{ width: unit.progress + '%' }"></i>
      </div>
      <div class="unit-card-meta">
        <span>{{ lessons }} lecciones</span>
        <span>{{ unit.progress }}%</span>
      </div>
    </div>

    <div class="unit-card-action">
      <template v-if="unit.status === 'locked'">
        <q-icon name="lock" size="15px" />
        <span>Bloqueada</span>
      </template>
      <template v-else>
        <q-icon :name="unit.status === 'completed' ? 'replay' : 'play_arrow'" size="18px" />
        <span>{{ unit.status === 'completed' ? 'Repasar' : 'Continuar' }}</span>
      </template>
    </div>
  </article>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  unit: {
    type: Object,
    required: true,
  },
  lessons: {
    type: Number,
    default: 0,
  },
})

const emit = defineEmits(['select'])

const stateLabel = computed(() => {
  const labels = { available: 'Disponible', locked: 'Bloqueada', completed: 'Completada' }
  return labels[props.unit.status] || 'Disponible'
})

function onSelect() {
  if (props.unit.status !== 'locked') emit('select', props.unit.id)
}
</script>

<style scoped>
.unit-card {
  position: relative;
  padding: 20px;
  background: var(--k-surface-2);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius);
  transition:
    border-color 0.15s ease,
    transform 0.08s ease;
  -webkit-tap-highlight-color: transparent;
}

.unit-card.is-clickable {
  cursor: pointer;
}

.unit-card.is-clickable:active {
  transform: scale(0.985);
}

.unit-card.is-completed {
  border-color: rgba(52, 211, 153, 0.35);
}

.unit-card.is-available {
  border-color: rgba(142, 5, 194, 0.55);
}

.unit-card.is-locked {
  opacity: 0.55;
}

.unit-card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--k-space-3);
}

.unit-tag {
  padding: 4px 10px;
  border-radius: 99px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  color: var(--k-text-2);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.unit-state {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.state-available {
  color: var(--k-accent);
}

.state-locked {
  color: var(--k-text-3);
}

.state-completed {
  color: var(--k-success);
}

.unit-card-title {
  margin-top: var(--k-space-4);
  font-size: 19px;
  font-weight: 800;
  letter-spacing: -0.01em;
}

.unit-card-desc {
  margin-top: var(--k-space-2);
  font-size: 13.5px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.unit-card-progress {
  margin-top: var(--k-space-5);
}

.unit-card-meta {
  display: flex;
  justify-content: space-between;
  margin-top: var(--k-space-2);
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
}

.unit-card-action {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-top: var(--k-space-4);
  font-size: 13px;
  font-weight: 800;
  color: var(--k-accent);
}

.unit-card.is-locked .unit-card-action {
  color: var(--k-text-3);
}
</style>
