<template>
  <div class="activity-runner">
    <h2 class="activity-statement">{{ actividadActual.statement }}</h2>

    <BloqueCodigo v-if="actividadActual.code" :code="actividadActual.code" class="activity-code" />

    <div v-if="isChoice" class="options">
      <button
        v-for="(option, index) in actividadActual.options"
        :key="index"
        type="button"
        class="option"
        :class="optionClasses(index)"
        :disabled="submitted"
        @click="pick(index)"
      >
        <span class="option-letter k-mono">{{ letters[index] }}</span>
        <code class="option-text k-mono">{{ option }}</code>
      </button>
    </div>

    <div v-else-if="isOrder" class="order">
      <p class="order-label">Tocá las líneas en el orden correcto:</p>
      <div class="order-pool">
        <button
          v-for="item in pool"
          :key="item.index"
          type="button"
          class="line-chip"
          :disabled="submitted"
          @click="chooseLine(item)"
        >
          {{ item.line }}
        </button>
      </div>
      <div class="order-stack">
        <button
          v-for="(item, index) in chosen"
          :key="item.index"
          type="button"
          class="line-chip is-chosen"
          :disabled="submitted"
          @click="unchoose(item)"
        >
          <span class="order-number k-mono">{{ index + 1 }}</span>
          {{ item.line }}
        </button>
        <p v-if="!chosen.length" class="order-empty">Las líneas elegidas van a aparecer acá.</p>
      </div>
    </div>

    <div v-else class="answer-field">
      <input
        v-if="activity.type === 'fill'"
        v-model="typed"
        type="text"
        class="text-input k-mono"
        :placeholder="placeholder"
        :disabled="submitted"
        @keyup.enter="handleAction"
      />
      <textarea
        v-else
        v-model="typed"
        class="text-input k-mono"
        rows="3"
        :placeholder="placeholder"
        :disabled="submitted"
      ></textarea>
      <p class="answer-hint">{{ hint }}</p>
    </div>

    <transition name="fade">
      <div v-if="submitted" class="feedback" :class="feedbackClass">
        <q-icon :name="correct ? 'check_circle' : 'cancel'" size="20px" />
        <div class="feedback-body">
          <strong>{{ correct ? 'Correcto' : 'Incorrecto' }}</strong>
          <p>{{ correct ? actividadActual.explanation : wrongMessage }}</p>
        </div>
      </div>
    </transition>

    <button
      type="button"
      class="k-btn k-btn--primary k-btn--block action-main"
      :disabled="!canCheck"
      @click="handleAction"
    >
      {{ actionLabel }}
    </button>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import BloqueCodigo from './BloqueCodigo.vue'

const props = defineProps({
  activity: {
    type: Object,
    required: false,
    default: null,
  },
  actividad: {
    type: Object,
    required: false,
    default: null,
  },
})

const emit = defineEmits(['submit', 'next'])

const actividadActual = computed(() => props.actividad || props.activity || {})

const letters = ['A', 'B', 'C', 'D', 'E', 'F']

const selected = ref(-1)
const typed = ref('')
const submitted = ref(false)
const correct = ref(false)
const pool = ref([])
const chosen = ref([])

const isChoice = computed(() => ['choice', 'fix'].includes(actividadActual.value.type))
const isOrder = computed(() => actividadActual.value.type === 'order')
const isText = computed(() => actividadActual.value.type === 'fill' || actividadActual.value.type === 'write')

const hint = computed(() => {
  if (actividadActual.value.type === 'write') return 'Escribí tu código y tocá Comprobar.'
  return 'Escribí lo que falta y tocá Comprobar.'
})

const placeholder = computed(() =>
  actividadActual.value.type === 'write' ? 'let miVariable = …;' : 'Escribí el fragmento que falta…',
)

const wrongMessage = computed(() => {
  if (actividadActual.value.explanation) {
    return actividadActual.value.explanation
  }
  if (isOrder.value)
    return 'Algunas líneas no están en el orden correcto. Revisá e intentalo de nuevo.'
  return 'Revisá tu respuesta e intentalo de nuevo.'
})

const canCheck = computed(() => {
  if (!submitted.value) {
    if (isText.value) return typed.value.trim().length > 0
    if (isOrder.value) return chosen.value.length === (actividadActual.value.lines?.length || 0)
    return selected.value !== -1
  }
  return true
})

const actionLabel = computed(() => {
  if (!submitted.value) return 'Confirmar'
  return 'Continuar'
})

const feedbackClass = computed(() =>
  submitted.value ? (correct.value ? 'is-correct' : 'is-wrong') : '',
)

function initOrder() {
  const lines = actividadActual.value.lines || []
  const shuffled = lines
    .map((line, index) => ({ line, index }))
    .sort(() => Math.random() - 0.5)
  pool.value = shuffled
  chosen.value = []
}

function reset() {
  selected.value = -1
  typed.value = ''
  submitted.value = false
  correct.value = false
  if (isOrder.value) initOrder()
}

watch(
  () => actividadActual.value?.id,
  () => reset(),
  { immediate: true },
)

function pick(index) {
  selected.value = index
}

function chooseLine(item) {
  chosen.value.push(item)
  pool.value = pool.value.filter((p) => p !== item)
}

function unchoose(item) {
  chosen.value = chosen.value.filter((c) => c !== item)
  pool.value.push(item)
}

function normalize(value) {
  return String(value || '')
    .replace(/\s+/g, '')
    .toLowerCase()
    .replace(/^['"]|['"]$/g, '')
    .replace(/;+$/, '')
}

function isAnswerCorrect() {
  if (isOrder.value) {
    return (
      chosen.value.length === (actividadActual.value.lines?.length || 0) &&
      chosen.value.every((item, index) => item.index === index)
    )
  }
  if (isText.value) {
    return (actividadActual.value.expected || []).some((answer) => normalize(typed.value) === normalize(answer))
  }
  return selected.value === actividadActual.value.answer
}

function optionClasses(index) {
  if (!submitted.value) {
    return { 'is-selected': selected.value === index }
  }
  const isAnswer = index === actividadActual.value.answer
  const isWrongChoice = selected.value === index && !isAnswer
  return { 'is-answer': isAnswer, 'is-wrong-choice': isWrongChoice }
}

function handleAction() {
  if (!submitted.value) {
    submitted.value = true
    correct.value = isAnswerCorrect()
    emit('submit', correct.value)
    return
  }

  emit('next')
}
</script>

<style scoped>
.activity-runner {
  display: grid;
  gap: var(--k-space-4);
}

.activity-statement {
  font-size: 18px;
  font-weight: 700;
  line-height: 1.45;
}

.activity-code {
  margin-top: var(--k-space-1);
}

.options {
  display: grid;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
}

.option {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 100%;
  padding: 14px 16px;
  border-radius: 16px;
  border: 2px solid var(--k-line);
  background: linear-gradient(180deg, rgba(24, 9, 31, 0.96), rgba(12, 6, 17, 1));
  color: var(--k-text);
  cursor: pointer;
  text-align: left;
  transition:
    border-color 0.12s ease,
    background 0.12s ease,
    transform 0.08s ease;
  -webkit-tap-highlight-color: transparent;
}

.option-letter {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  flex-shrink: 0;
  border-radius: 9px;
  background: var(--k-surface);
  border: 1px solid var(--k-line);
  font-size: 13px;
  font-weight: 600;
  color: var(--k-text-2);
}

.option-text {
  font-size: 13px;
  color: var(--k-text);
  white-space: pre-wrap;
  word-break: break-word;
}

.option.is-selected {
  border-color: var(--k-accent);
  background: var(--k-accent-soft);
}

.option.is-selected .option-letter {
  border-color: var(--k-accent);
  color: var(--k-accent);
}

.option.is-answer {
  border-color: var(--k-success);
  background: rgba(52, 211, 153, 0.12);
}

.option.is-answer .option-letter {
  border-color: var(--k-success);
  color: var(--k-success);
}

.option.is-wrong-choice {
  border-color: var(--k-error);
  background: rgba(255, 93, 115, 0.1);
}

.option.is-wrong-choice .option-letter {
  border-color: var(--k-error);
  color: var(--k-error);
}

.order {
  margin-top: var(--k-space-5);
  display: grid;
  gap: var(--k-space-4);
}

.order-label {
  font-size: 13px;
  font-weight: 700;
  color: var(--k-text-2);
}

.order-pool {
  display: grid;
  gap: var(--k-space-3);
}

.order-stack {
  display: grid;
  gap: var(--k-space-3);
  min-height: 56px;
  padding: 14px;
  border-radius: var(--k-radius-sm);
  border: 2px dashed var(--k-line);
}

.line-chip {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1.5px solid var(--k-line);
  background: rgba(17, 10, 22, 0.95);
  color: #d9c8ef;
  font-family: var(--k-font-code);
  font-size: 12.5px;
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.line-chip.is-chosen {
  border-color: var(--k-accent);
  background: var(--k-accent-soft);
}

.order-number {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 6px;
  border-radius: 7px;
  background: var(--k-accent);
  color: #fff;
  font-size: 12px;
  font-weight: 600;
}

.order-empty {
  align-self: center;
  text-align: center;
  font-size: 12.5px;
  color: var(--k-text-3);
}

.answer-field {
  margin-top: var(--k-space-5);
}

.text-input {
  width: 100%;
  padding: 14px 16px;
  border-radius: var(--k-radius-sm);
  border: 2px solid var(--k-line);
  background: var(--k-surface);
  color: var(--k-text);
  font-size: 14px;
  line-height: 1.5;
  outline: none;
  resize: vertical;
  transition: border-color 0.12s ease;
}

.text-input:focus {
  border-color: var(--k-accent);
}

.answer-hint {
  margin-top: var(--k-space-2);
  font-size: 12px;
  color: var(--k-text-3);
}

.feedback {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
  padding: 14px 16px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
}

.feedback.is-correct {
  border-color: rgba(52, 211, 153, 0.4);
  background: rgba(52, 211, 153, 0.1);
}

.feedback.is-wrong {
  border-color: rgba(255, 93, 115, 0.4);
  background: rgba(255, 93, 115, 0.1);
}

.feedback.is-correct .q-icon {
  color: var(--k-success);
}

.feedback.is-wrong .q-icon {
  color: var(--k-error);
}

.feedback-body strong {
  display: block;
  font-size: 14px;
}

.feedback-body p {
  margin-top: var(--k-space-1);
  font-size: 13px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.action-main {
  margin-top: var(--k-space-6);
}

.fade-enter-active,
.fade-leave-active {
  transition:
    opacity 0.15s ease,
    transform 0.15s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(4px);
}
</style>
