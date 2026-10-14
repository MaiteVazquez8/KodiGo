<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Amigos</p>
      <p class="pantalla-subtitulo">Comparte tu progreso con la comunidad</p>

      <EstadoPantalla
        tipo="vacio"
        titulo="Todavía no tenés amigos"
        mensaje="Buscá programadores y sumalos para compartir tu progreso."
      />

      <RouterLink to="/buscar-amigos" class="k-btn k-btn--primary k-btn--block pantalla-boton">
        Buscar amigos
      </RouterLink>
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

.pantalla-boton {
  margin-top: var(--k-space-5);
  text-decoration: none;
}
</style>
