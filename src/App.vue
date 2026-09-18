<template>
  <div class="k-app" :class="{ 'with-nav': showNav }">
    <RouterView />
    <BottomNav v-if="showNav" />
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import BottomNav from '@/components/BottomNav.vue'

const route = useRoute()

const NAV_ROUTES = ['home', 'courses', 'course', 'ranking', 'friends', 'profile']

const showNav = computed(() => NAV_ROUTES.includes(route.name))
</script>
