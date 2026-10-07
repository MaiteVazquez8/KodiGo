<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Actividad" :back="linkLeccion" />

    <main class="k-container activity">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar la actividad"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'inexistente'"
        tipo="inexistente"
        titulo="Actividad no encontrada"
        mensaje="La actividad que buscás no existe o la clase ya no está disponible."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <EstadoPantalla
        v-else-if="estado === 'vacio'"
        tipo="vacio"
        titulo="Esta clase no tiene preguntas"
        mensaje="La práctica de esta clase va a estar disponible pronto."
      />

      <template v-else-if="estado === 'listo' && leccion && unidad">
        <p class="k-eyebrow">{{ tituloLeccion }}</p>

        <div v-if="total" class="activity-progress">
          <div class="k-progress">
            <i :style="{ width: porcentajeProgreso + '%' }"></i>
          </div>
          <div class="activity-progress-meta">
            <span>Pregunta {{ posicion }} de {{ total }}</span>
            <span>{{ porcentajeProgreso }}%</span>
          </div>
        </div>

        <EjecutorActividad
          :pregunta="preguntaActual"
          :corrigiendo="corrigiendo"
          :devolucion="devolucion"
          class="activity-runner-wrap"
          @comprobar="manejarComprobar"
          @siguiente="siguiente"
        />
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EjecutorActividad from '@/components/EjecutorActividad.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import {
  comprobarRespuesta,
  obtenerLeccion,
  obtenerPreguntaPorId,
  obtenerPreguntas,
  obtenerUnidadPorId,
  registrarRespuestaLeccion,
  rutaLeccion,
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
const indice = ref(0)
const corrigiendo = ref(false)
const devolucion = ref(null)

const preguntaActual = computed(() => preguntas.value[indice.value] ?? null)

const total = computed(() => preguntas.value.length)

const posicion = computed(() => (total.value ? indice.value + 1 : 0))

const porcentajeProgreso = computed(() => {
  if (!total.value) return 0
  return Math.round((posicion.value / total.value) * 100)
})

const tituloLeccion = computed(() => {
  if (!leccion.value || !unidad.value) return ''
  return `Unidad ${unidad.value.orden} · ${leccion.value.titulo}`
})

const linkLeccion = computed(() => {
  if (!leccion.value || !unidad.value) return { name: 'cursos' }
  return rutaLeccion(leccion.value, unidad.value)
})

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    let preguntaId = route.params.activityId
    let lessonId = route.params.lessonId

    // Rutas legadas: /activity/:activityId sin curso ni unidad.
    if (!lessonId) {
      const pregunta = preguntaId ? await obtenerPreguntaPorId(preguntaId) : null
      if (!pregunta) {
        estado.value = 'inexistente'
        return
      }
      lessonId = pregunta.leccionId
    }

    const dataLeccion = await obtenerLeccion(lessonId)
    if (!dataLeccion) {
      estado.value = 'inexistente'
      return
    }
    leccion.value = dataLeccion

    const dataUnidad = await obtenerUnidadPorId(dataLeccion.unidadId)
    if (!dataUnidad) {
      estado.value = 'inexistente'
      return
    }
    unidad.value = dataUnidad

    const dataPreguntas = await obtenerPreguntas(lessonId)
    preguntas.value = dataPreguntas

    if (!route.params.courseId) {
      const destino = dataPreguntas.length
        ? rutaPregunta(dataLeccion, dataUnidad, preguntaId)
        : rutaResultados(dataLeccion, dataUnidad)
      router.replace(destino)
    }

    if (!dataPreguntas.length) {
      estado.value = 'vacio'
      return
    }

    const indexEncontrado = dataPreguntas.findIndex((pregunta) => pregunta.id === preguntaId)
    indice.value = indexEncontrado === -1 ? 0 : indexEncontrado
    devolucion.value = null

    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

watch(
  () => route.params.activityId,
  () => {
    if (estado.value !== 'listo' || !preguntas.value.length) return
    const indexEncontrado = preguntas.value.findIndex(
      (pregunta) => pregunta.id === route.params.activityId,
    )
    if (indexEncontrado !== -1) {
      indice.value = indexEncontrado
      devolucion.value = null
    }
  },
)

async function manejarComprobar(opcionId) {
  if (corrigiendo.value || !preguntaActual.value) return
  corrigiendo.value = true
  devolucion.value = null
  const pregunta = preguntaActual.value
  try {
    const resultado = await comprobarRespuesta(pregunta.id, opcionId)
    registrarRespuestaLeccion(leccion.value.id, pregunta.id, resultado.correcta)
    devolucion.value = {
      estado: resultado.correcta ? 'correcta' : 'incorrecta',
      explicacion: resultado.explicacion,
    }
  } catch (error) {
    devolucion.value = {
      estado: 'error',
      mensaje: error.message,
    }
  } finally {
    corrigiendo.value = false
  }
}

function siguiente() {
  if (!leccion.value || !unidad.value) return
  if (indice.value + 1 < preguntas.value.length) {
    router.push(rutaPregunta(leccion.value, unidad.value, preguntas.value[indice.value + 1].id))
    return
  }
  router.push(rutaResultados(leccion.value, unidad.value))
}

function verCursos() {
  router.push('/courses')
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
