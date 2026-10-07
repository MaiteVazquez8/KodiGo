<template>
  <div class="k-screen">
    <EncabezadoApp :titulo="`Unidad ${unidad?.orden ?? ''}`" :back="linkCurso" />

    <main class="k-container unit">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar la unidad"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'inexistente'"
        tipo="inexistente"
        titulo="Unidad no encontrada"
        mensaje="La unidad que buscás no existe o ya no está disponible."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <template v-else-if="estado === 'listo' && unidad">
        <p class="k-eyebrow">Curso {{ curso?.nombre }}</p>
        <h1 class="k-h1 unit-title">{{ unidad.nombre }}</h1>
        <p class="k-muted unit-desc">{{ unidad.descripcion }}</p>

        <div v-if="unidad.estado === 'bloqueada'" class="unit-locked-note">
          <q-icon name="lock" size="18px" />
          Completá la unidad anterior para desbloquear esta.
        </div>

        <section class="lessons">
          <p class="k-eyebrow">Clases</p>

          <EstadoPantalla
            v-if="estadoLecciones === 'vacio'"
            tipo="vacio"
            titulo="Esta unidad aún no tiene clases"
            mensaje="Las clases publicadas van a aparecer acá."
          />

          <div v-else class="lessons-list">
            <button
              v-for="leccion in lecciones"
              :key="leccion.id"
              type="button"
              class="lesson-row"
              :class="[`is-${leccion.estado}`]"
              :disabled="leccion.estado === 'bloqueada'"
              @click="abrirLeccion(leccion)"
            >
              <span class="lesson-icon">
                <q-icon
                  v-if="['completada', 'aprobada'].includes(leccion.estado)"
                  name="check"
                  size="18px"
                />
                <q-icon v-else-if="leccion.estado === 'bloqueada'" name="lock" size="15px" />
                <q-icon v-else name="play_circle_filled" size="20px" />
              </span>
              <span class="lesson-body">
                <span class="lesson-title">{{ leccion.titulo }}</span>
                <span class="lesson-meta">{{ leccion.cantidadPreguntas }} preguntas</span>
              </span>
              <q-icon name="chevron_right" size="18px" class="lesson-chev" />
            </button>
          </div>
        </section>

        <button
          v-if="primeraDisponible && unidad.estado !== 'bloqueada'"
          type="button"
          class="k-btn k-btn--primary k-btn--block unit-cta"
          @click="abrirLeccion(primeraDisponible)"
        >
          <q-icon name="play_arrow" size="20px" />
          Empezar primera clase
        </button>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { obtenerCurso, obtenerLecciones, obtenerUnidad } from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const estado = ref('cargando')
const estadoLecciones = ref('cargando')
const mensajeError = ref('')
const unidad = ref(null)
const curso = ref(null)
const lecciones = ref([])

const linkCurso = computed(() => ({
  name: 'curso',
  params: { courseId: route.params.courseId },
}))

const primeraDisponible = computed(
  () => lecciones.value.find((l) => l.estado !== 'bloqueada') ?? null,
)

async function cargar() {
  estado.value = 'cargando'
  estadoLecciones.value = 'cargando'
  mensajeError.value = ''
  try {
    const dataUnidad = await obtenerUnidad(route.params.courseId, route.params.unitId)
    if (!dataUnidad) {
      estado.value = 'inexistente'
      return
    }
    unidad.value = dataUnidad

    const dataCurso = await obtenerCurso(route.params.courseId)
    curso.value = dataCurso

    const dataLecciones = await obtenerLecciones(dataUnidad.id)
    lecciones.value = dataLecciones
    estadoLecciones.value = dataLecciones.length ? 'listo' : 'vacio'
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

function abrirLeccion(leccion) {
  router.push({
    name: 'leccion',
    params: {
      courseId: route.params.courseId,
      unitId: route.params.unitId,
      lessonId: leccion.id,
    },
  })
}

function verCursos() {
  router.push('/courses')
}
</script>

<style scoped>
.unit-title {
  margin-top: var(--k-space-2);
}

.unit-desc {
  margin-top: var(--k-space-2);
  font-size: 14px;
  line-height: 1.5;
}

.unit-locked-note {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-4);
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(142, 5, 194, 0.08);
  border: 1px solid rgba(142, 5, 194, 0.22);
  color: var(--k-text-2);
  font-size: 13px;
  font-weight: 600;
}

.lessons {
  margin-top: var(--k-space-6);
}

.lessons-list {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-4);
}

.lesson-row {
  display: flex;
  align-items: center;
  gap: var(--k-space-4);
  padding: 14px 16px;
  border-radius: 16px;
  border: 1px solid var(--k-line);
  background: linear-gradient(180deg, rgba(24, 9, 31, 0.96), rgba(15, 7, 21, 0.98));
  color: var(--k-text);
  cursor: pointer;
  text-align: left;
  transition:
    border-color 0.12s ease,
    transform 0.08s ease,
    box-shadow 0.12s ease;
  -webkit-tap-highlight-color: transparent;
}

.lesson-row:active {
  transform: scale(0.985);
}

.lesson-row:disabled {
  cursor: default;
  opacity: 0.5;
  transform: none;
}

.lesson-row.is-completada,
.lesson-row.is-aprobada {
  border-color: rgba(52, 211, 153, 0.35);
}

.lesson-row.is-disponible {
  border-color: rgba(142, 5, 194, 0.55);
}

.lesson-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  flex-shrink: 0;
  border-radius: 12px;
  background: rgba(142, 5, 194, 0.08);
  border: 1px solid rgba(142, 5, 194, 0.22);
  color: var(--k-accent);
}

.lesson-row.is-completada .lesson-icon,
.lesson-row.is-aprobada .lesson-icon {
  color: var(--k-success);
}

.lesson-row.is-bloqueada .lesson-icon {
  color: var(--k-text-3);
}

.lesson-body {
  flex: 1;
  min-width: 0;
  display: grid;
  gap: 2px;
}

.lesson-title {
  font-size: 14.5px;
  font-weight: 700;
}

.lesson-meta {
  font-size: 12px;
  color: var(--k-text-3);
}

.lesson-chev {
  color: var(--k-text-3);
  flex-shrink: 0;
}

.unit-cta {
  margin-top: var(--k-space-6);
}
</style>
