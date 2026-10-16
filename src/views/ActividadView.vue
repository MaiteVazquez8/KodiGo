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
        <div v-if="sinSesion" class="activity-aviso">
          Estás practicando sin iniciar sesión. Podés resolver la clase, pero este
          intento no se va a guardar.
          <RouterLink class="activity-aviso-enlace" :to="{ name: 'acceso' }">
            Entrar como invitado
          </RouterLink>
        </div>

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
  obtenerCurso,
  obtenerIntentoActivo,
  obtenerLeccion,
  obtenerPreguntaPorId,
  obtenerPreguntas,
  obtenerUnidadPorId,
  iniciarIntento,
  registrarRespuesta,
  resolverCurso,
  resolverLeccion,
  resolverUnidad,
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
const curso = ref(null)
const preguntas = ref([])
const indice = ref(0)
const corrigiendo = ref(false)
const devolucion = ref(null)
const intentoId = ref(null)
const sinSesion = ref(false)

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
  return rutaLeccion(leccion.value, unidad.value, curso.value)
})

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    const refLeccion = route.params.leccion
    const numeroPregunta = Number.parseInt(route.params.pregunta, 10)

    let dataCurso = null
    let dataUnidad = null
    let dataLeccion = null
    let indiceInicial = Number.isFinite(numeroPregunta) ? numeroPregunta - 1 : 0

    if (refLeccion && route.params.curso && route.params.unidad) {
      // Ruta canonica por slugs.
      dataCurso = await resolverCurso(route.params.curso)
      dataUnidad = dataCurso ? await resolverUnidad(dataCurso, route.params.unidad) : null
      dataLeccion = dataUnidad ? await resolverLeccion(dataUnidad, refLeccion) : null
    } else {
      // Ruta legada: /activity/:activityId o /lesson/:leccion.
      const refPregunta = route.params.activityId
      let refLeccionId = refLeccion
      if (!refLeccionId) {
        const pregunta = refPregunta ? await obtenerPreguntaPorId(refPregunta) : null
        if (!pregunta) {
          estado.value = 'inexistente'
          return
        }
        refLeccionId = pregunta.leccionId
      }
      dataLeccion = await obtenerLeccion(refLeccionId)
      if (dataLeccion) {
        dataUnidad = await obtenerUnidadPorId(dataLeccion.unidadId)
        if (dataUnidad) dataCurso = await obtenerCurso(dataUnidad.cursoId).catch(() => null)
      }
      // En la ruta legada la pregunta llega por UUID.
      if (route.params.activityId) {
        const preguntasLegadas = dataLeccion ? await obtenerPreguntas(dataLeccion.id) : []
        const pos = preguntasLegadas.findIndex((p) => p.id === route.params.activityId)
        if (pos !== -1) indiceInicial = pos
      }
    }

    if (!dataLeccion || !dataUnidad) {
      estado.value = 'inexistente'
      return
    }

    leccion.value = dataLeccion
    unidad.value = dataUnidad
    curso.value = dataCurso

    const dataPreguntas = await obtenerPreguntas(dataLeccion.id)
    preguntas.value = dataPreguntas

    // Canonicaliza la URL con slugs.
    if (dataCurso && dataPreguntas.length) {
      const destino = rutaPregunta(dataLeccion, dataUnidad, dataCurso, indiceInicial + 1)
      const esperado = destino.params
      if (
        route.params.curso !== esperado.curso ||
        route.params.unidad !== esperado.unidad ||
        route.params.leccion !== esperado.leccion ||
        route.params.pregunta !== esperado.pregunta
      ) {
        router.replace(destino)
      }
    } else if (dataCurso) {
      router.replace(rutaResultados(dataLeccion, dataUnidad, dataCurso))
    }

    if (!dataPreguntas.length) {
      estado.value = 'vacio'
      return
    }

    indice.value = Math.min(Math.max(indiceInicial, 0), dataPreguntas.length - 1)
    devolucion.value = null

    // El intento se crea una sola vez por pasada. La clave de idempotencia
    // vive en el dispositivo, asi que recargar no genera otro intento.
    const intentoExistente = obtenerIntentoActivo(dataLeccion.id)
    if (intentoExistente) {
      intentoId.value = intentoExistente
    } else {
      try {
        const intento = await iniciarIntento(dataLeccion.id)
        intentoId.value = intento.intentoId
        sinSesion.value = false
      } catch {
        // Sin sesion se puede practicar igual, pero no queda registrado.
        intentoId.value = null
        sinSesion.value = true
      }
    }

    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

watch(
  () => route.params.pregunta,
  () => {
    if (estado.value !== 'listo' || !preguntas.value.length) return
    const numero = Number.parseInt(route.params.pregunta, 10)
    if (!Number.isFinite(numero)) return
    const nuevoIndice = Math.min(Math.max(numero - 1, 0), preguntas.value.length - 1)
    if (nuevoIndice !== indice.value) {
      indice.value = nuevoIndice
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
    // Con intento abierto el servidor corrige, guarda y recalcula.
    // Sin sesion se cae a la comprobacion simple, que tampoco guarda nada.
    const resultado = intentoId.value
      ? await registrarRespuesta(intentoId.value, pregunta.id, opcionId)
      : await comprobarRespuesta(pregunta.id, opcionId)

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
    router.push(rutaPregunta(leccion.value, unidad.value, curso.value, indice.value + 2))
    return
  }
  router.push(rutaResultados(leccion.value, unidad.value, curso.value))
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

.activity-aviso {
  margin-bottom: var(--k-space-4);
  padding: var(--k-space-3) var(--k-space-4);
  border-radius: var(--k-radius-md);
  background: var(--k-surface-2);
  color: var(--k-text-2);
  font-size: 13px;
  line-height: 1.5;
}

.activity-aviso-enlace {
  display: inline-block;
  margin-left: 6px;
  color: var(--k-accent);
  font-weight: 700;
  text-decoration: underline;
}
</style>
