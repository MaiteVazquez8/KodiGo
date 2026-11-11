<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Buscar Amigos</p>
      <p class="pantalla-subtitulo">Encuentra a tu equipo de estudio</p>

      <CampoFormulario
        v-model="busqueda"
        placeholder="Escribe un nombre de usuario..."
        inputmode="search"
      />

      <EstadoPantalla
        v-if="!busqueda.trim()"
        tipo="vacio"
        titulo="Buscá por nombre de usuario"
        mensaje="Escribí arriba para encontrar programadores."
      />

      <EstadoPantalla
        v-else-if="cargandoPerfiles"
        tipo="cargando"
        titulo="Buscando…"
        mensaje="Un momento."
      />

      <EstadoPantalla
        v-else-if="!resultados.length"
        tipo="inexistente"
        titulo="Sin resultados"
        mensaje="No encontramos a nadie con ese nombre."
      />

      <ul v-else class="resultados">
        <li v-for="persona in resultados" :key="persona.alias" class="resultado">
          <span class="resultado-avatar">{{ persona.alias.charAt(0).toUpperCase() }}</span>
          <div class="resultado-datos">
            <p class="resultado-alias">{{ persona.alias }}</p>
            <p class="resultado-nivel">Nivel {{ persona.nivel }}</p>
          </div>
          <button
            type="button"
            class="resultado-agregar"
            :disabled="enviando === persona.alias || enviadas.has(persona.alias)"
            @click="agregar(persona)"
          >
            {{ enviadas.has(persona.alias) ? 'Enviada' : 'Agregar' }}
          </button>
        </li>
      </ul>

      <p v-if="aviso" class="resultado-aviso">{{ aviso }}</p>
    </main>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import CampoFormulario from '@/components/CampoFormulario.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { estado as estadoAuth } from '@/services/auth'
import { enviarSolicitudAmistad, obtenerPerfilesPublicos } from '@/services/catalogo'

const busqueda = ref('')
const perfiles = ref([])
const cargandoPerfiles = ref(false)
const intentoPerfiles = ref(false)
const enviando = ref('')
const enviadas = ref(new Set())
const aviso = ref('')

// La lista de perfiles publicos se carga una sola vez y se filtra en el
// cliente: pedirla en cada tecla satura la base sin ganar nada.
async function asegurarPerfiles() {
  if (perfiles.value.length || cargandoPerfiles.value || intentoPerfiles.value) return
  intentoPerfiles.value = true
  cargandoPerfiles.value = true
  try {
    perfiles.value = await obtenerPerfilesPublicos()
    aviso.value = ''
  } catch {
    perfiles.value = []
    aviso.value = estadoAuth.usuario
      ? 'No se pudo cargar la lista. Revisá tu conexión.'
      : 'Iniciá sesión para ver a otros programadores.'
  } finally {
    cargandoPerfiles.value = false
  }
}

watch(
  busqueda,
  (valor) => {
    if (valor.trim().length >= 2) asegurarPerfiles()
  },
  { immediate: true },
)

const resultados = computed(() => {
  const texto = busqueda.value.trim().toLowerCase()
  if (texto.length < 2) return []
  return perfiles.value.filter((perfil) => perfil.alias.toLowerCase().includes(texto)).slice(0, 10)
})

async function agregar(persona) {
  if (!estadoAuth.usuario) {
    aviso.value = 'Iniciá sesión para enviar solicitudes de amistad.'
    return
  }
  enviando.value = persona.alias
  aviso.value = ''
  try {
    await enviarSolicitudAmistad(persona.alias)
    enviadas.value.add(persona.alias)
    enviadas.value = new Set(enviadas.value)
    aviso.value = `Solicitud enviada a ${persona.alias}.`
  } catch (error) {
    aviso.value = error.message
  } finally {
    enviando.value = ''
  }
}
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

.pantalla .campo-formulario {
  margin-top: var(--k-space-5);
}

.resultados {
  margin: var(--k-space-5) 0 0;
  padding: 0;
  list-style: none;
  display: grid;
  gap: var(--k-space-3);
}

.resultado {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  padding: var(--k-space-3);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.resultado-avatar {
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

.resultado-alias {
  font-size: 14.5px;
  font-weight: 800;
}

.resultado-nivel {
  font-size: 12.5px;
  color: var(--k-text-2);
}

.resultado-agregar {
  flex-shrink: 0;
  padding: 6px 12px;
  border-radius: 999px;
  border: 1px solid rgba(142, 5, 194, 0.5);
  background: rgba(142, 5, 194, 0.16);
  color: var(--k-accent);
  font-size: 11.5px;
  font-weight: 800;
  cursor: pointer;
}

.resultado-agregar:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.resultado-aviso {
  margin-top: var(--k-space-4);
  font-size: 12.5px;
  color: var(--k-text-2);
}
</style>
