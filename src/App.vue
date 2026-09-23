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

const rutasNavegacion = ['inicio', 'cursos', 'curso']

const mostrarNavegacion = computed(() => rutasNavegacion.includes(ruta.name))
</script>
