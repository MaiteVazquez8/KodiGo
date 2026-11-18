<template>
  <div class="k-screen">
    <main class="k-container curso">
      <EstadoPantalla v-if="estadoCarga === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estadoCarga === 'error'"
        tipo="error"
        titulo="No pudimos cargar el curso"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estadoCarga === 'inexistente'"
        tipo="inexistente"
        titulo="Curso no encontrado"
        mensaje="El curso que buscás no existe o ya no está publicado."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <template v-else-if="estadoCarga === 'listo' && curso">
        <div class="curso-cabecera">
          <button type="button" class="curso-boton-volver" aria-label="Volver" @click="volver">
            <q-icon name="arrow_back" size="20px" />
          </button>
          <h1 class="curso-titulo">Detalle: {{ curso.nombre }}</h1>
          <span class="curso-racha">
            <q-icon name="local_fire_department" size="17px" />
            {{ rachaDias }}d
          </span>
        </div>
        <p class="curso-lema">{{ curso.lema }}</p>

        <section class="tarjeta-presentacion">
          <LogoCurso :curso="curso" tone="hero" class="presentacion-logo" />
          <p class="presentacion-nivel">{{ nivel }}</p>
          <p class="presentacion-titulo">{{ curso.nombre }}</p>
          <p class="presentacion-descripcion">{{ curso.descripcion }}</p>
        </section>

        <section class="curso-bloque">
          <p class="curso-bloque-titulo">Progreso General</p>
          <div class="k-progress curso-barra">
            <i :style="{ width: progresoCurso + '%' }"></i>
          </div>
          <p class="curso-bloque-detalle">{{ progresoCurso }}% completado</p>
        </section>

        <!-- Atajo al Desafio ExpoTecnica cuando se estudia JavaScript. -->
        <section v-if="esCursoJavaScript && desafioActivo" class="curso-bloque curso-desafio">
          <p class="curso-bloque-titulo">Evento Especial</p>
          <button type="button" class="k-btn k-btn--primary k-btn--block" @click="irAlDesafio">
            <q-icon name="emoji_events" size="18px" />
            Ir al Desafío ExpoTécnica
          </button>
        </section>

        <section class="curso-bloque">
          <p class="curso-bloque-titulo">Unidades de Estudio</p>

          <EstadoPantalla
            v-if="estadoUnidades === 'vacio'"
            tipo="vacio"
            titulo="Este curso aún no tiene unidades"
            mensaje="Las unidades del curso van a aparecer acá cuando estén publicadas."
          />

          <div v-else class="unidades-lista">
            <button
              v-for="(unidad, indice) in unidades"
              :key="unidad.id"
              type="button"
              class="tarjeta-unidad"
              :class="{
                'es-actual': indice === indiceActual,
                'es-completada': unidad.estado === 'completada',
                'es-bloqueada': unidad.estado === 'bloqueada',
              }"
              @click="abrirUnidad(unidad.id)"
            >
              <span class="unidad-numero" aria-hidden="true">{{ indice + 1 }}</span>
              <div class="unidad-cuerpo">
                <p class="unidad-etiqueta">
                  UNIDAD {{ indice + 1 }}
                  <span v-if="unidad.estado === 'completada'">(Completada)</span>
                  <span v-else-if="indice === indiceActual" class="unidad-etiqueta-actual">(Actual)</span>
                </p>
                <p class="unidad-nombre">{{ unidad.nombre }}</p>
                <p class="unidad-descripcion">{{ unidad.descripcion }}</p>
                <div class="unidad-meta" aria-hidden="true">
                  <span class="unidad-meta-item">{{ unidad.cantidadLecciones }} clases</span>
                  <span class="unidad-meta-sep">·</span>
                  <span class="unidad-meta-item">+{{ unidad.cantidadLecciones * 25 }} XP potenciales</span>
                </div>
                <div class="unidad-progreso" role="progressbar" :aria-valuenow="unidad.progreso" aria-valuemin="0" aria-valuemax="100">
                  <div class="k-progress unidad-barra"><i :style="{ width: unidad.progreso + '%' }"></i></div>
                  <span class="unidad-progreso-pct">{{ unidad.progreso }}%</span>
                </div>
              </div>
              <q-icon
                v-if="unidad.estado === 'completada'"
                name="check_circle"
                size="22px"
                class="unidad-icono"
              />
              <q-icon
                v-else-if="unidad.estado === 'bloqueada'"
                name="lock"
                size="18px"
                class="unidad-icono is-bloqueada"
              />
              <q-icon v-else name="chevron_right" size="20px" class="unidad-icono" />
            </button>
          </div>
        </section>

        <button
          type="button"
          class="k-btn k-btn--primary k-btn--block k-btn--lg curso-empezar"
          :disabled="!unidadActual"
          @click="empezarAprendizaje"
        >
          {{ progresoCurso >= 100 ? 'REPASAR UNIDAD' : 'EMPEZAR APRENDIZAJE' }}
        </button>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import LogoCurso from '@/components/LogoCurso.vue'
import { aSlug, obtenerUnidades, resolverCurso, rutaUnidad } from '@/services/catalogo'
import { estado as estadoAuth } from '@/services/auth'
import { obtenerEventoActivo } from '@/services/expotecnica'

const route = useRoute()
const router = useRouter()


const estadoCarga = ref('cargando')
const estadoUnidades = ref('cargando')
const mensajeError = ref('')
const curso = ref(null)
const unidades = ref([])

const rachaDias = computed(() => estadoAuth.perfil?.racha_dias ?? 0)

const esCursoJavaScript = computed(() => aSlug(curso.value?.nombre) === 'javascript')
const desafioActivo = ref(false)

const progresoCurso = computed(() => {
  if (!unidades.value.length) return 0
  const total = unidades.value.reduce((suma, unidad) => suma + unidad.progreso, 0)
  return Math.round(total / unidades.value.length)
})

// El mock muestra "Nivel Principiante" sobre el titulo del curso.
const nivel = computed(() => (progresoCurso.value >= 100 ? 'Nivel Avanzado' : 'Nivel Principiante'))

const indiceActual = computed(() => {
  const pendiente = unidades.value.findIndex((unidad) => unidad.estado === 'disponible')
  return pendiente === -1 ? 0 : pendiente
})

const unidadActual = computed(() => unidades.value[indiceActual.value] || null)

async function cargar() {
  estadoCarga.value = 'cargando'
  estadoUnidades.value = 'cargando'
  mensajeError.value = ''
  try {
    const dataCurso = await resolverCurso(route.params.curso)
    if (!dataCurso) {
      estadoCarga.value = 'inexistente'
      return
    }
    curso.value = dataCurso

    // Si se entró con un UUID, la URL visible queda con el slug.
    if (route.params.curso !== aSlug(dataCurso.nombre)) {
      router.replace({ name: 'curso', params: { curso: aSlug(dataCurso.nombre) } })
    }

    const dataUnidades = await obtenerUnidades(dataCurso.id)
    unidades.value = dataUnidades
    estadoUnidades.value = dataUnidades.length ? 'listo' : 'vacio'
    estadoCarga.value = 'listo'

    // El atajo al desafio solo aparece si hay evento activo; falla silenciosa.
    if (esCursoJavaScript.value) {
      try {
        desafioActivo.value = Boolean(await obtenerEventoActivo())
      } catch {
        desafioActivo.value = false
      }
    }
  } catch (error) {
    mensajeError.value = error.message
    estadoCarga.value = 'error'
  }
}

onMounted(cargar)

function abrirUnidad(unidadId) {
  const unidad = unidades.value.find((u) => u.id === unidadId)
  if (unidad && curso.value) router.push(rutaUnidad(unidad, curso.value))
}

function empezarAprendizaje() {
  if (unidadActual.value) abrirUnidad(unidadActual.value.id)
}

function irAlDesafio() {
  router.push('/expotecnica')
}

function volver() {
  router.back()
}

function verCursos() {
  router.push('/courses')
}
</script>

<style scoped>
.curso {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.curso-cabecera {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
}

.curso-boton-volver {
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

.curso-titulo {
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

.curso-racha {
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

.curso-racha .q-icon {
  color: var(--k-accent);
}

.curso-lema {
  margin-top: var(--k-space-3);
  font-size: 14px;
  color: var(--k-text-2);
}

.tarjeta-presentacion {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-top: var(--k-space-5);
  padding: var(--k-space-6) var(--k-space-4);
  border-radius: var(--k-radius);
  border: 1px solid rgba(142, 5, 194, 0.45);
  background: rgba(24, 9, 31, 0.9);
  text-align: center;
}

.presentacion-nivel {
  margin-top: var(--k-space-4);
  font-size: 13px;
  font-weight: 800;
  color: var(--k-accent);
}

.presentacion-titulo {
  margin-top: 2px;
  font-family: var(--k-font-brand);
  font-size: 21px;
  font-weight: 800;
}

.presentacion-descripcion {
  margin-top: var(--k-space-2);
  font-size: 13.5px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.curso-bloque {
  margin-top: var(--k-space-6);
}

.curso-bloque-titulo {
  font-size: 17px;
  font-weight: 800;
}

.curso-barra {
  margin-top: var(--k-space-3);
  background: rgba(255, 255, 255, 0.12);
}

.curso-bloque-detalle {
  margin-top: var(--k-space-2);
  font-size: 12.5px;
  font-weight: 700;
  color: var(--k-text-2);
}

.unidades-lista {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-3);
}

.tarjeta-unidad {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  width: 100%;
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  transition: border-color 0.14s ease, background 0.14s ease, transform 0.08s ease;
}

.tarjeta-unidad:hover {
  border-color: rgba(142, 5, 194, 0.45);
  background: rgba(142, 5, 194, 0.06);
}

.tarjeta-unidad.es-actual {
  border-color: var(--k-accent);
  background: var(--k-accent-softer);
  box-shadow: inset 0 0 0 1px rgba(142, 5, 194, 0.25);
}

.tarjeta-unidad.es-completada {
  border-color: rgba(34, 197, 94, 0.35);
}

.tarjeta-unidad.es-bloqueada {
  opacity: 0.6;
}

.unidad-numero {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 14px;
  background: #251033;
  border: 1px solid rgba(142, 5, 194, 0.35);
  font-family: var(--k-font-brand);
  font-size: 20px;
  font-weight: 800;
  color: #d8b4fe;
  flex-shrink: 0;
}

.tarjeta-unidad.es-completada .unidad-numero {
  border-color: rgba(34, 197, 94, 0.45);
  color: var(--k-success);
}

.tarjeta-unidad.es-actual .unidad-numero {
  background: var(--k-accent);
  color: #fff;
  border-color: rgba(255, 255, 255, 0.28);
}

.unidad-cuerpo {
  display: grid;
  gap: 2px;
  flex: 1;
  min-width: 0;
}

.unidad-etiqueta {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.09em;
  color: var(--k-accent);
}

.tarjeta-unidad.es-completada .unidad-etiqueta {
  color: var(--k-success);
}

.unidad-etiqueta-actual {
  color: var(--k-text);
}

.unidad-nombre {
  margin-top: 2px;
  font-size: 17px;
  font-weight: 800;
}

.unidad-descripcion {
  margin-top: 2px;
  font-size: 12.5px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.unidad-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
}

.unidad-meta-item {
  font-size: 11px;
  font-weight: 800;
  color: var(--k-text-3);
  letter-spacing: 0.01em;
}

.unidad-meta-sep {
  font-size: 11px;
  color: var(--k-text-3);
}

.unidad-progreso {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 8px;
}

.unidad-barra {
  flex: 1;
  height: 8px;
  background: rgba(255, 255, 255, 0.1);
}

.unidad-barra i {
  background: var(--k-accent);
}

.tarjeta-unidad.es-completada .unidad-barra i {
  background: var(--k-success);
}

.unidad-progreso-pct {
  font-size: 11px;
  font-weight: 800;
  color: var(--k-text-2);
  min-width: 34px;
  text-align: right;
}

.unidad-icono {
  align-self: center;
  color: var(--k-text-3);
  flex-shrink: 0;
}

.unidad-icono.is-bloqueada {
  color: var(--k-text-3);
}

.curso-empezar {
  margin-top: var(--k-space-6);
}

/* Bloque del Desafio ExpoTecnica: mismo ritmo, borde con acento violeta */
.curso-desafio .k-btn {
  border: 1px solid rgba(142, 5, 194, 0.5);
}
</style>
