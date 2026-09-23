<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Cursos" :back="true" />

    <main class="k-container courses">
      <p class="k-eyebrow">Elegí tu camino</p>
      <h1 class="k-h1 courses-title">Cursos</h1>
      <p class="k-muted courses-subtitle">
        Empezá por JavaScript: tu primera experiencia de programación.
      </p>

      <div class="course-list">
        <TarjetaCurso
          v-for="curso in cursos"
          :key="curso.id"
          :curso="curso"
          @select="abrirCurso"
        />
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import TarjetaCurso from '@/components/TarjetaCurso.vue'
import { obtenerCursos } from '@/services/catalogo'

const router = useRouter()

const cursos = computed(() => obtenerCursos())

function abrirCurso(courseId) {
  router.push({ name: 'curso', params: { courseId } })
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
  max-width: 330px;
}

.course-list {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
}
</style>
