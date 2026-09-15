<template>
  <pre
    class="code-block"
  ><code class="k-mono"><template v-for="(part, index) in segments" :key="index"><span v-if="part.blank" class="code-blank">___</span><span v-else>{{ part.text }}</span></template></code></pre>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  code: {
    type: String,
    default: '',
  },
})

const segments = computed(() => {
  const parts = props.code.split('___')
  const result = []
  parts.forEach((text, index) => {
    if (index > 0) result.push({ blank: true, text: '' })
    if (text) result.push({ blank: false, text })
  })
  return result
})
</script>

<style scoped>
.code-block {
  margin: 0;
  padding: 16px 20px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  color: #d9c8ef;
  font-size: 13.5px;
  line-height: 1.6;
  overflow-x: auto;
  white-space: pre;
  -webkit-overflow-scrolling: touch;
}

.code-blank {
  display: inline-block;
  min-width: 44px;
  padding: 1px 8px;
  border-radius: 6px;
  background: var(--k-accent-soft);
  border: 1px dashed var(--k-accent);
  color: var(--k-accent);
  font-weight: 600;
  text-align: center;
}
</style>
