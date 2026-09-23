<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Curso" :back="true" />

    <main v-if="curso" class="k-container course">
      <section class="course-hero">
        <LogoCurso :curso="curso" tone="hero" />
        <h1 class="k-h1 course-hero-name">{{ curso.name }}</h1>
        <p class="course-hero-tagline">{{ curso.tagline }}</p>
        <p class="k-muted course-hero-desc">{{ curso.description }}</p>

        <div v-if="unidades.length" class="course-hero-progress">
          <div class="k-progress">
            <i :style="{ width: progresoCurso + '%' }"></i>
          </div>
          <div class="course-hero-meta">
            <span>{{ unidades.length }} unidades</span>
            <span>{{ progresoCurso }}% completado</span>
          </div>
        </div>
      </section>

      <section class="units">
        <p class="k-eyebrow">Recorrido de aprendizaje</p>
        <div class="units-list">
          <TarjetaUnidad
            v-for="unidad in unidades"
            :key="unidad.id"
            :unidad="unidad"
            :lessons="contarLecciones(unidad.id)"
            @select="abrirUnidad"
          />
        </div>
      </section>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import LogoCurso from '@/components/LogoCurso.vue'
import TarjetaUnidad from '@/components/TarjetaUnidad.vue'
import { obtenerCurso, obtenerLeccionesPorUnidad, obtenerUnidadesPorCurso, rutaUnidad } from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const curso = computed(() => obtenerCurso(route.params.courseId))

const unidades = computed(() => (curso.value ? obtenerUnidadesPorCurso(curso.value.id) : []))

const progresoCurso = computed(() => {
  if (!unidades.value.length) return 0
  const total = unidades.value.reduce((sum, unidad) => sum + unidad.progress, 0)
  return Math.round(total / unidades.value.length)
})

function contarLecciones(unidadId) {
  return obtenerLeccionesPorUnidad(unidadId).length
}

function abrirUnidad(unidadId) {
  router.push(rutaUnidad(unidadId))
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
