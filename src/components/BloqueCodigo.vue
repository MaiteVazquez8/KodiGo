<template>
  <pre class="code-block"><code class="k-mono"><template v-for="(part, index) in segments" :key="index"><span v-if="part.blank" class="code-blank">___</span><span v-else>{{ part.text }}</span></template></code></pre>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  code: {
    type: String,
    default: '',
  },
})

// El contenido viene del seed como texto con escapes literales (\n), no como
// saltos de línea reales. Sin normalizar, el bloque se renderiza en una sola
// línea con "\n" a la vista.
const normalizado = computed(() =>
  String(props.code ?? '')
    .replace(/\\r\\n|\\n|\\r/g, '\n')
    .replace(/\\t/g, '\t'),
)

const segments = computed(() => {
  const parts = normalizado.value.split('___')
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
  padding: 16px 18px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  border-radius: var(--k-radius-sm);
  color: #d9c8ef;
  font-size: 13px;
  line-height: 1.7;
  /* Envolver en vez de scrollear: el bloque queda contenido en el ancho. */
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

.code-blank {
  display: inline-block;
  min-width: 40px;
  padding: 1px 8px;
  border-radius: 6px;
  background: var(--k-accent-soft);
  border: 1px dashed var(--k-accent);
  color: var(--k-accent);
  font-weight: 600;
  text-align: center;
}
</style>