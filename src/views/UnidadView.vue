<template>
  <div class="k-screen">
    <main class="k-container unit">
      <EstadoPantalla v-if="estadoCarga === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estadoCarga === 'error'"
        tipo="error"
        titulo="No pudimos cargar la unidad"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estadoCarga === 'inexistente'"
        tipo="inexistente"
        titulo="Unidad no encontrada"
        mensaje="La unidad que buscás no existe o ya no está disponible."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <template v-else-if="estadoCarga === 'listo' && unidad">
        <div class="unit-barra">
          <button type="button" class="unit-boton-volver" aria-label="Volver" @click="volver">
            <IconoArrowLeft :size="20" />
          </button>
          <span class="unit-racha" aria-label="Racha actual">
            <q-icon name="local_fire_department" size="17px" />
            {{ rachaDias }}d
          </span>
        </div>

        <CaminoUnidad
          v-if="estadoLecciones !== 'vacio'"
          :lecciones="lecciones"
          :unidad="unidad"
          :orden="unidad.orden"
          :mensaje="mensajeGuida"
          @abrir="abrirLeccion"
        />
        <EstadoPantalla
          v-else
          tipo="vacio"
          titulo="Esta unidad aún no tiene clases"
          mensaje="Las clases publicadas van a aparecer acá."
        />

        <button
          v-if="primeraDisponible && unidad.estado !== 'bloqueada'"
          type="button"
          class="k-btn k-btn--primary k-btn--block unit-cta"
          :aria-label="todasVistas ? 'Repasar las clases de esta unidad' : hayCompletadas ? 'Comenzar la próxima clase' : 'Comenzar la primera clase'"
          @click="abrirLeccion(primeraDisponible)"
        >
          {{ todasVistas ? 'REPASAR CAMINO' : hayCompletadas ? 'COMENZAR SIGUIENTE CLASE' : 'COMENZAR PRIMERA CLASE' }}
        </button>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import CaminoUnidad from '@/components/CaminoUnidad.vue'
import IconoArrowLeft from '@/components/IconoArrowLeft.vue'
import {
  aSlug,
  obtenerLecciones,
  resolverCurso,
  resolverUnidad,
  rutaLeccion,
  rutaUnidad,
} from '@/services/catalogo'
import { estado as estadoAuth } from '@/services/auth'

const route = useRoute()
const router = useRouter()

const estadoCarga = ref('cargando')
const estadoLecciones = ref('cargando')
const mensajeError = ref('')
const unidad = ref(null)
const curso = ref(null)
const lecciones = ref([])

const rachaDias = computed(() => estadoAuth.perfil?.racha_dias ?? 0)

const hayCompletadas = computed(() =>
  lecciones.value.some((l) => ['completada', 'aprobada'].includes(l.estado)),
)

const todasVistas = computed(
  () =>
    lecciones.value.length > 0 &&
    lecciones.value.every((l) => ['completada', 'aprobada'].includes(l.estado)),
)

const linkCurso = computed(() =>
  curso.value ? { name: 'curso', params: { curso: aSlug(curso.value.nombre) } } : { name: 'learn' },
)

const mensajeGuida = computed(() => {
  if (unidad.value?.estado === 'bloqueada') return 'El camino está en pausa: completá la unidad anterior para seguir avanzando.'
  const todosVistos =
    lecciones.value.length > 0 &&
    lecciones.value.every((l) => ['completada', 'aprobada'].includes(l.estado))
  if (todosVistos) {
    return 'Terminaste el camino de esta unidad: ¡elegí una clase para repasarla cuando quieras!'
  }
  return 'Seguí el camino: la próxima clase es la tuya.'
})

// El CTA quiere decir "siguiente clase pendiente". Si la lección 1 ya está
// aprobada, abrirla de nuevo sería un paso atrás: se prefiere la primera
// lección disponible (no completada ni bloqueada) y, si no hay ninguna, se
// cae a cualquier no bloqueada para repasar.
const primeraDisponible = computed(
  () =>
    lecciones.value.find((l) => l.estado === 'disponible') ??
    lecciones.value.find((l) => l.estado !== 'bloqueada') ??
    null,
)

async function cargar() {
  estadoCarga.value = 'cargando'
  estadoLecciones.value = 'cargando'
  mensajeError.value = ''
  try {
    const dataCurso = await resolverCurso(route.params.curso)
    if (!dataCurso) {
      estadoCarga.value = 'inexistente'
      return
    }
    curso.value = dataCurso

    const dataUnidad = await resolverUnidad(dataCurso, route.params.unidad)
    if (!dataUnidad) {
      estadoCarga.value = 'inexistente'
      return
    }
    unidad.value = dataUnidad

    // Canonicaliza la URL si se entró con UUID.
    if (route.params.curso !== aSlug(dataCurso.nombre) || route.params.unidad !== aSlug(dataUnidad.nombre)) {
      router.replace(rutaUnidad(dataUnidad, dataCurso))
    }

    const dataLecciones = await obtenerLecciones(dataUnidad.id)
    lecciones.value = dataLecciones
    estadoLecciones.value = dataLecciones.length ? 'listo' : 'vacio'
    estadoCarga.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estadoCarga.value = 'error'
  }
}

onMounted(cargar)

function abrirLeccion(leccion) {
  if (!curso.value || !unidad.value) return
  router.push(rutaLeccion(leccion, unidad.value, curso.value))
}

function volver() {
  router.push(linkCurso.value)
}

function verCursos() {
  router.push('/courses')
}
</script>

<style scoped>
.unit-barra {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--k-space-4);
}

.unit-boton-volver {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 12px;
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.unit-racha {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 6px 12px;
  border-radius: 999px;
  border: 1px solid rgba(142, 5, 194, 0.35);
  font-size: 12px;
  font-weight: 800;
}

.unit-racha .q-icon {
  color: var(--k-accent);
}

.unit-cta {
  margin-top: var(--k-space-5);
}
</style>
