<template>
  <div class="k-screen">
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
        <div class="lesson-cabecera">
          <button type="button" class="lesson-boton-volver" aria-label="Volver" @click="volver">
            <q-icon name="arrow_back" size="20px" />
          </button>
          <h1 class="lesson-titulo-cabecera">{{ leccion.titulo }}</h1>
          <span class="lesson-racha">
            <q-icon name="local_fire_department" size="17px" />
            {{ rachaDias }}d
          </span>
        </div>

        <section class="lesson-portada">
          <LogoCurso v-if="curso" :curso="curso" tone="hero" class="lesson-logo" />
          <p class="lesson-titulo k-h1">{{ leccion.titulo }}</p>
          <p class="lesson-descripcion">{{ leccion.explicacion }}</p>

          <div class="lesson-metas">
            <div class="lesson-meta">
              <p class="lesson-meta-etiqueta">DURACIÓN</p>
              <p class="lesson-meta-valor">~{{ duracionMinutos }} Minutos</p>
            </div>
            <div class="lesson-meta">
              <p class="lesson-meta-etiqueta">RECOMPENSA</p>
              <p class="lesson-meta-valor es-acento">+{{ xpLeccion }} XP</p>
            </div>
          </div>
        </section>

        <section class="lesson-bloque">
          <p class="lesson-bloque-titulo">Ejemplo de código</p>
          <p class="lesson-bloque-intro">Analizá el ejemplo antes de arrancar la práctica:</p>
          <BloqueCodigo v-if="leccion.ejemploCodigo" :code="leccion.ejemploCodigo" />
          <EstadoPantalla
            v-else
            tipo="vacio"
            titulo="Sin ejemplo de código"
            mensaje="Esta clase no trae un ejemplo de código."
          />
        </section>

        <section class="lesson-bloque">
          <p class="lesson-bloque-titulo">Lo que aprenderás hoy:</p>
          <div class="lesson-burbuja">
            <BurbujaFantasma :mensaje="explicacionCorta" :tamano-fantasma="56" estado="happy" />
          </div>
        </section>

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
            COMENZAR AHORA
          </button>

          <EstadoPantalla
            v-else
            tipo="vacio"
            titulo="Esta clase aún no tiene preguntas"
            mensaje="La práctica de esta clase va a estar disponible pronto."
          />
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import BloqueCodigo from '@/components/BloqueCodigo.vue'
import BurbujaFantasma from '@/components/BurbujaFantasma.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import LogoCurso from '@/components/LogoCurso.vue'
import {
  obtenerCurso,
  obtenerLeccion,
  obtenerLecciones,
  obtenerPreguntas,
  obtenerUnidadPorId,
  resolverCurso,
  resolverLeccion,
  resolverUnidad,
  rutaLeccion,
  rutaPregunta,
} from '@/services/catalogo'
import { estado as estadoAuth } from '@/services/auth'

const route = useRoute()
const router = useRouter()

const XP_POR_LECCION = 20
const MINUTOS_POR_PREGUNTA = 2

const estado = ref('cargando')
const mensajeError = ref('')
const leccion = ref(null)
const unidad = ref(null)
const curso = ref(null)
const preguntas = ref([])
const estadoLeccion = ref('disponible')

const rachaDias = computed(() => estadoAuth.perfil?.racha_dias ?? 0)
const xpLeccion = computed(() => XP_POR_LECCION)

const duracionMinutos = computed(() => Math.max(1, preguntas.value.length * MINUTOS_POR_PREGUNTA))

const linkUnidad = computed(() => {
  if (leccion.value && unidad.value) {
    return {
      name: 'unidad',
      params: { courseId: unidad.value.cursoId, unitId: unidad.value.id },
    }
  }
  return { name: 'cursos' }
})

// El texto va en la burbuja del fantasma: recortado para no saturar la pantalla.
const explicacionCorta = computed(() => {
  const texto = leccion.value?.explicacion ?? ''
  if (texto.length <= 180) return texto
  return `${texto.slice(0, 177).trimEnd()}…`
})

const hayPreguntas = computed(() => preguntas.value.length > 0)

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    // Ruta canónica por slugs; la legada /lesson/:leccion entra por el UUID.
    const refLeccion = route.params.leccion
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

    if (!dataLeccion || !dataUnidad) {
      estado.value = 'inexistente'
      return
    }

    leccion.value = dataLeccion
    unidad.value = dataUnidad
    curso.value = dataCurso

    // Canonicaliza: si se entró con UUID, la URL visible queda con slugs.
    if (dataCurso) {
      const destino = rutaLeccion(dataLeccion, dataUnidad, dataCurso)
      const actual = {
        curso: route.params.curso,
        unidad: route.params.unidad,
        leccion: route.params.leccion,
      }
      const esperado = destino.params
      if (
        actual.curso !== esperado.curso ||
        actual.unidad !== esperado.unidad ||
        actual.leccion !== esperado.leccion
      ) {
        router.replace(destino)
      }
    }

    const dataPreguntas = await obtenerPreguntas(dataLeccion.id)
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
  router.push(rutaPregunta(leccion.value, unidad.value, curso.value, 1))
}

function verCursos() {
  router.push('/courses')
}

function volver() {
  router.push(linkUnidad.value)
}
</script>

<style scoped>
.lesson {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.lesson-cabecera {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
}

.lesson-boton-volver {
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

.lesson-titulo-cabecera {
  flex: 1;
  min-width: 0;
  font-family: var(--k-font-brand);
  font-size: 20px;
  font-weight: 800;
  letter-spacing: -0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.lesson-racha {
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

.lesson-racha .q-icon {
  color: var(--k-accent);
}

.lesson-portada {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-top: var(--k-space-5);
  text-align: center;
}

.lesson-logo {
  margin-bottom: var(--k-space-4);
}

.lesson-descripcion {
  margin-top: var(--k-space-3);
  max-width: 330px;
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.lesson-metas {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--k-space-3);
  width: 100%;
  margin-top: var(--k-space-6);
}

.lesson-meta {
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  text-align: left;
}

.lesson-meta-etiqueta {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: var(--k-text-3);
}

.lesson-meta-valor {
  margin-top: 4px;
  font-size: 15px;
  font-weight: 800;
}

.lesson-meta-valor.es-acento {
  color: var(--k-accent);
}

.lesson-bloque {
  margin-top: var(--k-space-6);
}

.lesson-bloque-titulo {
  font-size: 17px;
  font-weight: 800;
}

.lesson-bloque-intro {
  margin-top: var(--k-space-2);
  font-size: 13.5px;
  color: var(--k-text-2);
}

.lesson-burbuja {
  margin-top: var(--k-space-4);
}

.lesson-actions {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
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
