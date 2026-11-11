<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Diccionario</p>
      <p class="pantalla-subtitulo">Términos de programación que aparecen en tus clases</p>

      <input
        v-model="busqueda"
        type="search"
        class="dic-buscador"
        placeholder="Buscar un término..."
        aria-label="Buscar un término"
      />

      <EstadoPantalla v-if="estado === 'cargando'" tipo="cargando" />

      <EstadoPantalla
        v-else-if="estado === 'error'"
        tipo="error"
        titulo="No pudimos cargar el diccionario"
        :mensaje="mensajeError"
        accion-label="Reintentar"
        @accion="cargar"
      />

      <EstadoPantalla
        v-else-if="!filtrados.length"
        tipo="vacio"
        titulo="Sin resultados"
        mensaje="Probá con otra palabra o revisá la ortografía."
      />

      <template v-else>
        <section v-for="grupo in grupos" :key="grupo.categoria" class="dic-grupo">
          <h2 class="dic-grupo-titulo">{{ grupo.categoria }}</h2>
          <article v-for="termino in grupo.terminos" :key="termino.termino" class="dic-item">
            <p class="dic-termino">{{ termino.termino }}</p>
            <p class="dic-definicion">{{ termino.definicion }}</p>
            <pre v-if="termino.ejemplo" class="dic-ejemplo k-mono">{{ termino.ejemplo }}</pre>
          </article>
        </section>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { obtenerDiccionario } from '@/services/catalogo'

const estado = ref('cargando')
const mensajeError = ref('')
const terminos = ref([])
const busqueda = ref('')

const filtrados = computed(() => {
  const texto = busqueda.value.trim().toLowerCase()
  if (!texto) return terminos.value
  return terminos.value.filter(
    (item) =>
      item.termino.toLowerCase().includes(texto) ||
      item.definicion.toLowerCase().includes(texto),
  )
})

const grupos = computed(() => {
  const mapa = new Map()
  for (const item of filtrados.value) {
    const categoria = item.categoria || 'General'
    if (!mapa.has(categoria)) mapa.set(categoria, [])
    mapa.get(categoria).push(item)
  }
  return [...mapa.entries()].map(([categoria, lista]) => ({ categoria, terminos: lista }))
})

async function cargar() {
  estado.value = 'cargando'
  mensajeError.value = ''
  try {
    terminos.value = await obtenerDiccionario()
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

.dic-buscador {
  margin-top: var(--k-space-5);
  width: 100%;
  padding: 12px 14px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 14px;
}

.dic-buscador:focus {
  outline: none;
  border-color: var(--k-accent);
}

.dic-grupo {
  margin-top: var(--k-space-6);
}

.dic-grupo-titulo {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--k-accent);
}

.dic-item {
  margin-top: var(--k-space-3);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.dic-termino {
  font-size: 15px;
  font-weight: 800;
}

.dic-definicion {
  margin-top: 4px;
  font-size: 13px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.dic-ejemplo {
  margin: var(--k-space-3) 0 0;
  padding: var(--k-space-3);
  border-radius: 10px;
  background: rgba(12, 6, 18, 0.9);
  border: 1px solid var(--k-line);
  font-size: 12.5px;
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
