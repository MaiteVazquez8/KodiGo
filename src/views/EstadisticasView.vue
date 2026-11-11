<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Mis Estadísticas</p>
      <p class="pantalla-subtitulo">Tu progreso real guardado en Kodigo</p>

      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'sin-sesion'"
        tipo="vacio"
        titulo="Iniciá sesión para ver tus estadísticas"
        mensaje="Necesitamos tu cuenta para calcular tu progreso real."
        accion-label="Ir a acceso"
        @accion="irAcceso"
      />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar tus estadísticas"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <template v-else>
        <section class="stats-grid">
          <div class="stats-tile">
            <p class="stats-etiqueta">PRECISIÓN</p>
            <p class="stats-valor es-acento">{{ datos.precision ?? 0 }}%</p>
          </div>
          <div class="stats-tile">
            <p class="stats-etiqueta">TOTAL XP</p>
            <p class="stats-valor">{{ datos.xp ?? 0 }}</p>
          </div>
          <div class="stats-tile">
            <p class="stats-etiqueta">RACHA</p>
            <p class="stats-valor">{{ datos.racha ?? 0 }}d</p>
          </div>
        </section>

        <section class="stats-bloque">
          <h2 class="stats-titulo">Aprendizaje</h2>
          <dl class="stats-lista">
            <div class="stats-fila">
              <dt>Nivel</dt>
              <dd>{{ datos.nivel ?? 1 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Cursos empezados</dt>
              <dd>{{ datos.cursos_iniciados ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Cursos completados</dt>
              <dd>{{ datos.cursos_completados ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Unidades completadas</dt>
              <dd>{{ datos.unidades_completadas ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Lecciones aprobadas</dt>
              <dd>{{ datos.lecciones_aprobadas ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Lecciones completadas</dt>
              <dd>{{ datos.lecciones_completadas ?? 0 }}</dd>
            </div>
          </dl>
        </section>

        <section class="stats-bloque">
          <h2 class="stats-titulo">Actividad</h2>
          <dl class="stats-lista">
            <div class="stats-fila">
              <dt>Actividades respondidas</dt>
              <dd>{{ datos.actividades_realizadas ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Respuestas correctas</dt>
              <dd>{{ datos.respuestas_correctas ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Respuestas incorrectas</dt>
              <dd>{{ datos.respuestas_incorrectas ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Intentos cerrados</dt>
              <dd>{{ datos.intentos ?? 0 }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Tiempo de práctica</dt>
              <dd>{{ tiempo }}</dd>
            </div>
            <div class="stats-fila">
              <dt>Logros obtenidos</dt>
              <dd>{{ datos.logros_obtenidos ?? 0 }}</dd>
            </div>
          </dl>
        </section>

        <EstadoPantalla
          v-if="!hayActividad"
          tipo="vacio"
          titulo="Todavía no hay historial"
          mensaje="A medida que completes lecciones vas a ver acá tu evolución."
        />
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { estado as estadoAuth } from '@/services/auth'
import { obtenerEstadisticas } from '@/services/catalogo'

const router = useRouter()
const estado = ref('cargando')
const mensajeError = ref('')
const datos = ref({})

const hayActividad = computed(() => (datos.value.actividades_realizadas ?? 0) > 0)

const tiempo = computed(() => {
  const segundos = Number(datos.value.tiempo_aprendizaje_seg ?? 0)
  if (segundos < 60) return `${segundos}s`
  const minutos = Math.round(segundos / 60)
  if (minutos < 60) return `${minutos} min`
  const horas = Math.floor(minutos / 60)
  return `${horas} h ${minutos % 60} min`
})

function irAcceso() {
  router.push('/acceso')
}

async function cargar() {
  if (!estadoAuth.usuario) {
    estado.value = 'sin-sesion'
    return
  }
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    datos.value = await obtenerEstadisticas()
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)
</script>

<style scoped>
.pantalla {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.pantalla-titulo {
  margin-top: var(--k-space-2);
}

.pantalla-subtitulo {
  margin-top: var(--k-space-2);
  font-size: 14px;
  color: var(--k-text-2);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.stats-tile {
  padding: var(--k-space-4) var(--k-space-2);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  text-align: center;
}

.stats-etiqueta {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: var(--k-text-3);
}

.stats-valor {
  margin-top: 4px;
  font-size: 19px;
  font-weight: 800;
}

.stats-valor.es-acento {
  color: var(--k-accent);
}

.stats-bloque {
  margin-top: var(--k-space-6);
  padding: var(--k-space-4);
  border-radius: var(--k-radius);
  border: 1px solid var(--k-line);
  background: rgba(24, 9, 31, 0.55);
}

.stats-titulo {
  font-size: 15px;
  font-weight: 800;
}

.stats-lista {
  margin: var(--k-space-3) 0 0;
}

.stats-fila {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--k-space-3);
  padding: 8px 0;
  border-bottom: 1px solid var(--k-line);
  font-size: 13.5px;
}

.stats-fila:last-child {
  border-bottom: 0;
}

.stats-fila dt {
  color: var(--k-text-2);
}

.stats-fila dd {
  margin: 0;
  font-weight: 800;
}
</style>
