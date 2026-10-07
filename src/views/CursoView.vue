<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Curso" :back="true" />

    <main class="k-container course">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar el curso"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'inexistente'"
        tipo="inexistente"
        titulo="Curso no encontrado"
        mensaje="El curso que buscás no existe o ya no está publicado."
        accion-label="Ver cursos"
        @accion="verCursos"
      />

      <template v-else-if="estado === 'listo' && curso">
        <section class="course-hero">
          <LogoCurso :curso="curso" tone="hero" />
          <h1 class="k-h1 course-hero-name">{{ curso.nombre }}</h1>
          <p class="course-hero-tagline">{{ curso.lema }}</p>
          <p class="k-muted course-hero-desc">{{ curso.descripcion }}</p>

          <div v-if="unidades.length" class="course-hero-progress">
            <div class="k-progress">
              <i :style="{ width: progresoCurso + '%' }"></i>
            </div>
            <div class="course-hero-meta">
              <span>{{ unidades.length }} unidades</span>
              <span>{{ progresoCurso }}% completado</span>
            </div>
          </div>
        </section>

        <section class="units">
          <p class="k-eyebrow">Recorrido de aprendizaje</p>

          <EstadoPantalla
            v-if="estadoUnidades === 'vacio'"
            tipo="vacio"
            titulo="Este curso aún no tiene unidades"
            mensaje="Las unidades del curso van a aparecer acá cuando estén publicadas."
          />

          <div v-else class="units-list">
            <TarjetaUnidad
              v-for="unidad in unidades"
              :key="unidad.id"
              :unit="unidad"
              :lessons="unidad.cantidadLecciones"
              @select="abrirUnidad"
            />
          </div>
        </section>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import LogoCurso from '@/components/LogoCurso.vue'
import TarjetaUnidad from '@/components/TarjetaUnidad.vue'
import { obtenerCurso, obtenerUnidades, rutaUnidad } from '@/services/catalogo'

const route = useRoute()
const router = useRouter()

const estado = ref('cargando')
const estadoUnidades = ref('cargando')
const mensajeError = ref('')
const curso = ref(null)
const unidades = ref([])

const progresoCurso = computed(() => {
  if (!unidades.value.length) return 0
  const total = unidades.value.reduce((suma, unidad) => suma + unidad.progreso, 0)
  return Math.round(total / unidades.value.length)
})

async function cargar() {
  estado.value = 'cargando'
  estadoUnidades.value = 'cargando'
  mensajeError.value = ''
  try {
    const dataCurso = await obtenerCurso(route.params.courseId)
    if (!dataCurso) {
      estado.value = 'inexistente'
      return
    }
    curso.value = dataCurso

    const dataUnidades = await obtenerUnidades(dataCurso.id)
    unidades.value = dataUnidades
    estadoUnidades.value = dataUnidades.length ? 'listo' : 'vacio'
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

function abrirUnidad(unidadId) {
  const unidad = unidades.value.find((u) => u.id === unidadId)
  if (unidad) router.push(rutaUnidad(unidad))
}

function verCursos() {
  router.push('/courses')
}
</script>

<style scoped>
.course-hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 16px 0 0;
}

.course-hero-name {
  margin-top: var(--k-space-4);
}

.course-hero-tagline {
  margin-top: var(--k-space-2);
  font-size: 14px;
  font-weight: 700;
  color: var(--k-text-2);
}

.course-hero-desc {
  margin-top: var(--k-space-2);
  max-width: 320px;
  font-size: 13.5px;
  line-height: 1.5;
}

.course-hero-progress {
  width: 100%;
  max-width: 300px;
  margin-top: var(--k-space-6);
}

.course-hero-meta {
  display: flex;
  justify-content: space-between;
  margin-top: var(--k-space-2);
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
}

.units {
  margin-top: var(--k-space-6);
}

.units-list {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-4);
}
</style>
