<template>
  <div class="k-screen">
    <AppHeader :title="`Unidad ${unit?.id ?? ''}`" :back="courseLink" />

    <main v-if="unit" class="k-container unit">
      <p class="k-eyebrow">Curso {{ course?.name }}</p>
      <h1 class="k-h1 unit-title">{{ unit.title }}</h1>
      <p class="k-muted unit-desc">{{ unit.description }}</p>

      <div v-if="unit.status === 'locked'" class="unit-locked-note">
        <q-icon name="lock" size="18px" />
        Completá la unidad anterior para desbloquear esta.
      </div>

      <section class="lessons">
        <p class="k-eyebrow">Clases</p>
        <div class="lessons-list">
          <button
            v-for="lesson in lessons"
            :key="lesson.id"
            type="button"
            class="lesson-row"
            :class="[`is-${lesson.status}`]"
            :disabled="lesson.status === 'locked'"
            @click="openLesson(lesson)"
          >
            <span class="lesson-icon">
              <q-icon v-if="lesson.status === 'completed'" name="check" size="18px" />
              <q-icon v-else-if="lesson.status === 'locked'" name="lock" size="15px" />
              <q-icon v-else name="play_circle_filled" size="20px" />
            </span>
            <span class="lesson-body">
              <span class="lesson-kind">{{ kindLabel(lesson.kind) }}</span>
              <span class="lesson-title">{{ lesson.title }}</span>
              <span class="lesson-meta">{{ lesson.activityIds?.length }} actividades</span>
            </span>
            <q-icon name="chevron_right" size="18px" class="lesson-chev" />
          </button>
        </div>
      </section>

      <button
        v-if="firstAvailable"
        type="button"
        class="k-btn k-btn--primary k-btn--block unit-cta"
        @click="openLesson(firstAvailable)"
      >
        <q-icon name="play_arrow" size="20px" />
        Empezar primera clase
      </button>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import { getCourse, getLessonsForUnit, getUnit, lessonRoute } from '@/services/catalog'

const route = useRoute()
const router = useRouter()

const courseId = computed(() => route.params.courseId)
const unitId = computed(() => route.params.unitId)

const unit = computed(() => getUnit(courseId.value, unitId.value))

const course = computed(() => getCourse(courseId.value))

const lessons = computed(() => (unit.value ? getLessonsForUnit(unit.value.id) : []))

const firstAvailable = computed(() =>
  unit.value ? lessons.value.find((l) => l.status === 'available') : null,
)

const courseLink = computed(() => ({ name: 'course', params: { courseId: courseId.value } }))

function kindLabel(kind) {
  return kind === 'challenge' ? 'Desafío' : 'Clase'
}

function openLesson(lesson) {
  router.push(lessonRoute(lesson.id))
}
</script>

<style scoped>
.unit-title {
  margin-top: var(--k-space-2);
}

.unit-desc {
  margin-top: var(--k-space-2);
  font-size: 14px;
  line-height: 1.5;
}

.unit-locked-note {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-4);
  padding: 12px 14px;
  border-radius: var(--k-radius-sm);
  background: var(--k-surface-2);
  border: 1px solid var(--k-line);
  color: var(--k-text-2);
  font-size: 13px;
  font-weight: 600;
}

.lessons {
  margin-top: var(--k-space-6);
}

.lessons-list {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-4);
}

.lesson-row {
  display: flex;
  align-items: center;
  gap: var(--k-space-4);
  padding: 14px 16px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  cursor: pointer;
  text-align: left;
  transition:
    border-color 0.12s ease,
    transform 0.08s ease;
  -webkit-tap-highlight-color: transparent;
}

.lesson-row:active {
  transform: scale(0.985);
}

.lesson-row:disabled {
  cursor: default;
  opacity: 0.5;
  transform: none;
}

.lesson-row.is-completed {
  border-color: rgba(52, 211, 153, 0.35);
}

.lesson-row.is-available {
  border-color: rgba(142, 5, 194, 0.55);
}

.lesson-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  flex-shrink: 0;
  border-radius: 12px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  color: var(--k-accent);
}

.lesson-row.is-completed .lesson-icon {
  color: var(--k-success);
}

.lesson-row.is-locked .lesson-icon {
  color: var(--k-text-3);
}

.lesson-body {
  flex: 1;
  min-width: 0;
  display: grid;
  gap: 2px;
}

.lesson-kind {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--k-text-3);
}

.lesson-title {
  font-size: 14.5px;
  font-weight: 700;
}

.lesson-meta {
  font-size: 12px;
  color: var(--k-text-3);
}

.lesson-chev {
  color: var(--k-text-3);
  flex-shrink: 0;
}

.unit-cta {
  margin-top: var(--k-space-6);
}
</style>
