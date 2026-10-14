<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Logros</p>
      <p class="pantalla-subtitulo">Supera retos y obtén recompensas</p>

      <EstadoPantalla
        tipo="vacio"
        titulo="Todavía no hay logros"
        mensaje="Completá tus lecciones para desbloquear los primeros logros."
      />
    </main>
  </div>
</template>

<script setup>
import EstadoPantalla from '@/components/EstadoPantalla.vue'
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
</style>
