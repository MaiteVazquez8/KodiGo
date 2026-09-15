<template>
  <div class="k-screen">
    <AppHeader title="Curso" :back="true" />

    <main v-if="course" class="k-container course">
      <section class="course-hero">
        <CourseLogo :course="course" tone="hero" />
        <h1 class="k-h1 course-hero-name">{{ course.name }}</h1>
        <p class="course-hero-tagline">{{ course.tagline }}</p>
        <p class="k-muted course-hero-desc">{{ course.description }}</p>

        <div v-if="units.length" class="course-hero-progress">
          <div class="k-progress">
            <i :style="{ width: courseProgress + '%' }"></i>
          </div>
          <div class="course-hero-meta">
            <span>{{ units.length }} unidades</span>
            <span>{{ courseProgress }}% completado</span>
          </div>
        </div>
      </section>

      <section class="units">
        <p class="k-eyebrow">Recorrido de aprendizaje</p>
        <div class="units-list">
          <UnitCard
            v-for="unit in units"
            :key="unit.id"
            :unit="unit"
            :lessons="lessonCount(unit.id)"
            @select="openUnit"
          />
        </div>
      </section>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import CourseLogo from '@/components/CourseLogo.vue'
import UnitCard from '@/components/UnitCard.vue'
import { getCourse, getLessonsForUnit, getUnitsForCourse, unitRoute } from '@/services/catalog'

const route = useRoute()
const router = useRouter()

const course = computed(() => getCourse(route.params.courseId))

const units = computed(() => (course.value ? getUnitsForCourse(course.value.id) : []))

const courseProgress = computed(() => {
  if (!units.value.length) return 0
  const total = units.value.reduce((sum, unit) => sum + unit.progress, 0)
  return Math.round(total / units.value.length)
})

function lessonCount(unitId) {
  return getLessonsForUnit(unitId).length
}

function openUnit(unitId) {
  router.push(unitRoute(unitId))
}
</script>

<style scoped>
.course-hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 16px 0 0;
}

.course-hero-name {
  margin-top: var(--k-space-4);
}

.course-hero-tagline {
  margin-top: var(--k-space-2);
  font-size: 14px;
  font-weight: 700;
  color: var(--k-text-2);
}

.course-hero-desc {
  margin-top: var(--k-space-2);
  max-width: 320px;
  font-size: 13.5px;
  line-height: 1.5;
}

.course-hero-progress {
  width: 100%;
  max-width: 300px;
  margin-top: var(--k-space-6);
}

.course-hero-meta {
  display: flex;
  justify-content: space-between;
  margin-top: var(--k-space-2);
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
}

.units {
  margin-top: var(--k-space-6);
}

.units-list {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-4);
}
</style>
