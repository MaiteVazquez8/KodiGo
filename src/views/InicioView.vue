<template>
  <div class="k-screen">
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
        <header class="home-encabezado">
          <p class="home-logo k-font-brand">KODI<span>GO</span></p>
          <span class="home-racha">
            <q-icon name="local_fire_department" size="18px" />
            {{ rachaDias }}d
          </span>
        </header>
        <p class="home-lema">Tu portal de aprendizaje gamificado</p>

        <section class="tarjeta-progreso">
          <div class="tarjeta-progreso-cabecera">
            <p class="tarjeta-progreso-titulo">Progreso Diario</p>
            <p class="tarjeta-progreso-valor">{{ progresoDiario }}% Completado</p>
          </div>
          <div class="k-progress">
            <i :style="{ width: `${progresoDiario}%` }"></i>
          </div>
          <p class="tarjeta-progreso-ayuda">{{ mensajeProgreso }}</p>
        </section>

        <section v-if="leccionContinuar" class="home-seccion">
          <p class="home-seccion-titulo">Continuar Aprendiendo</p>
          <button type="button" class="tarjeta-continuar" @click="continuarAprendiendo">
            <LogoCurso :curso="cursoContinuar" tone="hero" class="continuar-logo" />
            <div class="continuar-datos">
              <p class="continuar-titulo">{{ cursoContinuar?.nombre }}</p>
              <p class="continuar-subtitulo">
                Unidad {{ leccionContinuar.orden }}: {{ unidadContinuar?.nombre }}
              </p>
            </div>
            <q-icon name="play_arrow" size="22px" class="continuar-play" />
          </button>
        </section>

        <!-- Tarjeta del Desafio ExpoTecnica: solo si hay un evento activo. -->
        <section v-if="eventoActivo" class="home-seccion">
          <p class="home-seccion-titulo">Evento Especial</p>
          <button type="button" class="tarjeta-continuar tarjeta-desafio" @click="irAlDesafio">
            <FantasmaKodigo :size="46" class="desafio-ghost" />
            <div class="continuar-datos">
              <p class="continuar-titulo">Desafío ExpoTécnica</p>
              <p class="continuar-subtitulo">{{ lemaDesafio }}</p>
            </div>
            <q-icon name="emoji_events" size="22px" class="continuar-play" />
          </button>
        </section>

        <section class="home-seccion">
          <p class="home-seccion-titulo">Cursos Sugeridos</p>
          <div class="home-sugeridos">
            <TarjetaCurso
              v-for="curso in sugeridos"
              :key="curso.id"
              :curso="curso"
              @select="abrirCurso"
            />
          </div>
        </section>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import LogoCurso from '@/components/LogoCurso.vue'
import TarjetaCurso from '@/components/TarjetaCurso.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import {
  aSlug,
  obtenerCursos,
  obtenerLecciones,
  obtenerUnidades,
  rutaLeccion,
} from '@/services/catalogo'
import { estado as estadoAuth, usarAuth } from '@/services/auth'
import { obtenerEventoActivo } from '@/services/expotecnica'

const router = useRouter()
const { estado } = usarAuth()

const estadoCarga = ref('cargando')
const mensajeError = ref('')
const cursos = ref([])
const primeraUnidad = ref(null)
const primeraLeccion = ref(null)

const perfil = computed(() => estadoAuth.perfil)
const rachaDias = computed(() => perfil.value?.racha_dias ?? 0)

const cursoContinuar = computed(() => cursos.value[0] || null)
const unidadContinuar = computed(() => primeraUnidad.value)

// Se toma la primera leccion aun sin aprobacion: el mock usa "Unidad N: ..." como
// etiqueta de la tarjeta, no el nombre del curso.
const leccionContinuar = computed(() => primeraLeccion.value)

const progresoDiario = computed(() => {
  if (!leccionContinuar.value) return 0
  return primeraUnidad.value?.progreso ?? 0
})

const mensajeProgreso = computed(() => {
  if (!leccionContinuar.value) {
    return 'Elegí un curso para empezar tu primera lección.'
  }
  if (progresoDiario.value >= 100) {
    return `¡Racha de ${rachaDias.value} días mantenida! Seguí con la próxima lección.`
  }
  return 'Completa 1 lección más hoy para mantener tu racha.'
})

const sugeridos = computed(() => cursos.value.slice(0, 4))

// El desafio es independiente del catalogo: si no hay evento activo la tarjeta
// no aparece y el portal queda igual que siempre.
const eventoActivo = ref(null)
const lemaDesafio = computed(() => {
  const d = eventoActivo.value?.desafio
  if (!d) return 'El gran desafío competitivo de Kodigo'
  return `${d.cantidadPreguntas} preguntas de JavaScript + Core Defender`
})

async function cargar() {
  estadoCarga.value = 'cargando'
  mensajeError.value = ''
  try {
    const [lista, activo] = await Promise.all([obtenerCursos(), obtenerEventoActivoSilencioso()])
    cursos.value = lista
    eventoActivo.value = activo

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
    estadoCarga.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estadoCarga.value = 'error'
  }
}

onMounted(cargar)

// El desafio es independiente del catalogo: si no hay evento activo la tarjeta
// no aparece y el portal queda igual que siempre. La consulta no rompe el
// portal: si falla, la tarjeta simplemente no se muestra.
async function obtenerEventoActivoSilencioso() {
  try {
    return await obtenerEventoActivo()
  } catch {
    return null
  }
}

function irAlDesafio() {
  router.push('/expotecnica')
}

function continuarAprendiendo() {
  if (primeraLeccion.value && primeraUnidad.value) {
    router.push(rutaLeccion(primeraLeccion.value, primeraUnidad.value, cursoContinuar.value))
    return
  }
  if (cursoContinuar.value) {
    router.push({ name: 'curso', params: { curso: aSlug(cursoContinuar.value.nombre) } })
    return
  }
  router.push('/courses')
}

// TarjetaCurso emite el curso completo. Si no llegara un curso usable, no se
// navega: evitaría construir "/courses/" y caer en el redirect.
function abrirCurso(curso) {
  const slug = aSlug(curso?.nombre)
  if (!slug) return
  router.push({ name: 'curso', params: { curso: slug } })
}
</script>

<style scoped>
.home {
  display: flex;
  flex-direction: column;
  padding-top: max(12px, env(safe-area-inset-top));
}

.home-encabezado {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.home-logo {
  font-size: 26px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.home-logo span {
  color: var(--k-accent);
}

.home-racha {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 12px;
  border-radius: 999px;
  border: 1px solid rgba(142, 5, 194, 0.35);
  font-size: 12.5px;
  font-weight: 800;
}

.home-racha .q-icon {
  color: var(--k-accent);
}

.home-lema {
  margin-top: var(--k-space-2);
  font-size: 14.5px;
  color: var(--k-text-2);
}

.tarjeta-progreso {
  margin-top: var(--k-space-5);
  padding: var(--k-space-5);
  border-radius: var(--k-radius);
  border: 1px solid rgba(142, 5, 194, 0.45);
  background: rgba(24, 9, 31, 0.9);
}

.tarjeta-progreso-cabecera {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--k-space-3);
}

.tarjeta-progreso-titulo {
  font-size: 16px;
  font-weight: 800;
}

.tarjeta-progreso-valor {
  font-size: 14px;
  font-weight: 800;
  color: var(--k-accent);
}

.tarjeta-progreso .k-progress {
  margin-top: var(--k-space-3);
  /* El track global es casi negro sobre el fondo de la tarjeta y no se ve. */
  background: rgba(255, 255, 255, 0.12);
}

.tarjeta-progreso-ayuda {
  margin-top: var(--k-space-3);
  font-size: 13px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.home-seccion {
  margin-top: var(--k-space-6);
}

.home-seccion-titulo {
  font-size: 17px;
  font-weight: 800;
}

.tarjeta-continuar {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  width: 100%;
  margin-top: var(--k-space-3);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-accent);
  background: var(--k-surface-2);
  color: var(--k-text);
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.continuar-logo {
  flex-shrink: 0;
}

.continuar-datos {
  flex: 1;
  min-width: 0;
}

.continuar-titulo {
  font-size: 15px;
  font-weight: 800;
}

.continuar-subtitulo {
  margin-top: 2px;
  font-size: 12.5px;
  color: var(--k-text-2);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.continuar-play {
  color: var(--k-accent);
  flex-shrink: 0;
}

/* Tarjeta del Desafio ExpoTecnica: misma anatomia que continuar, gana acento */
.tarjeta-desafio {
  border-color: rgba(142, 5, 194, 0.45);
  background: linear-gradient(160deg, rgba(142, 5, 194, 0.16), rgba(62, 6, 95, 0.5));
}

.tarjeta-desafio:hover,
.tarjeta-desafio:active {
  border-color: var(--k-accent);
}

.desafio-ghost {
  flex-shrink: 0;
  animation: desafio-flotar 2.2s ease-in-out infinite;
}

@keyframes desafio-flotar {
  0%,
  100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-4px);
  }
}

.home-sugeridos {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-3);
}
</style>
