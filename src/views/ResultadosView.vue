<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Resultados" :back="linkUnidad" />

    <main class="k-container results">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar el resultado"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'inexistente'"
        tipo="inexistente"
        titulo="Resultado no disponible"
        mensaje="La lección no existe o aún no se completó la actividad."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <template v-else-if="estado === 'listo' && leccion">
        <div class="results-card">
          <p class="k-eyebrow">Lección {{ tituloLeccion }}</p>

          <div class="results-summary" :class="{ 'is-passed': resultados.aprobada }">
            <p class="results-label">
              {{ resultados.aprobada ? '¡Lección aprobada!' : 'Lección completada' }}
            </p>
            <h1 class="k-h1">{{ resultados.porcentaje }}%</h1>
            <p class="results-subtext">
              {{ resultados.correctas }} de {{ resultados.total }} respuestas correctas.
            </p>
          </div>

          <div class="results-grid">
            <div class="result-tile">
              <span>Total</span>
              <strong>{{ resultados.total }}</strong>
            </div>
            <div class="result-tile">
              <span>Correctas</span>
              <strong>{{ resultados.correctas }}</strong>
            </div>
            <div class="result-tile">
              <span>Incorrectas</span>
              <strong>{{ resultados.incorrectas }}</strong>
            </div>
            <div class="result-tile">
              <span>Aciertos</span>
              <strong>{{ resultados.porcentaje }}%</strong>
            </div>
          </div>

          <div class="results-actions">
            <button
              type="button"
              class="k-btn k-btn--primary k-btn--block k-btn--lg"
              @click="volverUnidad"
            >
              Volver a la unidad
            </button>
            <button
              type="button"
              class="k-btn k-btn--ghost k-btn--block"
              @click="reintentarLeccion"
            >
              Intentar nuevamente
            </button>
          </div>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import {
  obtenerLeccion,
  obtenerPreguntas,
  obtenerResultadosLeccion,
  obtenerUnidadPorId,
  reiniciarIntentoLeccion,
  rutaPregunta,
  rutaResultados,
} from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const leccion = ref(null)
const unidad = ref(null)
const preguntas = ref([])
const resultados = ref(null)

const tituloLeccion = computed(() => unidad.value?.nombre ?? leccion.value?.titulo ?? '')

const linkUnidad = computed(() => {
  if (unidad.value) {
    return { name: 'unidad', params: { courseId: unidad.value.cursoId, unitId: unidad.value.id } }
  }
  return { name: 'cursos' }
})

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  const lessonId = route.params.lessonId
  try {
    if (!lessonId) {
      estado.value = 'inexistente'
      return
    }

    const dataLeccion = await obtenerLeccion(lessonId)
    if (!dataLeccion) {
      estado.value = 'inexistente'
      return
    }
    leccion.value = dataLeccion

    const dataUnidad = await obtenerUnidadPorId(dataLeccion.unidadId)
    unidad.value = dataUnidad

    const dataPreguntas = await obtenerPreguntas(lessonId)
    preguntas.value = dataPreguntas

    resultados.value = obtenerResultadosLeccion(lessonId)
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

function volverUnidad() {
  if (unidad.value) {
    router.push({
      name: 'unidad',
      params: { courseId: unidad.value.cursoId, unitId: unidad.value.id },
    })
    return
  }
  router.push('/courses')
}

function reintentarLeccion() {
  if (!leccion.value) return
  reiniciarIntentoLeccion(leccion.value.id)
  if (preguntas.value.length && unidad.value) {
    router.push(rutaPregunta(leccion.value, unidad.value, preguntas.value[0].id))
    return
  }
  if (unidad.value) {
    router.push(rutaResultados(leccion.value, unidad.value))
    return
  }
  router.push('/courses')
}

function verCursos() {
  router.push('/courses')
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
</style>
