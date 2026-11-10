<template>
  <div class="k-app" :class="{ 'with-nav': mostrarNavegacion }">
    <RouterView />
    <NavegacionInferior v-if="mostrarNavegacion" />
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import NavegacionInferior from '@/components/NavegacionInferior.vue'

const ruta = useRoute()

const rutasSinNavegacion = [
  'bienvenida',
  'acceso',
  'learn',
  'registro',
  'ingreso',
  'recuperar',
  'restablecer',
  // Desafío ExpoTécnica: durante la partida y en el panel no hay navegación.
  'expotecnica-desafio',
  'expotecnica-ranking',
  'admin',
]

const mostrarNavegacion = computed(
  () => ruta.name !== null && !rutasSinNavegacion.includes(ruta.name),
)
</script>
