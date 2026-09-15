<template>
  <span v-if="imageSrc" class="course-logo" :class="[`tone-${tone}`]">
    <img :src="imageSrc" :alt="course.name" class="course-logo-img" draggable="false" />
  </span>
  <span v-else class="course-logo mono" :class="[`tone-${tone}`]" :style="monogramStyle">
    {{ course.monogram }}
  </span>
</template>

<script setup>
import { computed } from 'vue'
import { getCourseImage } from '@/assets/img'

const props = defineProps({
  course: {
    type: Object,
    required: true,
  },
  tone: {
    type: String,
    default: 'card',
  },
})

const imageSrc = computed(() => getCourseImage(props.course.logo || props.course.id))

const monogramStyle = computed(() => {
  const accent = props.course.accent
  return {
    background: `${accent}22`,
    color: accent,
    borderColor: `${accent}44`,
  }
})
</script>

<style scoped>
.course-logo {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  border-radius: 16px;
  border: 1px solid transparent;
  overflow: hidden;
}

.course-logo.tone-card {
  width: 54px;
  height: 54px;
}

.course-logo.tone-hero {
  width: 68px;
  height: 68px;
  border-radius: 20px;
}

.course-logo-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  padding: 9px;
}

.tone-hero .course-logo-img {
  padding: 10px;
}

.mono {
  font-family: var(--k-font-code);
  font-weight: 600;
}

.tone-card.mono {
  font-size: 17px;
}

.tone-hero.mono {
  font-size: 22px;
}
</style>
