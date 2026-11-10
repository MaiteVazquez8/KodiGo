<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Desafío ExpoTécnica" :back="'/learn'" />

    <main class="k-container expo">
      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar el desafío"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="estado === 'sin-evento'"
        variant="bored"
        eyebrow="Eventos"
        titulo="No hay desafío activo"
        mensaje="El próximo Desafío ExpoTécnica todavía no arrancó. Cuando el evento se active, vas a poder entrar desde acá o desde la tarjeta del inicio."
        accion-label="Volver al inicio"
        @accion="volverInicio"
      />

      <template v-else>
        <section class="expo-portada">
          <FantasmaKodigo :size="92" variant="happy" class="expo-ghost" />
          <p class="k-eyebrow expo-eyebrow">Kodigo presenta</p>
          <h1 class="k-h1 expo-titulo">{{ evento.nombre }}</h1>
          <p class="expo-desafio-nombre">{{ evento.desafio.nombre }} · versión {{ evento.desafio.version }}</p>
        </section>

        <section class="expo-reglas">
          <p>
            El desafío tiene dos partes:
          </p>
          <ul>
            <li>
              <strong>Cuestionario de JavaScript.</strong>
              Las preguntas se sortean y las opciones se mezclan por partida, con un cronómetro que
              corre en el servidor. Cada acierto suma {{ evento.desafio.puntosPorCorrecta }} puntos
              nada más al final, porque nadie ve las respuestas mientras juega.
            </li>
            <li>
              <strong>Core Defender.</strong>
              Un minijuego donde el escudo sigue tu puntero y proteges el núcleo mientras llegan
              meteoritos de todos lados: los que bloqueaste puntúan y los que golpean el núcleo
              te quitan vidas.
            </li>
          </ul>
          <p>
            El resultado final se publica en el ranking del evento, con desempates claros: primero
            el puntaje total, después el tiempo del cuestionario, después los puntos del juego y
            por último quién terminó antes. Jugando de invitado la partida sigue siendo tuya:
            tu identidad en el ranking es el nombre que elijas, y nadie más puede usarlo
            en este evento.
          </p>
        </section>

        <section class="expo-datos">
          <div class="expo-dato">
            <span class="expo-dato-valor">{{ evento.desafio.cantidadPreguntas }}</span>
            <span class="expo-dato-etiqueta">preguntas</span>
          </div>
          <div class="expo-dato">
            <span class="expo-dato-valor">{{ tiempoCuestionarioTexto }}</span>
            <span class="expo-dato-etiqueta">de tiempo</span>
          </div>
          <div class="expo-dato">
            <span class="expo-dato-valor">{{ evento.desafio.duracionJuegoSeg }}s</span>
            <span class="expo-dato-etiqueta">de juego</span>
          </div>
          <div class="expo-dato">
            <span class="expo-dato-valor">{{ evento.desafio.intentosPermitidos }}</span>
            <span class="expo-dato-etiqueta">{{ evento.desafio.intentosPermitidos === 1 ? 'intento' : 'intentos' }}</span>
          </div>
        </section>

        <div class="expo-acciones">
          <button type="button" class="k-btn k-btn--primary k-btn--block k-btn--lg" @click="irDesafio">
            <q-icon name="sports_esports" size="19px" />
            Participar del desafío
          </button>
          <router-link class="k-btn k-btn--ghost k-btn--block" :to="linkCursoJavaScript">
            <q-icon name="school" size="18px" />
            Aprender JavaScript
          </router-link>
          <router-link class="k-btn k-btn--ghost k-btn--block" to="/expotecnica/ranking">
            <q-icon name="leaderboard" size="18px" />
            Ver ranking
          </router-link>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import { obtenerEventoActivo } from '@/services/expotecnica'
import { aSlug, obtenerCursos } from '@/services/catalogo'

const router = useRouter()

const estado = ref('cargando')
const mensajeError = ref('')
const evento = ref(null)
const slugJavaScript = ref('')

const tiempoCuestionarioTexto = computed(() => {
  const t = evento.value?.desafio.tiempoCuestionarioSeg ?? null
  if (t == null) return 'sin límite'
  return `${Math.round(t / 60)} min`
})

const linkCursoJavaScript = computed(() => {
  if (slugJavaScript.value) {
    return { name: 'curso', params: { curso: slugJavaScript.value } }
  }
  return '/learn'
})

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    const [dataActivaData, cursos] = await Promise.all([obtenerEventoActivo(), obtenerCursos()])
    if (!dataActivaData) {
      estado.value = 'sin-evento'
      return
    }
    evento.value = dataActivaData

    // El curso JavaScript existe ya en el catálogo: su acceso directo salvut al
    // estudiar antes del desafío.
    const js = cursos.find((c) => aSlug(c.nombre) === 'javascript') || cursos[0] || null
    slugJavaScript.value = js ? aSlug(js.nombre) : ''
    estado.value = 'listo'
  } catch (error) {
    mensajeError.value = error.message
    estado.value = 'error'
  }
}

onMounted(cargar)

function irDesafio() {
  router.push('/expotecnica/desafio')
}

function volverInicio() {
  router.push('/learn')
}
</script>

<style scoped>
.expo {
  display: flex;
  flex-direction: column;
  gap: var(--k-space-6);
}

.expo-portada {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  text-align: center;
  padding-top: 12px;
}

.expo-eyebrow {
  margin: 8px 0 0;
}

.expo-titulo {
  margin: 0;
}

.expo-desafio-nombre {
  color: var(--k-text-2);
  font-size: 14px;
  margin: 0;
}

.expo-reglas {
  color: var(--k-text);
  font-size: 15px;
  line-height: 1.65;
}

.expo-reglas ul {
  margin: 12px 0;
  padding-left: 18px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.expo-datos {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
}

.expo-dato {
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  padding: 12px 8px;
  text-align: center;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.expo-dato-valor {
  font-family: var(--k-font-brand);
  font-weight: 700;
  font-size: 18px;
}

.expo-dato-etiqueta {
  font-size: 11px;
  color: var(--k-text-3);
}

.expo-acciones {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
</style>
