<template>
  <div class="k-screen">
    <EncabezadoApp :titulo="leccion?.title ?? 'Lección'" :back="linkUnidad" />

    <main v-if="leccion" class="k-container lesson">
      <p class="k-eyebrow">Clase · {{ tituloUnidad }}</p>

      <BurbujaFantasma :mensaje="leccion.explanation" :tamano-fantasma="64" class="lesson-bubble">
        <BloqueCodigo v-if="leccion.exampleCode" :code="leccion.exampleCode" class="lesson-code" />
      </BurbujaFantasma>

      <div class="lesson-actions">
        <button
          v-if="primeraActividad"
          type="button"
          class="k-btn k-btn--primary k-btn--block k-btn--lg"
          @click="iniciarActividades"
        >
          <q-icon name="play_arrow" size="20px" />
          {{ etiquetaPrimeraActividad }}
        </button>
        <RouterLink :to="linkUnidad" class="k-link lesson-back">Volver a la unidad</RouterLink>
      </div>
    </main>

    <main v-else class="k-container lesson lesson-error">
      <div class="error-card">
        <p class="k-eyebrow">Lección no encontrada</p>
        <h1 class="k-h1">No pudimos abrir esta lección</h1>
        <p class="k-muted">La ruta solicitada no existe o ya no está disponible.</p>
        <RouterLink to="/courses" class="k-btn k-btn--primary k-btn--block k-btn--lg error-button">
          Volver a cursos
        </RouterLink>
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import BloqueCodigo from '@/components/BloqueCodigo.vue'
import BurbujaFantasma from '@/components/BurbujaFantasma.vue'
import {
  rutaActividad,
  obtenerActividadesPorLeccion,
  obtenerLeccion,
  obtenerEstadoLeccion,
  obtenerUnidadPorId,
  rutaUnidad,
} from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const leccion = computed(() => obtenerLeccion(route.params.lessonId))

const actividades = computed(() => (leccion.value ? obtenerActividadesPorLeccion(leccion.value.id) : []))

const primeraActividad = computed(() => actividades.value[0] || null)

const estadoLeccion = computed(() => (leccion.value ? obtenerEstadoLeccion(leccion.value.id) : 'locked'))

const linkUnidad = computed(() =>
  leccion.value ? rutaUnidad(leccion.value.unitId) : { name: 'cursos' },
)

const tituloUnidad = computed(() => {
  if (!leccion.value) return ''
  const unidad = obtenerUnidadPorId(leccion.value.unitId)
  return unidad ? unidad.title : ''
})

const etiquetaPrimeraActividad = computed(() =>
  actividades.value.length > 1 ? 'Comenzar actividades' : 'Comenzar actividad',
)

function iniciarActividades() {
  if (!leccion.value || estadoLeccion.value === 'locked' || !primeraActividad.value) return
  router.push(rutaActividad(leccion.value.id, primeraActividad.value.id))
}
</script>

<style scoped>
.lesson {
  display: block;
}

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

.lesson-error {
  display: grid;
  place-items: center;
}

.error-card {
  width: 100%;
  max-width: 360px;
  padding: 28px 22px;
  border-radius: var(--k-radius);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  text-align: center;
}

.error-card h1 {
  margin-top: var(--k-space-3);
}

.error-card p {
  margin-top: var(--k-space-3);
}

.error-button {
  margin-top: var(--k-space-5);
}
</style>
