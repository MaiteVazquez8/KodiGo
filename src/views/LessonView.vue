<template>
  <div class="k-screen">
    <AppHeader :title="lesson?.title ?? 'Clase'" :back="unitLink" />

    <main v-if="lesson" class="k-container lesson">
      <p class="k-eyebrow">Clase · {{ unitTitle }}</p>

      <GhostBubble
        v-if="lesson.intro"
        :message="lesson.intro.message"
        ghost-size="64"
        class="lesson-bubble"
      >
        <CodeBlock v-if="lesson.intro.code" :code="lesson.intro.code" class="lesson-code" />
      </GhostBubble>

      <div class="lesson-actions">
        <button
          v-if="firstActivity"
          type="button"
          class="k-btn k-btn--primary k-btn--block k-btn--lg"
          @click="startActivities"
        >
          <q-icon name="play_arrow" size="20px" />
          {{ firstActivityLabel }}
        </button>
        <RouterLink :to="unitLink" class="k-link lesson-back">Volver a la unidad</RouterLink>
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import CodeBlock from '@/components/CodeBlock.vue'
import GhostBubble from '@/components/GhostBubble.vue'
import { getActivitiesForLesson, getLesson, getUnitById, unitRoute } from '@/services/catalog'

const route = useRoute()
const router = useRouter()

const lesson = computed(() => getLesson(route.params.lessonId))

const activities = computed(() => (lesson.value ? getActivitiesForLesson(lesson.value.id) : []))

const firstActivity = computed(() => activities.value[0] || null)

const unitLink = computed(() =>
  lesson.value ? unitRoute(lesson.value.unitId) : { name: 'courses' },
)

const unitTitle = computed(() => {
  if (!lesson.value) return ''
  const unit = getUnitById(lesson.value.unitId)
  return unit ? unit.title : ''
})

const firstActivityLabel = computed(() =>
  activities.value.length > 1 ? 'Comenzar actividades' : 'Comenzar actividad',
)

function startActivities() {
  if (firstActivity.value) {
    router.push({ name: 'activity', params: { activityId: firstActivity.value.id } })
  }
}
</script>

<style scoped>
.lesson-bubble {
  margin-top: var(--k-space-6);
}

.lesson-code {
  margin-top: var(--k-space-4);
}

.lesson-actions {
  margin-top: var(--k-space-6);
}

.lesson-back {
  display: block;
  text-align: center;
  margin-top: var(--k-space-4);
}
</style>
