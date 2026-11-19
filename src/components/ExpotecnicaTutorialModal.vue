<template>
  <div v-if="abierto" class="expotec-tutorial-overlay" role="dialog" aria-modal="true" :aria-label="'Mini repaso para el desafío ExpoTécnica'">
    <div class="expotec-tutorial-caja">
      <header class="expotec-tutorial-header">
        <div class="expotec-tutorial-eyebrow">
          <q-icon name="menu_book" size="18px" />
          <span>Repaso rápido · sin respuestas</span>
        </div>
        <button type="button" class="expotec-tutorial-cerrar" aria-label="Cerrar repaso" @click="$emit('cerrar')">
          <q-icon name="close" size="22px" />
        </button>
      </header>

      <div class="expotec-tutorial-contenido">
        <p class="expotec-tutorial-intro">
          Antes de entrar, un vistazo veloz a los diez conceptos que aparecen en el cuestionario de JavaScript.
          Acá no hay respuestas: solo recordatorios de cómo suenan las cosas.
        </p>

        <ol class="expotec-tutorial-lista">
          <li
            v-for="(item, i) in pasos"
            :key="i"
            class="expotec-tutorial-paso"
            :class="{ 'es-actual': indexActivo === i }"
            @click="indexActivo = i"
          >
            <span class="expotec-tutorial-numero k-mono">{{ String(i + 1).padStart(2, '0') }}</span>
            <div>
              <p class="expotec-tutorial-titulo">{{ item.titulo }}</p>
              <p class="expotec-tutorial-regla">{{ item.regla }}</p>
              <p class="expotec-tutorial-ejemplo k-mono">{{ item.ejemplo }}</p>
            </div>
          </li>
        </ol>

        <aside class="expotec-tutorial-pista">
          <q-icon name="tips_and_updates" size="18px" />
          <p>
            Prestá atención al tipo de dato: varios ejercicios dependen de qué tipo hay del otro lado del operador o qué obtuviste.
            Llevá esto presente y el resto viene solo.
          </p>
        </aside>
      </div>

      <footer class="expotec-tutorial-acciones">
        <button type="button" class="k-btn k-btn--ghost" @click="$emit('cerrar')">
          Saltar y participar
        </button>
        <button type="button" class="k-btn k-btn--primary k-btn--lg" @click="$emit('cerrar')">
          <q-icon name="sports_esports" size="18px" />
          ¡Listo, participar!
        </button>
      </footer>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

defineProps({
  abierto: { type: Boolean, default: false },
})

defineEmits(['cerrar'])

const indexActivo = ref(0)

const pasos = [
  {
    titulo: 'El + con texto mixto',
    regla: 'Si un operando es una cadena, + concatena; si ambos son números, suma.',
    ejemplo: '2 + "2"  →  "22"',
  },
  {
    titulo: 'const, let y var',
    regla: 'const declara un enlace que no se puede reasignar; let sí; var es el viejo esclavo de funciones.',
    ejemplo: 'const pi = 3.14\nlet contador = 0',
  },
  {
    titulo: 'typeof y los arrays',
    regla: 'typeof devuelve un string con el tipo; los arrays son objetos y no un tipo propio.',
    ejemplo: 'typeof 42\ntypeof "hola"\ntypeof []  // "object"',
  },
  {
    titulo: '=== vs ==',
    regla: '=== compara valor y tipo sin hacer conversiones; == acepta coerciones antes de comparar.',
    ejemplo: '1 === 1\n1 === "1"\n1 == "1"  // true',
  },
  {
    titulo: '.map() devuelve otro array',
    regla: 'map aplica una función a cada elemento y devuelve un array nuevo; el original queda igual.',
    ejemplo: '[2, 4, 6].map(x => x / 2)  // [1, 2, 3]',
  },
  {
    titulo: 'push / pop / shift / unshift',
    regla: 'push agrega al final; pop quita del final; shift quita del principio; unshift agrega al principio.',
    ejemplo: 'const a = [1, 2]\na.push(3)  // [1, 2, 3]',
  },
  {
    titulo: 'Funciones flecha',
    regla: 'El parámetro entre (); la expresión tras => es el valor que devuelve la función.',
    ejemplo: 'const doble = x => x * 2\ndoble(3)  // 6',
  },
  {
    titulo: 'break dentro de switch',
    regla: 'Corta la ejecución del switch y salta fuera; si falta, fluye al siguiente case.',
    ejemplo: 'switch (n) { case 1: ...; break; }',
  },
  {
    titulo: 'Parámetros por defecto',
    regla: 'El valor por defecto se asigna con = en la firma de la función.',
    ejemplo: 'function saludo(nombre = "invitado") {}',
  },
  {
    titulo: 'while vs for',
    regla: 'while repite mientras la condición sea verdadera; for cuando sabés cuántas vueltas va a dar.',
    ejemplo: 'while (n < 10) { n++ }\nfor (let i = 0; i < 10; i++) {}',
  },
]
</script>

<style scoped>
.expotec-tutorial-overlay {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: grid;
  place-items: center;
  padding: 16px;
  background: rgba(0, 0, 0, 0.78);
  backdrop-filter: blur(3px);
  -webkit-backdrop-filter: blur(3px);
}

.expotec-tutorial-caja {
  width: 100%;
  max-width: 520px;
  max-height: min(720px, 92vh);
  overflow: hidden;
  display: grid;
  grid-template-rows: auto 1fr auto;
  border-radius: var(--k-radius);
  background: #170723;
  border: 1px solid rgba(142, 5, 194, 0.45);
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.6);
}

.expotec-tutorial-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px 10px;
  border-bottom: 1px solid rgba(142, 5, 194, 0.25);
}

.expotec-tutorial-eyebrow {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--k-accent);
}

.expotec-tutorial-cerrar {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 10px;
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text-2);
  cursor: pointer;
  transition: color 0.14s ease, border-color 0.14s ease;
}

.expotec-tutorial-cerrar:hover {
  color: var(--k-text);
  border-color: var(--k-accent);
}

.expotec-tutorial-contenido {
  overflow-y: auto;
  padding: 16px;
  display: grid;
  gap: 12px;
}

.expotec-tutorial-intro {
  font-size: 13px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.expotec-tutorial-lista {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 8px;
}

.expotec-tutorial-paso {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 12px;
  align-items: flex-start;
  padding: 10px 12px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: rgba(142, 5, 194, 0.05);
  cursor: pointer;
  transition: border-color 0.14s ease, background 0.14s ease;
}

.expotec-tutorial-paso.es-actual,
.expotec-tutorial-paso:hover {
  border-color: rgba(142, 5, 194, 0.4);
  background: rgba(142, 5, 194, 0.08);
}

.expotec-tutorial-numero {
  font-size: 12px;
  font-weight: 700;
  color: var(--k-text-3);
  padding-top: 2px;
}

.expotec-tutorial-titulo {
  font-size: 13.5px;
  font-weight: 800;
}

.expotec-tutorial-regla {
  margin-top: 3px;
  font-size: 12.5px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.expotec-tutorial-ejemplo {
  margin-top: 6px;
  padding: 6px 10px;
  border-radius: 8px;
  background: rgba(0, 0, 0, 0.35);
  border: 1px solid rgba(142, 5, 194, 0.2);
  font-size: 12px;
  line-height: 1.45;
  color: #c89be0;
  white-space: pre;
}

.expotec-tutorial-pista {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 12px;
  border-radius: var(--k-radius-sm);
  border: 1px dashed rgba(142, 5, 194, 0.3);
  color: var(--k-text-2);
  font-size: 12px;
  line-height: 1.5;
}

.expotec-tutorial-pista .q-icon {
  color: var(--k-accent);
  flex-shrink: 0;
  margin-top: 2px;
}

.expotec-tutorial-acciones {
  display: flex;
  gap: 10px;
  padding: 12px 16px;
  border-top: 1px solid rgba(142, 5, 194, 0.25);
  justify-content: space-between;
}
</style>
