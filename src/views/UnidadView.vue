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
        <div class="unit-cabecera">
          <button type="button" class="unit-boton-volver" aria-label="Volver" @click="volver">
            <q-icon name="arrow_back" size="20px" />
          </button>
          <h1 class="unit-titulo-cabecera">Unidad {{ unidad.orden }}</h1>
          <span class="unit-racha">
            <q-icon name="local_fire_department" size="17px" />
            {{ rachaDias }}d
          </span>
        </div>
        <p class="unit-subtitulo">{{ unidad.descripcion }}</p>

        <section v-if="objetivos.length" class="unit-bloque">
          <p class="unit-bloque-titulo">Objetivos del aprendizaje</p>
          <ul class="unit-objetivos">
            <li v-for="objetivo in objetivos" :key="objetivo">{{ objetivo }}</li>
          </ul>
        </section>

        <div v-if="unidad.estado === 'bloqueada'" class="unit-locked-note">
          <q-icon name="lock" size="18px" />
          Completá la unidad anterior para desbloquear esta.
        </div>

        <section class="lessons">
          <p class="unit-bloque-titulo">Clases Disponibles</p>

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
                <span class="lesson-meta">
                  {{ leccion.cantidadPreguntas }} preguntas
                  <span class="lesson-xp">• +{{ xpClase }} XP</span>
                </span>
              </span>
            </button>
          </div>
        </section>

        <section class="unit-recompensa">
          <q-icon name="card_giftcard" size="22px" />
          <p>
            Recompensa al finalizar la unidad: ¡Desbloquea el cofre con
            {{ xpUnidad }} XP extras!
          </p>
        </section>

        <button
          v-if="primeraDisponible && unidad.estado !== 'bloqueada'"
          type="button"
          class="k-btn k-btn--primary k-btn--block unit-cta"
          @click="abrirLeccion(primeraDisponible)"
        >
          {{ hayCompletadas ? 'COMENZAR SIGUIENTE CLASE' : 'COMENZAR PRIMERA CLASE' }}
        </button>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
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

const XP_POR_CLASE = 15
const XP_POR_UNIDAD = 100

const rachaDias = computed(() => estadoAuth.perfil?.racha_dias ?? 0)
const xpClase = computed(() => XP_POR_CLASE)
const xpUnidad = computed(() => XP_POR_UNIDAD)

const hayCompletadas = computed(() =>
  lecciones.value.some((l) => ['completada', 'aprobada'].includes(l.estado)),
)

// El mock lista los objetivos como viñetas; se derivan de las clases de la
// unidad porque la tabla unidades no tiene columna de objetivos.
const objetivos = computed(() => lecciones.value.map((leccion) => leccion.titulo).slice(0, 3))

const linkCurso = computed(() =>
  curso.value ? { name: 'curso', params: { curso: aSlug(curso.value.nombre) } } : { name: 'learn' },
)

const primeraDisponible = computed(
  () => lecciones.value.find((l) => l.estado !== 'bloqueada') ?? null,
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
.unit-cabecera {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
}

.unit-boton-volver {
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

.unit-titulo-cabecera {
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

.unit-racha {
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

.unit-racha .q-icon {
  color: var(--k-accent);
}

.unit-subtitulo {
  margin-top: var(--k-space-3);
  font-size: 14px;
  color: var(--k-text-2);
}

.unit-bloque {
  margin-top: var(--k-space-6);
}

.unit-bloque-titulo {
  font-size: 17px;
  font-weight: 800;
}

.unit-objetivos {
  display: grid;
  gap: var(--k-space-2);
  margin: var(--k-space-3) 0 0;
  padding: var(--k-space-4) var(--k-space-4) var(--k-space-4) var(--k-space-7);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.unit-objetivos li {
  font-size: 13.5px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.lesson-xp {
  color: var(--k-accent);
  font-weight: 800;
}

.unit-recompensa {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(142, 5, 194, 0.35);
  background: var(--k-accent-softer);
}

.unit-recompensa .q-icon {
  color: var(--k-accent);
  flex-shrink: 0;
}

.unit-recompensa p {
  font-size: 13.5px;
  line-height: 1.45;
  color: var(--k-text-2);
}

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
