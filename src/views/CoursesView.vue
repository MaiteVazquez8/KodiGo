<template>
  <div class="k-screen">
    <AppHeader title="Cursos" :back="true" />

    <main class="k-container courses">
      <p class="k-eyebrow">Elegí tu camino</p>
      <h1 class="k-h1 courses-title">Cursos</h1>
      <p class="k-muted courses-subtitle">
        Empezá por JavaScript: tu primera experiencia de programación.
      </p>

      <div class="course-list">
        <CourseCard
          v-for="course in courses"
          :key="course.id"
          :course="course"
          @select="openCourse"
        />
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import CourseCard from '@/components/CourseCard.vue'
import { getCourses } from '@/services/catalog'

const router = useRouter()

const courses = computed(() => getCourses())

function openCourse(courseId) {
  router.push({ name: 'course', params: { courseId } })
}
</script>

<style scoped>
.courses-title {
  margin-top: var(--k-space-2);
}

.courses-subtitle {
  margin-top: var(--k-space-2);
  font-size: 14px;
  line-height: 1.5;
}

.course-list {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
}
</style>
