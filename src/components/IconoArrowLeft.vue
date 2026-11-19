<template>
  <svg
    class="icon-arrow-left"
    viewBox="0 0 24 24"
    :width="size"
    :height="size"
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <line x1="19" y1="12" x2="5" y2="12" />
    <polyline points="12 19 5 12 12 5" />
  </svg>
</template>

<script setup>
defineProps({
  size: { type: Number, default: 20 },
})
</script>

<style scoped>
.icon-arrow-left {
  flex-shrink: 0;
  stroke: currentColor;
}
</style>
