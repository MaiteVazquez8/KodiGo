<template>
  <div class="k-screen">
    <AppHeader brand />

    <main class="k-container home">
      <section class="hero">
        <KodigoGhost :size="112" variant="happy" class="hero-ghost" />
        <p class="hero-wordmark k-font-brand">Kodigo</p>
        <p class="hero-tagline">Aprendé a programar paso a paso.</p>
        <div class="hero-stats">
          <span class="hero-stat">
            <q-icon name="bolt" size="16px" />
            120 XP
          </span>
          <span class="hero-stat">
            <q-icon name="local_fire_department" size="16px" />
            Racha 3
          </span>
        </div>
      </section>

      <GhostBubble :message="welcomeMessage" ghost-size="60" mood="happy" class="home-bubble" />

      <div class="home-actions">
        <button
          type="button"
          class="k-btn k-btn--primary k-btn--block k-btn--lg"
          :disabled="!nextLesson"
          @click="continueLearning"
        >
          {{ nextLesson ? 'Continuar aprendiendo' : 'Empezar a aprender' }}
        </button>
        <RouterLink to="/courses" class="k-btn k-btn--ghost k-btn--block"
          >Ver todos los cursos</RouterLink
        >
      </div>

      <CourseCard v-if="javascriptCourse" :course="javascriptCourse" @select="openCourse" />
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import GhostBubble from '@/components/GhostBubble.vue'
import KodigoGhost from '@/components/KodigoGhost.vue'
import CourseCard from '@/components/CourseCard.vue'
import { getCourse, getFirstAvailableLesson, lessonRoute } from '@/services/catalog'

const router = useRouter()

const js = 'javascript'

const welcomeMessage =
  '¡Hola! Soy el fantasma de Kodigo. ¿Listo para escribir tu primer código en JavaScript?'

const javascriptCourse = computed(() => getCourse(js))

const nextLesson = computed(() => getFirstAvailableLesson(js))

function continueLearning() {
  if (!nextLesson.value) {
    router.push('/courses')
    return
  }
  router.push(lessonRoute(nextLesson.value.id))
}

function openCourse() {
  router.push({ name: 'course', params: { courseId: js } })
}
</script>

<style scoped>
.hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 24px 0 0;
  text-align: center;
}

.hero-wordmark {
  margin-top: var(--k-space-2);
  font-size: 40px;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
}

.hero-tagline {
  margin-top: var(--k-space-2);
  font-size: 15px;
  font-weight: 600;
  color: var(--k-text-2);
}

.hero-stats {
  display: flex;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.hero-stat {
  display: inline-flex;
  align-items: center;
  gap: var(--k-space-2);
  padding: 7px 12px;
  border-radius: 99px;
  background: var(--k-surface-2);
  border: 1px solid var(--k-line);
  color: var(--k-text-2);
  font-size: 12.5px;
  font-weight: 700;
}

.hero-stat .q-icon {
  color: var(--k-accent);
}

.home-bubble {
  margin-top: var(--k-space-6);
}

.home-actions {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
}
</style>
