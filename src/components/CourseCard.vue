<template>
  <article
    class="course-card"
    :class="{ 'is-locked': !isAvailable }"
    role="button"
    tabindex="0"
    aria-label="Abrir curso {{ course.name }}"
    @click="emit('select', course.id)"
    @keyup.enter="emit('select', course.id)"
  >
    <CourseLogo :course="course" />

    <div class="course-card-body">
      <div class="course-card-head">
        <h2 class="course-card-title">{{ course.name }}</h2>
        <span class="course-badge" :class="{ 'badge-locked': !isAvailable }">
          {{ isAvailable ? 'Disponible' : 'Próximamente' }}
        </span>
      </div>
      <p class="course-card-tagline">{{ course.tagline }}</p>

      <div v-if="isAvailable" class="course-card-progress">
        <div class="k-progress">
          <i :style="{ width: course.progress + '%' }"></i>
        </div>
        <span class="course-card-percent">{{ course.progress }}%</span>
      </div>
    </div>

    <q-icon v-if="isAvailable" name="chevron_right" size="20px" class="course-card-chev" />
  </article>
</template>

<script setup>
import { computed } from 'vue'
import CourseLogo from './CourseLogo.vue'

const props = defineProps({
  course: {
    type: Object,
    required: true,
  },
})

const emit = defineEmits(['select'])

const isAvailable = computed(() => props.course.status === 'available')
</script>

<style scoped>
.course-card {
  display: flex;
  align-items: center;
  gap: var(--k-space-4);
  padding: 18px 20px;
  background: var(--k-surface-2);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius);
  cursor: pointer;
  transition:
    border-color 0.15s ease,
    transform 0.08s ease;
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
  font-size: 17px;
  font-weight: 800;
  letter-spacing: -0.01em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.course-badge {
  flex-shrink: 0;
  padding: 3px 8px;
  border-radius: 99px;
  background: var(--k-accent-soft);
  color: var(--k-accent);
  font-size: 10px;
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
