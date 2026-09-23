<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Resultados" :back="linkUnidad" />

    <main v-if="leccion" class="k-container results">
      <div class="results-card">
        <p class="k-eyebrow">Lección {{ tituloLeccion }}</p>

        <div class="results-summary" :class="{ 'is-passed': resultados.passed }">
          <p class="results-label">{{ resultados.passed ? '¡Lección aprobada!' : 'Lección completada' }}</p>
          <h1 class="k-h1">{{ resultados.percentage }}%</h1>
          <p class="results-subtext">
            {{ resultados.correct }} de {{ resultados.total }} respuestas correctas.
          </p>
        </div>

        <div class="results-grid">
          <div class="result-tile">
            <span>Total</span>
            <strong>{{ resultados.total }}</strong>
          </div>
          <div class="result-tile">
            <span>Correctas</span>
            <strong>{{ resultados.correct }}</strong>
          </div>
          <div class="result-tile">
            <span>Incorrectas</span>
            <strong>{{ resultados.incorrect }}</strong>
          </div>
          <div class="result-tile">
            <span>Aciertos</span>
            <strong>{{ resultados.percentage }}%</strong>
          </div>
        </div>

        <div class="results-actions">
          <button type="button" class="k-btn k-btn--primary k-btn--block k-btn--lg" @click="volverUnidad">
            Volver a la unidad
          </button>
          <button type="button" class="k-btn k-btn--ghost k-btn--block" @click="reintentarLeccion">
            Intentar nuevamente
          </button>
        </div>
      </div>
    </main>

    <main v-else class="k-container lesson lesson-error">
      <div class="error-card">
        <p class="k-eyebrow">Resultado no disponible</p>
        <h1 class="k-h1">No pudimos cargar el resultado</h1>
        <p class="k-muted">La lección no existe o aún no se completó la actividad.</p>
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
import {
  obtenerActividadesPorLeccion,
  obtenerLeccion,
  obtenerResultadosLeccion,
  obtenerUnidadPorId,
  reiniciarIntentoLeccion,
  rutaUnidad,
} from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const leccion = computed(() => obtenerLeccion(route.params.lessonId))

const tituloLeccion = computed(() => {
  if (!leccion.value) return ''
  const unidad = obtenerUnidadPorId(leccion.value.unitId)
  return unidad ? `${unidad.title}` : leccion.value.title
})

const resultados = computed(() => (leccion.value ? obtenerResultadosLeccion(leccion.value.id) : { total: 0, correct: 0, incorrect: 0, percentage: 0, passed: false, completed: false }))

const linkUnidad = computed(() =>
  leccion.value ? rutaUnidad(leccion.value.unitId) : { name: 'cursos' },
)

function volverUnidad() {
  if (!leccion.value) return router.push('/courses')
  router.push(rutaUnidad(leccion.value.unitId))
}

function reintentarLeccion() {
  if (!leccion.value) return
  reiniciarIntentoLeccion(leccion.value.id)
  const primeraActividad = obtenerActividadesPorLeccion(leccion.value.id)[0]
  router.push({
    name: 'actividad-leccion',
    params: {
      courseId: obtenerUnidadPorId(leccion.value.unitId)?.courseId,
      unitId: String(leccion.value.unitId),
      lessonId: leccion.value.id,
      activityId: primeraActividad.id,
    },
  })
}
</script>

<style scoped>
.results {
  display: grid;
  place-items: center;
}

.results-card {
  width: 100%;
  max-width: 370px;
  padding: 24px 20px;
  border-radius: 22px;
  border: 1px solid var(--k-line);
  background: linear-gradient(180deg, rgba(53, 16, 71, 0.96), rgba(24, 9, 31, 0.98));
}

.results-summary {
  margin-top: var(--k-space-4);
  padding: 22px 18px;
  border-radius: 18px;
  background: rgba(142, 5, 194, 0.12);
  border: 1px solid rgba(142, 5, 194, 0.24);
  text-align: center;
}

.results-summary.is-passed {
  background: rgba(52, 211, 153, 0.12);
  border-color: rgba(52, 211, 153, 0.3);
}

.results-label {
  font-size: 14px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--k-text-2);
}

.results-summary h1 {
  margin-top: var(--k-space-2);
  font-size: 50px;
}

.results-subtext {
  margin-top: var(--k-space-2);
  font-size: 13px;
  color: var(--k-text-2);
}

.results-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.result-tile {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 16px 14px;
  border-radius: 14px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  text-align: center;
}

.result-tile span {
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
}

.result-tile strong {
  font-size: 24px;
  letter-spacing: -0.03em;
}

.results-actions {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
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
