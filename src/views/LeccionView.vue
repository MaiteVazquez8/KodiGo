<template>
  <div class="k-screen">
    <EncabezadoApp :titulo="leccion?.titulo ?? 'Lección'" :back="linkUnidad" />

    <main class="k-container lesson">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar la lección"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'inexistente'"
        tipo="inexistente"
        titulo="Lección no encontrada"
        mensaje="La lección que buscás no existe o ya no está disponible."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <template v-else-if="estado === 'listo' && leccion && unidad">
        <p class="k-eyebrow">Clase · {{ tituloUnidad }}</p>

        <BurbujaFantasma :mensaje="leccion.explicacion" :tamano-fantasma="64" class="lesson-bubble">
          <BloqueCodigo
            v-if="leccion.ejemploCodigo"
            :code="leccion.ejemploCodigo"
            class="lesson-code"
          />
        </BurbujaFantasma>

        <div v-if="estadoLeccion === 'bloqueada'" class="lesson-locked-note">
          <q-icon name="lock" size="18px" />
          Completá la clase anterior para desbloquear esta.
        </div>

        <div v-else class="lesson-actions">
          <button
            v-if="hayPreguntas"
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            @click="iniciarPractica"
          >
            <q-icon name="play_arrow" size="20px" />
            Comenzar actividad
          </button>

          <EstadoPantalla
            v-else
            tipo="vacio"
            titulo="Esta clase aún no tiene preguntas"
            mensaje="La práctica de esta clase va a estar disponible pronto."
          />

          <RouterLink :to="linkUnidad" class="k-link lesson-back">Volver a la unidad</RouterLink>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import BloqueCodigo from '@/components/BloqueCodigo.vue'
import BurbujaFantasma from '@/components/BurbujaFantasma.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import {
  obtenerLeccion,
  obtenerLecciones,
  obtenerPreguntas,
  obtenerUnidadPorId,
  rutaLeccion,
  rutaPregunta,
} from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const leccion = ref(null)
const unidad = ref(null)
const preguntas = ref([])
const estadoLeccion = ref('disponible')

const linkUnidad = computed(() => {
  if (leccion.value && unidad.value) {
    return {
      name: 'unidad',
      params: { courseId: unidad.value.cursoId, unitId: unidad.value.id },
    }
  }
  return { name: 'cursos' }
})

const tituloUnidad = computed(() => unidad.value?.nombre ?? '')

const hayPreguntas = computed(() => preguntas.value.length > 0)

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
    if (!dataUnidad) {
      estado.value = 'inexistente'
      return
    }
    unidad.value = dataUnidad

    // Rutas legadas: /lesson/:lessonId redirige a la ruta canónica.
    if (!route.params.courseId) {
      router.replace(rutaLeccion(dataLeccion, dataUnidad))
    }

    const dataPreguntas = await obtenerPreguntas(lessonId)
    preguntas.value = dataPreguntas

    const leccionesUnidad = await obtenerLecciones(dataUnidad.id)
    const propia = leccionesUnidad.find((l) => l.id === dataLeccion.id)
    estadoLeccion.value = propia?.estado ?? dataLeccion.estado
    if (estadoLeccion.value === 'aprobada') estadoLeccion.value = 'completada'

    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

function iniciarPractica() {
  if (!leccion.value || !unidad.value || !preguntas.value.length) return
  router.push(rutaPregunta(leccion.value, unidad.value, preguntas.value[0].id))
}

function verCursos() {
  router.push('/courses')
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
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
}

.lesson-back {
  display: block;
  text-align: center;
}

.lesson-locked-note {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-6);
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(142, 5, 194, 0.08);
  border: 1px solid rgba(142, 5, 194, 0.22);
  color: var(--k-text-2);
  font-size: 13px;
  font-weight: 600;
}
</style>
