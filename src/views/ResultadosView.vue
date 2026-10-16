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
        <div class="results-cabecera">
          <button type="button" class="results-volver" aria-label="Volver" @click="volverUnidad">
            <q-icon name="arrow_back" size="20px" />
          </button>
          <h1 class="results-titulo-cabecera">
            {{ resultados.aprobada ? 'Clase Completada' : tituloLeccion }}
          </h1>
          <span class="results-racha">
            <q-icon name="local_fire_department" size="17px" />
            {{ rachaDias }}d
          </span>
        </div>

        <div class="results-cabecera-barra">
          <div class="k-progress">
            <i :style="{ width: progresoBarra + '%' }"></i>
          </div>
        </div>

        <section class="results-cuerpo">
          <div class="results-check" :class="{ 'es-aprobada': resultados.aprobada }">
            <q-icon :name="resultados.aprobada ? 'check' : 'close'" size="34px" />
          </div>

          <p class="results-titulo k-h1">
            {{ resultados.aprobada ? '¡Excelente Trabajo!' : 'Casi lo tenés' }}
          </p>
          <p class="results-subtitulo">
            {{
              resultados.aprobada
                ? `Has completado el ejercicio correctamente.`
                : `Respondiste ${resultados.correctas} de ${resultados.total} correctamente.`
            }}
          </p>

          <div class="results-grid">
            <div class="result-tile">
              <span>PRECISIÓN</span>
              <strong :class="{ 'es-acento': resultados.aprobada }">
                {{ resultados.porcentaje }}%
              </strong>
            </div>
            <div class="result-tile">
              <span>RESPUESTAS</span>
              <strong>{{ resultados.correctas }} / {{ resultados.total }}</strong>
            </div>
            <div class="result-tile">
              <span>TOTAL XP GANADO</span>
              <strong class="es-acento">+{{ xpGanado }} XP</strong>
            </div>
          </div>

          <section v-if="resultados.aprobada" class="results-recompensa">
            <q-icon name="workspace_premium" size="20px" />
            <p>
              +{{ xpGanado }} Puntos de Experiencia (XP). ¡Mantenés tu racha diaria de
              {{ rachaDias }} días activa!
            </p>
          </section>

          <section v-if="resultados.aprobada && tituloUnidad" class="results-progreso">
            <p class="results-progreso-titulo">Progreso de Unidad {{ numeroUnidad }}</p>
            <div class="k-progress results-barra">
              <i :style="{ width: progresoUnidad + '%' }"></i>
            </div>
            <p class="results-progreso-detalle">
              {{ clasesCompletadas }} de {{ clasesTotales }} Clases
            </p>
          </section>
        </section>

        <div class="results-actions">
          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            @click="siguienteLeccion"
          >
            {{ siguienteDisponible ? 'SIGUIENTE LECCIÓN' : 'VOLVER AL MAPA' }}
          </button>
          <button type="button" class="k-btn k-btn--ghost k-btn--block" @click="reintentarLeccion">
            REPETIR EJERCICIO
          </button>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import {
  finalizarIntento,
  obtenerCurso,
  obtenerIntentoActivo,
  obtenerLecciones,
  obtenerLeccion,
  obtenerPreguntas,
  obtenerResultadosLeccion,
  obtenerUnidadPorId,
  resolverCurso,
  resolverLeccion,
  resolverUnidad,
  reiniciarIntentoLeccion,
  rutaLeccion,
  rutaPregunta,
  rutaResultados,
  rutaUnidad,
} from '@/services/catalogo'
import { estado as estadoAuth, refrescarPerfil } from '@/services/auth'

const route = useRoute()
const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const leccion = ref(null)
const unidad = ref(null)
const curso = ref(null)
const preguntas = ref([])
const resultados = ref(null)
const leccionesUnidad = ref([])

const tituloLeccion = computed(() => unidad.value?.nombre ?? leccion.value?.titulo ?? '')
const tituloUnidad = computed(() => unidad.value?.nombre ?? '')
const numeroUnidad = computed(() => unidad.value?.orden ?? 1)
const rachaDias = computed(() => estadoAuth.perfil?.racha_dias ?? 0)

// El XP es el que confirmo el servidor al cerrar el intento. Calcularlo aca
// mostraria una cifra que el servidor podria no haber otorgado (por ejemplo
// si la leccion ya estaba aprobada y no correspondia repetir la recompensa).
const xpGanado = computed(() => Number(resultados.value?.xpGanado ?? 0))

const clasesTotales = computed(
  () => leccionesUnidad.value.filter((l) => l.estado !== 'bloqueada').length,
)
const clasesCompletadas = computed(
  () => leccionesUnidad.value.filter((l) => ['completada', 'aprobada'].includes(l.estado)).length,
)
const progresoUnidad = computed(() => {
  if (!clasesTotales.value) return 0
  return Math.round((clasesCompletadas.value / clasesTotales.value) * 100)
})

// La barra superior avanza con el avance dentro de la unidad.
const progresoBarra = computed(() => progresoUnidad.value)

const leccionSiguiente = computed(() => {
  if (!leccion.value) return null
  const indice = leccionesUnidad.value.findIndex((l) => l.id === leccion.value.id)
  if (indice === -1) return null
  return leccionesUnidad.value.slice(indice + 1).find((l) => l.estado !== 'bloqueada') ?? null
})
const siguienteDisponible = computed(() => Boolean(leccionSiguiente.value))

const linkUnidad = computed(() => {
  if (unidad.value) {
    return { name: 'unidad', params: { courseId: unidad.value.cursoId, unitId: unidad.value.id } }
  }
  return { name: 'cursos' }
})

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  const refLeccion = route.params.leccion
  try {
    if (!refLeccion) {
      estado.value = 'inexistente'
      return
    }

    let dataCurso = null
    let dataUnidad = null
    let dataLeccion = null

    if (route.params.curso && route.params.unidad) {
      dataCurso = await resolverCurso(route.params.curso)
      dataUnidad = dataCurso ? await resolverUnidad(dataCurso, route.params.unidad) : null
      dataLeccion = dataUnidad ? await resolverLeccion(dataUnidad, refLeccion) : null
    } else {
      dataLeccion = await obtenerLeccion(refLeccion)
      if (dataLeccion) {
        dataUnidad = await obtenerUnidadPorId(dataLeccion.unidadId)
        if (dataUnidad) dataCurso = await obtenerCurso(dataUnidad.cursoId).catch(() => null)
      }
    }

    if (!dataLeccion) {
      estado.value = 'inexistente'
      return
    }

    leccion.value = dataLeccion
    unidad.value = dataUnidad
    curso.value = dataCurso

    const dataPreguntas = await obtenerPreguntas(dataLeccion.id)
    preguntas.value = dataPreguntas

    if (dataUnidad) {
      leccionesUnidad.value = await obtenerLecciones(dataUnidad.id)
    }

    // Cierra el intento: el servidor calcula el resultado, actualiza el
    // progreso de la leccion y otorga la experiencia. Si el intento ya
    // estaba cerrado devuelve lo mismo sin duplicar nada.
    const intentoId = obtenerIntentoActivo(dataLeccion.id)
    if (intentoId) {
      resultados.value = await finalizarIntento(intentoId)
      // El XP quedo guardado en perfiles: se relee para que la pantalla y el
      // perfil muestren el valor persistido y no el anterior.
      await refrescarPerfil()
    } else {
      resultados.value = obtenerResultadosLeccion(dataLeccion.id)
    }
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

function siguienteLeccion() {
  if (leccionSiguiente.value && unidad.value) {
    router.push(rutaLeccion(leccionSiguiente.value, unidad.value, curso.value))
    return
  }
  volverUnidad()
}

function volverUnidad() {
  if (unidad.value) {
    router.push(rutaUnidad(unidad.value, curso.value))
    return
  }
  router.push('/courses')
}

function reintentarLeccion() {
  if (!leccion.value) return
  reiniciarIntentoLeccion(leccion.value.id)
  if (preguntas.value.length && unidad.value) {
    router.push(rutaPregunta(leccion.value, unidad.value, curso.value, 1))
    return
  }
  if (unidad.value) {
    router.push(rutaResultados(leccion.value, unidad.value, curso.value))
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
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.results-cabecera {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
}

.results-volver {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  flex-shrink: 0;
  border-radius: 12px;
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.results-titulo-cabecera {
  flex: 1;
  min-width: 0;
  font-family: var(--k-font-brand);
  font-size: 21px;
  font-weight: 800;
  letter-spacing: -0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.results-racha {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
  padding: 5px 10px;
  border-radius: 999px;
  border: 1px solid rgba(142, 5, 194, 0.35);
  font-size: 12px;
  font-weight: 800;
}

.results-racha .q-icon {
  color: var(--k-accent);
}

.results-cabecera-barra {
  margin-top: var(--k-space-4);
}

.results-cabecera-barra .k-progress {
  background: rgba(255, 255, 255, 0.12);
}

.results-cuerpo {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-top: var(--k-space-6);
  text-align: center;
}

.results-check {
  width: 84px;
  height: 84px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.07);
  border: 1px solid var(--k-line);
  color: var(--k-text-2);
}

.results-check.es-aprobada {
  background: linear-gradient(180deg, #9d2ad8 0%, #7f00c7 100%);
  border-color: transparent;
  color: #fff;
}

.results-titulo {
  margin-top: var(--k-space-5);
}

.results-subtitulo {
  margin-top: var(--k-space-3);
  max-width: 320px;
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.results-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--k-space-3);
  width: 100%;
  margin-top: var(--k-space-6);
}

.result-tile {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  background: var(--k-surface-2);
  border: 1px solid var(--k-line);
  text-align: left;
}

.result-tile span {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: var(--k-text-3);
}

.result-tile strong {
  font-size: 19px;
  font-weight: 800;
}

.result-tile strong.es-acento {
  color: var(--k-accent);
}

.results-recompensa {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  width: 100%;
  margin-top: var(--k-space-4);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(142, 5, 194, 0.35);
  background: var(--k-accent-softer);
  text-align: left;
}

.results-recompensa .q-icon {
  color: var(--k-accent);
  flex-shrink: 0;
}

.results-recompensa p {
  font-size: 13px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.results-progreso {
  width: 100%;
  margin-top: var(--k-space-4);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  text-align: left;
}

.results-progreso-titulo {
  font-size: 14px;
  font-weight: 800;
}

.results-barra {
  margin-top: var(--k-space-3);
  background: rgba(255, 255, 255, 0.12);
}

.results-progreso-detalle {
  margin-top: var(--k-space-2);
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-2);
}

.results-actions {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-6);
}
</style>
