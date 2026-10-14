<template>
  <div class="k-screen">
    <main class="k-container simple">
      <p class="simple-titulo k-h1">Review</p>
      <EstadoPantalla
        tipo="vacio"
        titulo="Todavía no hay repasos"
        mensaje="Cuando termines una lección vas a poder repasarla desde acá."
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
