<template>
  <div class="k-screen">
    <EncabezadoApp marca />

    <main class="k-container home">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar Kodigo"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <template v-else>
        <section class="hero">
          <FantasmaKodigo :size="112" variant="happy" class="hero-ghost" />
          <p class="hero-wordmark k-font-brand">Kodigo</p>
          <p class="hero-tagline">Aprendé a programar paso a paso.</p>
          <div class="hero-stats">
            <span class="hero-stat">
              <q-icon name="bolt" size="16px" />
              120 XP
            </span>
            <span class="hero-stat">
              <q-icon name="local_fire_department" size="16px" />
              Racha 3
            </span>
          </div>
        </section>

        <BurbujaFantasma
          :mensaje="mensajeBienvenida"
          :tamano-fantasma="60"
          estado="happy"
          class="home-bubble"
        />

        <div class="home-actions">
          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            @click="continuarAprendiendo"
          >
            {{ etiquetaContinuar }}
          </button>
          <RouterLink to="/courses" class="k-btn k-btn--ghost k-btn--block">
            Ver todos los cursos
          </RouterLink>
        </div>

        <TarjetaCurso v-if="cursoDestacado" :curso="cursoDestacado" @select="abrirCurso" />
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import BurbujaFantasma from '@/components/BurbujaFantasma.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import TarjetaCurso from '@/components/TarjetaCurso.vue'
import { obtenerCursos, obtenerLecciones, obtenerUnidades, rutaLeccion } from '@/services/catalogo'

const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const cursos = ref([])
const primeraUnidad = ref(null)
const primeraLeccion = ref(null)

const mensajeBienvenida =
  '¡Hola! Soy el fantasma de Kodigo. ¿Listo para escribir tu primer código en JavaScript?'

const cursoDestacado = computed(() => cursos.value[0] || null)

const etiquetaContinuar = computed(() => {
  if (!primeraLeccion.value) return 'Empezar a aprender'
  const tieneProgreso =
    primeraUnidad.value?.progreso > 0 ||
    ['completada', 'aprobada'].includes(primeraLeccion.value.estado)
  return tieneProgreso ? 'Continuar aprendiendo' : 'Empezar a aprender'
})

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    const lista = await obtenerCursos()
    cursos.value = lista
    primeraUnidad.value = null
    primeraLeccion.value = null

    const curso = lista[0]
    if (curso) {
      const unidades = await obtenerUnidades(curso.id)
      const unidad = unidades.find((u) => u.estado !== 'bloqueada')
      primeraUnidad.value = unidad || null
      if (unidad) {
        const lecciones = await obtenerLecciones(unidad.id)
        primeraLeccion.value = lecciones.find((l) => l.estado !== 'bloqueada') || null
      }
    }
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

function continuarAprendiendo() {
  if (primeraLeccion.value && primeraUnidad.value) {
    router.push(rutaLeccion(primeraLeccion.value, primeraUnidad.value))
    return
  }
  if (cursoDestacado.value) {
    router.push({ name: 'curso', params: { courseId: cursoDestacado.value.id } })
    return
  }
  router.push('/courses')
}

function abrirCurso() {
  if (cursoDestacado.value) {
    router.push({ name: 'curso', params: { courseId: cursoDestacado.value.id } })
  }
}
</script>

<style scoped>
.hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16px 0 0;
  text-align: center;
}

.hero-wordmark {
  margin-top: 8px;
  font-size: 42px;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 0.96;
}

.hero-tagline {
  margin-top: 8px;
  font-size: 15px;
  font-weight: 600;
  color: var(--k-text-2);
}

.hero-stats {
  display: flex;
  gap: 10px;
  margin-top: 18px;
}

.hero-stat {
  display: inline-flex;
  align-items: center;
  gap: var(--k-space-2);
  padding: 7px 12px;
  border-radius: 999px;
  background: rgba(142, 5, 194, 0.08);
  border: 1px solid rgba(142, 5, 194, 0.28);
  color: var(--k-text-2);
  font-size: 12.5px;
  font-weight: 700;
}

.hero-stat .q-icon {
  color: var(--k-accent);
}

.home-bubble {
  margin-top: var(--k-space-6);
}

.home-actions {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
}
</style>
