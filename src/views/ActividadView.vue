<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Actividad" :back="linkLeccion" />

    <main v-if="actividad && leccion" class="k-container activity">
      <p class="k-eyebrow">{{ tituloLeccion }}</p>

      <div class="activity-progress">
        <div class="k-progress">
          <i :style="{ width: porcentajeProgreso + '%' }"></i>
        </div>
        <div class="activity-progress-meta">
          <span>Actividad {{ posicion }} de {{ total }}</span>
          <span>{{ porcentajeProgreso }}%</span>
        </div>
      </div>

      <EjecutorActividad
        :actividad="actividad"
        class="activity-runner-wrap"
        @submit="manejarEnvio"
        @next="siguiente"
      />
    </main>

    <main v-else class="k-container lesson lesson-error">
      <div class="error-card">
        <p class="k-eyebrow">Actividad no encontrada</p>
        <h1 class="k-h1">No pudimos abrir esta actividad</h1>
        <p class="k-muted">La actividad solicitada no existe o la lección ya no está disponible.</p>
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
import EjecutorActividad from '@/components/EjecutorActividad.vue'
import {
  rutaActividad,
  obtenerActividadesPorLeccion,
  obtenerActividad,
  obtenerLeccion,
  obtenerResultadosLeccion,
  obtenerUnidadPorId,
  rutaLeccion,
  registrarRespuestaLeccion,
  reiniciarIntentoLeccion,
  rutaUnidad,
} from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const actividad = computed(() => {
  const activityId = route.params.activityId
  return obtenerActividad(activityId)
})

const leccion = computed(() => (actividad.value ? obtenerLeccion(actividad.value.lessonId) : null))

const actividades = computed(() =>
  actividad.value ? obtenerActividadesPorLeccion(actividad.value.lessonId) : [],
)

const posicion = computed(() => {
  const index = actividades.value.findIndex((a) => a.id === actividad.value?.id)
  return index === -1 ? 0 : index + 1
})

const total = computed(() => actividades.value.length)

const porcentajeProgreso = computed(() => {
  if (!total.value) return 0
  return Math.round((posicion.value / total.value) * 100)
})

const tituloLeccion = computed(() => {
  if (!leccion.value) return ''
  const unidad = obtenerUnidadPorId(leccion.value.unitId)
  return unidad ? `Unidad ${unidad.id} · ${leccion.value.title}` : leccion.value.title
})

const linkLeccion = computed(() =>
  leccion.value ? rutaLeccion(leccion.value.id) : { name: 'cursos' },
)

const resultadosActuales = computed(() => (leccion.value ? obtenerResultadosLeccion(leccion.value.id) : null))

function manejarEnvio(esCorrecto) {
  if (!leccion.value || !actividad.value) return
  registrarRespuestaLeccion(leccion.value.id, actividad.value.id, esCorrecto)
}

function siguiente() {
  if (!leccion.value || !actividad.value) return

  const siguienteIndex = actividades.value.findIndex((a) => a.id === actividad.value?.id) + 1
  const siguienteActividad = actividades.value[siguienteIndex]

  if (siguienteActividad) {
    router.push(rutaActividad(leccion.value.id, siguienteActividad.id))
    return
  }

  const rutaResultados = {
    name: 'resultados-leccion',
    params: {
      courseId: leccion.value.unitId ? obtenerUnidadPorId(leccion.value.unitId)?.courseId : undefined,
      unitId: String(leccion.value.unitId),
      lessonId: leccion.value.id,
    },
  }

  if (rutaResultados.params.courseId) {
    router.push(rutaResultados)
    return
  }

  router.push(rutaUnidad(leccion.value.unitId))
}

function reintentarLeccion() {
  if (!leccion.value) return
  reiniciarIntentoLeccion(leccion.value.id)
  const primeraActividad = obtenerActividadesPorLeccion(leccion.value.id)[0]
  if (primeraActividad) {
    router.push(rutaActividad(leccion.value.id, primeraActividad.id))
  } else {
    router.push(rutaUnidad(leccion.value.unitId))
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
