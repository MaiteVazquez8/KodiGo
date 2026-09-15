<template>
  <div class="ghost-bubble">
    <KodigoGhost :size="ghostSize" :variant="mood" class="ghost-bubble-avatar" />
    <div class="ghost-bubble-box">
      <p v-if="message" class="ghost-bubble-text">{{ message }}</p>
      <slot />
    </div>
  </div>
</template>

<script setup>
import KodigoGhost from './KodigoGhost.vue'

defineProps({
  message: {
    type: String,
    default: '',
  },
  ghostSize: {
    type: [Number, String],
    default: 72,
  },
  mood: {
    type: String,
    default: 'normal',
  },
})
</script>

<style scoped>
.ghost-bubble {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-4);
}

.ghost-bubble-avatar {
  flex-shrink: 0;
}

.ghost-bubble-box {
  position: relative;
  flex: 1;
  background: var(--k-surface-2);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius);
  padding: 18px 20px;
}

.ghost-bubble-box::before {
  content: '';
  position: absolute;
  top: 24px;
  left: -8px;
  width: 16px;
  height: 16px;
  background: var(--k-surface-2);
  border-left: 1px solid var(--k-line);
  border-bottom: 1px solid var(--k-line);
  transform: rotate(45deg);
}

.ghost-bubble-text {
  font-size: 15px;
  line-height: 1.5;
  color: var(--k-text);
}

.ghost-bubble.is-avatar-top {
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.ghost-bubble.is-avatar-top .ghost-bubble-box::before {
  top: -8px;
  left: 50%;
  transform: translateX(-50%) rotate(45deg);
  border-top: 1px solid var(--k-line);
  border-right: 1px solid var(--k-line);
  border-left: 0;
  border-bottom: 0;
}
</style>
