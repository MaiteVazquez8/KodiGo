<template>
  <article
    class="unit-card"
    :class="[`is-${unit.estado}`, { 'is-clickable': unit.estado !== 'bloqueada' }]"
    :role="unit.estado === 'bloqueada' ? undefined : 'button'"
    :tabindex="unit.estado === 'bloqueada' ? -1 : 0"
    aria-label="Abrir unidad {{ unit.nombre }}"
    @click="onSelect"
    @keyup.enter="onSelect"
  >
    <div class="unit-card-top">
      <span class="unit-tag">Unidad {{ unit.orden }}</span>
      <span class="unit-state" :class="`state-${unit.estado}`">{{ stateLabel }}</span>
    </div>

    <h2 class="unit-card-title">{{ unit.nombre }}</h2>
    <p class="unit-card-desc">{{ unit.descripcion }}</p>

    <div v-if="unit.estado !== 'bloqueada'" class="unit-card-progress">
      <div class="k-progress">
        <i :style="{ width: unit.progreso + '%' }"></i>
      </div>
      <div class="unit-card-meta">
        <span>{{ lessons }} lecciones</span>
        <span>{{ unit.progreso }}%</span>
      </div>
    </div>

    <div class="unit-card-action">
      <template v-if="unit.estado === 'bloqueada'">
        <q-icon name="lock" size="15px" />
        <span>Bloqueada</span>
      </template>
      <template v-else>
        <q-icon :name="unit.estado === 'completada' ? 'replay' : 'play_arrow'" size="18px" />
        <span>{{ unit.estado === 'completada' ? 'Repasar' : 'Continuar' }}</span>
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
  const labels = { disponible: 'Disponible', bloqueada: 'Bloqueada', completada: 'Completada' }
  return labels[props.unit.estado] || 'Disponible'
})

function onSelect() {
  if (props.unit.estado !== 'bloqueada') emit('select', props.unit.id)
}
</script>

<style scoped>
.unit-card {
  position: relative;
  padding: 18px 18px 16px;
  background: linear-gradient(180deg, rgba(53, 16, 71, 0.96), rgba(24, 9, 31, 0.98));
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 20px;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
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

.unit-card.is-completada {
  border-color: rgba(52, 211, 153, 0.35);
}

.unit-card.is-disponible {
  border-color: rgba(142, 5, 194, 0.55);
}

.unit-card.is-bloqueada {
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

.state-disponible {
  color: var(--k-accent);
}

.state-bloqueada {
  color: var(--k-text-3);
}

.state-completada {
  color: var(--k-success);
}

.unit-card-title {
  margin-top: 14px;
  font-size: 22px;
  font-weight: 800;
  letter-spacing: -0.02em;
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
  margin-top: 16px;
  font-size: 13px;
  font-weight: 800;
  color: var(--k-accent);
}

.unit-card.is-bloqueada .unit-card-action {
  color: var(--k-text-3);
}
</style>
