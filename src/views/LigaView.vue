<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Liga de Honor</p>
      <p class="pantalla-subtitulo">Compite con otros desarrolladores</p>

      <EstadoPantalla
        v-if="!competidores.length"
        tipo="vacio"
        titulo="La liga está vacía"
        mensaje="Todavía no hay programadores en el ranking."
      />

      <ol v-else class="liga">
        <li
          v-for="(persona, indice) in competidores"
          :key="persona.id"
          class="liga-fila"
          :class="{ 'es-yo': persona.soy }"
        >
          <span class="liga-puesto">{{ indice + 1 }}º</span>
          <span class="liga-avatar">{{ persona.alias.charAt(0).toUpperCase() }}</span>
          <div class="liga-datos">
            <p class="liga-alias">{{ persona.alias }}</p>
            <p class="liga-xp">{{ persona.experiencia }} XP</p>
          </div>
        </li>
      </ol>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { obtenerRanking } from '@/services/catalogo'
import { estado as estadoAuth } from '@/services/auth'

const competidores = ref([])

const miId = computed(() => estadoAuth.usuario?.id ?? null)

onMounted(async () => {
  try {
    const filas = await obtenerRanking()
    competidores.value = filas.map((fila) => ({
      id: fila.id,
      alias: fila.nombre_usuario,
      experiencia: fila.experiencia,
      soy: fila.id === miId.value,
    }))
  } catch {
    competidores.value = []
  }
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

.liga {
  margin: var(--k-space-6) 0 0;
  padding: 0;
  list-style: none;
  display: grid;
  gap: var(--k-space-3);
}

.liga-fila {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  padding: var(--k-space-3);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.liga-fila.es-yo {
  border-color: var(--k-accent);
  background: var(--k-accent-softer);
}

.liga-puesto {
  width: 30px;
  flex-shrink: 0;
  font-size: 12.5px;
  font-weight: 800;
  color: var(--k-text-3);
}

.liga-avatar {
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

.liga-alias {
  font-size: 14.5px;
  font-weight: 800;
}

.liga-xp {
  font-size: 12.5px;
  color: var(--k-accent);
  font-weight: 800;
}
</style>
