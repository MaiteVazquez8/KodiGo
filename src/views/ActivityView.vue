<template>
  <div class="k-screen">
    <AppHeader title="Actividad" :back="lessonLink" />

    <main v-if="activity && lesson" class="k-container activity">
      <p class="k-eyebrow">{{ lessonTitle }}</p>

      <div class="activity-progress">
        <div class="k-progress">
          <i :style="{ width: progressPct + '%' }"></i>
        </div>
        <div class="activity-progress-meta">
          <span>Actividad {{ position }} de {{ total }}</span>
          <span>{{ progressPct }}%</span>
        </div>
      </div>

      <ActivityRunner :activity="activity" class="activity-runner-wrap" @next="goNext" />
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import ActivityRunner from '@/components/ActivityRunner.vue'
import {
  getActivitiesForLesson,
  getActivity,
  getLesson,
  getUnitById,
  lessonRoute,
} from '@/services/catalog'

const route = useRoute()
const router = useRouter()

const activity = computed(() => getActivity(route.params.activityId))

const lesson = computed(() => (activity.value ? getLesson(activity.value.lessonId) : null))

const activities = computed(() =>
  activity.value ? getActivitiesForLesson(activity.value.lessonId) : [],
)

const position = computed(() => {
  const index = activities.value.findIndex((a) => a.id === activity.value?.id)
  return index === -1 ? 0 : index + 1
})

const total = computed(() => activities.value.length)

const progressPct = computed(() => {
  if (!total.value) return 0
  return Math.round((position.value / total.value) * 100)
})

const lessonTitle = computed(() => {
  if (!lesson.value) return ''
  const unit = getUnitById(lesson.value.unitId)
  return unit ? `Unidad ${unit.id} · ${lesson.value.title}` : lesson.value.title
})

const lessonLink = computed(() =>
  lesson.value ? lessonRoute(lesson.value.id) : { name: 'courses' },
)

function goNext() {
  const nextIndex = activities.value.findIndex((a) => a.id === activity.value?.id) + 1
  const nextActivity = activities.value[nextIndex]
  if (nextActivity) {
    router.push({ name: 'activity', params: { activityId: nextActivity.id } })
  } else {
    router.push(lessonLink.value)
  }
}
</script>

<style scoped>
.activity-progress {
  margin-top: var(--k-space-4);
}

.activity-progress-meta {
  display: flex;
  justify-content: space-between;
  margin-top: var(--k-space-2);
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
}

.activity-runner-wrap {
  margin-top: var(--k-space-6);
}
</style>
