<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Amigos</p>
      <p class="pantalla-subtitulo">Tu equipo de estudio</p>

      <RouterLink to="/buscar-amigos" class="k-btn k-btn--primary k-btn--block amigos-buscar">
        <q-icon name="person_add" size="18px" />
        Buscar amigos
      </RouterLink>

      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'sin-sesion'"
        tipo="vacio"
        titulo="Iniciá sesión para ver tus amigos"
        mensaje="Las solicitudes y amistades se guardan en tu cuenta."
        accion-label="Ir a acceso"
        @accion="irAcceso"
      />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar tus amigos"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <template v-else>
        <section v-if="recibidas.length" class="amigos-grupo">
          <h2 class="amigos-titulo">Solicitudes recibidas</h2>
          <article v-for="fila in recibidas" :key="fila.amistad_id" class="amigo-card">
            <span class="amigo-avatar">{{ inicial(fila.alias) }}</span>
            <div class="amigo-datos">
              <p class="amigo-alias">{{ fila.alias }}</p>
              <p class="amigo-nivel">Nivel {{ fila.nivel }} · {{ fila.experiencia }} XP</p>
            </div>
            <div class="amigo-acciones">
              <button type="button" class="amigo-btn es-ok" :disabled="enviando" @click="responder(fila, true)">
                Aceptar
              </button>
              <button type="button" class="amigo-btn" :disabled="enviando" @click="responder(fila, false)">
                Rechazar
              </button>
            </div>
          </article>
        </section>

        <section v-if="enviadas.length" class="amigos-grupo">
          <h2 class="amigos-titulo">Solicitudes enviadas</h2>
          <article v-for="fila in enviadas" :key="fila.amistad_id" class="amigo-card">
            <span class="amigo-avatar">{{ inicial(fila.alias) }}</span>
            <div class="amigo-datos">
              <p class="amigo-alias">{{ fila.alias }}</p>
              <p class="amigo-nivel">Pendiente de respuesta</p>
            </div>
          </article>
        </section>

        <section v-if="aceptadas.length" class="amigos-grupo">
          <h2 class="amigos-titulo">Amigos</h2>
          <article v-for="fila in aceptadas" :key="fila.amistad_id" class="amigo-card">
            <span class="amigo-avatar">{{ inicial(fila.alias) }}</span>
            <div class="amigo-datos">
              <p class="amigo-alias">{{ fila.alias }}</p>
              <p class="amigo-nivel">
                Nivel {{ fila.nivel }} · {{ fila.experiencia }} XP · Racha {{ fila.racha_dias }}d
              </p>
            </div>
          </article>
        </section>

        <EstadoPantalla
          v-if="!amistades.length"
          tipo="vacio"
          titulo="Todavía no tenés amigos"
          mensaje="Buscá a tus compañeros por su nombre de usuario y enviá una solicitud."
          accion-label="Buscar amigos"
          @accion="buscar"
        />
        <p v-if="aviso" class="amigos-aviso" role="status">{{ aviso }}</p>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { estado as estadoAuth } from '@/services/auth'
import { obtenerAmistades, responderSolicitudAmistad } from '@/services/catalogo'

const router = useRouter()
const estado = ref('cargando')
const mensajeError = ref('')
const amistades = ref([])
const enviando = ref(false)

const recibidas = computed(() =>
  amistades.value.filter((fila) => fila.estado === 'pendiente' && fila.direccion === 'recibida'),
)
const enviadas = computed(() =>
  amistades.value.filter((fila) => fila.estado === 'pendiente' && fila.direccion === 'enviada'),
)
const aceptadas = computed(() => amistades.value.filter((fila) => fila.estado === 'aceptada'))

function inicial(alias) {
  return String(alias ?? '?').charAt(0).toUpperCase()
}

function irAcceso() {
  router.push('/acceso')
}

function buscar() {
  router.push('/buscar-amigos')
}

const aviso = ref('')

async function responder(fila, aceptar) {
  enviando.value = true
  mensajeError.value = ''
  aviso.value = ''
  try {
    await responderSolicitudAmistad(fila.amistad_id, aceptar)
    amistades.value = await obtenerAmistades()
    aviso.value = aceptar ? 'Solicitud aceptada.' : 'Solicitud rechazada.'
  } catch (error) {
    aviso.value = error.message
  } finally {
    enviando.value = false
  }
}

async function cargar() {
  if (!estadoAuth.usuario) {
    estado.value = 'sin-sesion'
    return
  }
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    amistades.value = await obtenerAmistades()
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

.amigos-buscar {
  margin-top: var(--k-space-5);
}

.amigos-aviso {
  margin-top: var(--k-space-4);
  font-size: 12.5px;
  color: var(--k-text-2);
}

.amigos-grupo {
  margin-top: var(--k-space-6);
}

.amigos-titulo {
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--k-text-3);
}

.amigo-card {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-3);
  padding: var(--k-space-3);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.amigo-avatar {
  width: 40px;
  height: 40px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--k-accent-softer);
  border: 1px solid var(--k-accent);
  color: var(--k-accent);
  font-weight: 800;
}

.amigo-datos {
  flex: 1;
  min-width: 0;
}

.amigo-alias {
  font-size: 14.5px;
  font-weight: 800;
}

.amigo-nivel {
  font-size: 12px;
  color: var(--k-text-2);
}

.amigo-acciones {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.amigo-btn {
  padding: 6px 12px;
  border-radius: 999px;
  border: 1px solid var(--k-line);
  background: var(--k-surface-3);
  color: var(--k-text);
  font-size: 11.5px;
  font-weight: 800;
  cursor: pointer;
}

.amigo-btn.es-ok {
  border-color: rgba(52, 211, 153, 0.45);
  color: var(--k-success);
}

.amigo-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
