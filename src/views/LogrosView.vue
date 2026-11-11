<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Logros</p>
      <p class="pantalla-subtitulo">Superá retos, sumá experiencia y desbloqueá recompensas</p>

      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'sin-sesion'"
        tipo="vacio"
        titulo="Iniciá sesión para ver tus logros"
        mensaje="Los logros se guardan en tu cuenta y se desbloquean solos al practicar."
        accion-label="Ir a acceso"
        @accion="irAcceso"
      />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar tus logros"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <template v-else>
        <div class="logros-resumen">
          <div class="logros-tile">
            <p class="logros-etiqueta">OBTENIDOS</p>
            <p class="logros-valor">{{ obtenidos.length }}/{{ logros.length }}</p>
          </div>
          <div class="logros-tile">
            <p class="logros-etiqueta">PENDIENTES</p>
            <p class="logros-valor">{{ pendientes.length }}</p>
          </div>
        </div>

        <section v-if="obtenidos.length" class="logros-grupo">
          <h2 class="logros-grupo-titulo">Obtenidos</h2>
          <article
            v-for="logro in obtenidos"
            :key="logro.id"
            class="logro-card es-obtenido"
          >
            <span class="logro-icono">
              <q-icon :name="logro.icono" size="24px" />
            </span>
            <div class="logro-cuerpo">
              <p class="logro-nombre">{{ logro.nombre }}</p>
              <p class="logro-descripcion">{{ logro.descripcion }}</p>
              <p class="logro-meta">
                +{{ logro.recompensa }} XP
                <template v-if="logro.obtenidoEn"> · {{ fecha(logro.obtenidoEn) }}</template>
              </p>
            </div>
          </article>
        </section>

        <section v-if="pendientes.length" class="logros-grupo">
          <h2 class="logros-grupo-titulo">Pendientes</h2>
          <article v-for="logro in pendientes" :key="logro.id" class="logro-card">
            <span class="logro-icono">
              <q-icon :name="logro.icono" size="24px" />
            </span>
            <div class="logro-cuerpo">
              <p class="logro-nombre">{{ logro.nombre }}</p>
              <p class="logro-descripcion">{{ logro.descripcion }}</p>
              <div class="logro-progreso">
                <div class="k-progress">
                  <i :style="{ width: porcentaje(logro) + '%' }"></i>
                </div>
                <span class="logro-contador">{{ logro.actual }}/{{ logro.objetivo }}</span>
              </div>
            </div>
          </article>
        </section>

        <EstadoPantalla
          v-if="!logros.length"
          tipo="vacio"
          titulo="Todavía no hay logros publicados"
          mensaje="El equipo de Kodigo está preparando los primeros desafíos."
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
import { obtenerLogros } from '@/services/catalogo'

const router = useRouter()
const estado = ref('cargando')
const mensajeError = ref('')
const logros = ref([])

const obtenidos = computed(() => logros.value.filter((logro) => logro.obtenido))
const pendientes = computed(() => logros.value.filter((logro) => !logro.obtenido))

function porcentaje(logro) {
  if (!logro.objetivo) return 0
  return Math.min(100, Math.round((logro.actual / logro.objetivo) * 100))
}

function fecha(valor) {
  if (!valor) return ''
  return new Date(valor).toLocaleDateString('es', { day: '2-digit', month: 'short' })
}

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
    logros.value = await obtenerLogros()
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

.logros-resumen {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.logros-tile {
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  text-align: center;
}

.logros-etiqueta {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: var(--k-text-3);
}

.logros-valor {
  margin-top: 4px;
  font-size: 20px;
  font-weight: 800;
  color: var(--k-accent);
}

.logros-grupo {
  margin-top: var(--k-space-6);
}

.logros-grupo-titulo {
  font-size: 16px;
  font-weight: 800;
}

.logro-card {
  display: flex;
  gap: var(--k-space-3);
  margin-top: var(--k-space-3);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.logro-card.es-obtenido {
  border-color: rgba(142, 5, 194, 0.5);
  background: rgba(142, 5, 194, 0.12);
}

.logro-icono {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  flex-shrink: 0;
  border-radius: 50%;
  border: 1px solid var(--k-line);
  background: var(--k-surface-3);
  color: var(--k-text-3);
}

.logro-card.es-obtenido .logro-icono {
  border-color: var(--k-accent);
  color: var(--k-accent);
  background: var(--k-accent-softer);
}

.logro-cuerpo {
  flex: 1;
  min-width: 0;
}

.logro-nombre {
  font-size: 14.5px;
  font-weight: 800;
}

.logro-descripcion {
  margin-top: 2px;
  font-size: 12.5px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.logro-meta {
  margin-top: 6px;
  font-size: 11.5px;
  font-weight: 700;
  color: var(--k-accent);
}

.logro-progreso {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: 8px;
}

.logro-progreso .k-progress {
  flex: 1;
}

.logro-contador {
  font-size: 11.5px;
  font-weight: 800;
  color: var(--k-text-2);
  flex-shrink: 0;
}
</style>
