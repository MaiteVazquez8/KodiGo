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
        </li>
      </ul>
    </main>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import CampoFormulario from '@/components/CampoFormulario.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { obtenerPerfilesPublicos } from '@/services/catalogo'

const busqueda = ref('')
const perfiles = ref([])

watch(
  busqueda,
  async (valor) => {
    const texto = valor.trim()
    if (texto.length < 2) {
      perfiles.value = []
      return
    }
    try {
      perfiles.value = await obtenerPerfilesPublicos()
    } catch {
      perfiles.value = []
    }
  },
  { immediate: true },
)

const resultados = computed(() => {
  const texto = busqueda.value.trim().toLowerCase()
  if (texto.length < 2) return []
  return perfiles.value.filter((perfil) => perfil.alias.toLowerCase().includes(texto)).slice(0, 10)
})
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
</style>
