<template>
  <div class="k-screen">
    <main class="k-container simple">
      <p class="simple-titulo k-h1">Dictionary</p>
      <EstadoPantalla
        tipo="vacio"
        titulo="Diccionario vacío"
        mensaje="Los términos que veas en tus lecciones se van a guardar acá."
      />
    </main>
  </div>
</template>

<script setup>
import EstadoPantalla from '@/components/EstadoPantalla.vue'
</script>

<style scoped>
.simple {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.simple-titulo {
  margin-top: var(--k-space-2);
}
</style>
