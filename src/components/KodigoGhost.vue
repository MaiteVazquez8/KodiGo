<template>
  <img class="kodigo-ghost" :src="src" :alt="alt" :style="styleObject" draggable="false" />
</template>

<script setup>
import { computed } from 'vue'
import ghostBored from '@/assets/img/fantasmaAburrido.png'
import ghostHappy from '@/assets/img/fantasmaFeliz.png'
import ghostNormal from '@/assets/img/fantasmaNormal.png'
import ghostSad from '@/assets/img/fantasmaTriste.png'

const props = defineProps({
  size: {
    type: [Number, String],
    default: 96,
  },
  variant: {
    type: String,
    default: 'normal',
  },
  alt: {
    type: String,
    default: 'Fantasma de Kodigo',
  },
})

const variants = { normal: ghostNormal, happy: ghostHappy, bored: ghostBored, sad: ghostSad }

const src = computed(() => variants[props.variant] || ghostNormal)
const styleObject = computed(() => ({ width: `${props.size}px`, height: `${props.size}px` }))
</script>

<style scoped>
.kodigo-ghost {
  display: block;
  user-select: none;
  object-fit: contain;
}
</style>
