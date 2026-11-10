<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Ranking ExpoTécnica" back="/expotecnica" :lado="textoConexion" />

    <main class="k-container ranking">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar el ranking"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'vacio'"
        variant="bored"
        titulo="El ranking todavía está vacío"
        mensaje="Nadie publicó resultados todavía. Entrá al desafío y sé la primera persona en terminar el cuestionario de la ExpoTécnica."
        accion-label="Participar"
        @accion="irDesafio"
      />

      <template v-else>
        <section class="ranking-cabecera">
          <p class="ranking-evento">{{ evento?.nombre || 'Desafío ExpoTécnica' }}</p>
          <p class="ranking-actualizacion">
            Última actualización: {{ ultimaActualizacion }}
            <button type="button" class="ranking-refrescar" aria-label="Refrescar ranking" @click="refrescar">
              <q-icon name="refresh" size="14px" />
            </button>
          </p>
        </section>

        <section class="ranking-tabla" role="table" aria-label="Ranking del evento">
          <div v-for="fila in filas" :key="fila.alias" class="ranking-fila" :class="{ 'es-propio': esMiAlias(fila.alias) }" role="row">
            <span class="ranking-puesto k-font-brand" :class="clasePuesto(fila.puesto)">
              {{ fila.puesto }}
            </span>
            <span class="ranking-alias">
              {{ fila.alias }}
              <em v-if="esMiAlias(fila.alias)"> (vos)</em>
            </span>
            <span class="ranking-detalle">
              {{ fila.correctas }}·{{ fila.incorrectas }}
              <em class="ranking-juego">+{{ fila.puntajeJuego }}</em>
            </span>
            <strong class="ranking-puntos">{{ fila.puntajeTotal }}</strong>
          </div>
        </section>

        <p class="ranking-regla">
          El orden lo calcula el servidor con desempates ordenados: puntaje total, tiempo del
          cuestionario, puntos de juego y, por último, la fecha de envío. Solo cuentan partidas
          finalizadas.
        </p>
      </template>

      <div class="ranking-footer">
        <button type="button" class="k-btn k-btn--ghost k-btn--block" @click="volverInicio">
          <q-icon name="home" size="18px" />
          Volver al inicio
        </button>
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { obtenerEventoActivo, ranking, suscribirseARanking } from '@/services/expotecnica'

const INTERVALO_REFRESCO = 30_000

const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const evento = ref(null)
const filas = ref([])
const conectado = ref(false)
const ultimaActualizacionLos = ref('')

const textoConexion = computed(() => (conectado.value ? 'en vivo' : 'conectando'))

let desRegistrar = null
let timerRefresco = 0

const ultimaActualizacion = computed(() => {
  if (!ultimaActualizacionLos.value) return '—'
  const d = new Date(ultimaActualizacionLos.value)
  const hh = d.getHours().toString().padStart(2, '0')
  const mm = d.getMinutes().toString().padStart(2, '0')
  const ss = d.getSeconds().toString().padStart(2, '0')
  return `${hh}:${mm}:${ss}`
})

function esMiAlias(aliasFila) {
  const aliasGuardado = aliasLocal()
  return Boolean(aliasGuardado) && filaNormalizado(aliasFila) === aliasGuardado
}

function filaNormalizado(valor) {
  return String(valor ?? '').trim().toLowerCase()
}

function aliasLocal() {
  try {
    const guardada = JSON.parse(localStorage.getItem('kodigo.expotec.partida') ?? 'null')
    if (guardada?.alias) return filaNormalizado(guardada.alias)
    const ultimoAlias = JSON.parse(localStorage.getItem('kodigo.expotec.ultimo-alias') ?? 'null')
    return ultimoAlias ? filaNormalizado(ultimoAlias) : ''
  } catch {
    return ''
  }
}

function clasePuesto(puesto) {
  if (puesto === 1) return 'oro'
  if (puesto === 2) return 'plata'
  if (puesto === 3) return 'bronce'
  return ''
}

async function cargar() {
  estado.value = filas.value.length ? 'listo' : 'cargando'
  mensajeError.value = ''
  try {
    const activo = await obtenerEventoActivo()
    if (!activo) {
      filas.value = []
      estado.value = 'vacio'
      return
    }
    evento.value = activo
    await refrescar()
    // Realtime: cada resultado oficial nuevo entra sin refrescar la pantalla.
    registrarCanal(activo.id)
    if (!timerRefresco) {
      timerRefresco = setInterval(() => void refrescar(true), INTERVALO_REFRESCO)
    }
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

async function refrescar(silencioso = false) {
  if (!evento.value) return
  try {
    const data = await ranking(evento.value.id, 100)
    filas.value = data
    conectado.value = true
    if (data.length === 0 && !silencioso) {
      estado.value = 'vacio'
      return
    }
    ultimaActualizacionLos.value = new Date().toISOString()
  } catch (error) {
    if (!filas.value.length) {
      mensajeError.value = error.message
      estado.value = 'error'
    }
  }
}

function registrarCanal(eventoId) {
  if (desRegistrar) desRegistrar()
  desRegistrar = suscribirseARanking(eventoId, {
    onInsert: async () => {
      await refrescar(true)
    },
    onError: () => {
      conectado.value = false
    },
  })
}

onMounted(() => {
  void cargar()
})

onBeforeUnmount(() => {
  if (desRegistrar) desRegistrar()
  if (timerRefresco) clearInterval(timerRefresco)
})

function irDesafio() {
  router.push('/expotecnica/desafio')
}

function volverInicio() {
  router.push('/learn')
}
</script>

<style scoped>
.ranking {
  display: flex;
  flex-direction: column;
  gap: var(--k-space-5);
  padding-bottom: var(--k-space-7);
}

/* El indicador viaja como prop de texto del encabezado: sin estilos propios. */

.ranking-cabecera {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.ranking-evento {
  margin: 0;
  font-family: var(--k-font-brand);
  font-weight: 700;
  font-size: 15px;
}

.ranking-actualizacion {
  margin: 0;
  font-size: 12px;
  color: var(--k-text-3);
  display: flex;
  align-items: center;
  gap: 6px;
}

.ranking-refrescar {
  background: transparent;
  border: 0;
  color: var(--k-accent);
  padding: 2px;
  cursor: pointer;
}

.ranking-tabla {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.ranking-fila {
  display: grid;
  grid-template-columns: 34px 1fr auto 52px;
  align-items: center;
  gap: 10px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 10px 14px;
}

.ranking-fila.es-propio {
  border-color: var(--k-accent);
  background: var(--k-accent-softer);
}

.ranking-puesto {
  font-weight: 700;
  font-size: 15px;
  color: var(--k-text-2);
  text-align: center;
}

.ranking-puesto.oro {
  color: #ffd166;
}

.ranking-puesto.plata {
  color: #c9c9d9;
}

.ranking-puesto.bronce {
  color: #cd7f4d;
}

.ranking-alias {
  font-size: 14.5px;
  color: var(--k-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ranking-alias em {
  font-style: normal;
  font-size: 12px;
  color: var(--k-accent);
}

.ranking-detalle {
  font-size: 12px;
  color: var(--k-text-3);
  text-align: right;
}

.ranking-detalle em {
  font-style: normal;
  color: var(--k-text-2);
}

.ranking-puntos {
  font-family: var(--k-font-brand);
  font-weight: 700;
  font-size: 15px;
  text-align: right;
}

.ranking-regla {
  color: var(--k-text-3);
  font-size: 12px;
  line-height: 1.6;
  margin: 0;
}
</style>
