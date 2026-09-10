<template>
  <div class="screen">
    <header class="header">
      <h1 class="title">Aprendé Python</h1>
      <p class="subtitle">Unidad 1 · Fundamentos</p>

      <div class="progress">
        <div class="progress-track"><span class="progress-fill"></span></div>
        <div class="progress-meta">3 de 10 niveles · 30%</div>
      </div>
    </header>

    <main class="map">
      <section
        v-for="unit in units"
        :key="unit.id"
        class="unit"
        :style="{ animationDelay: unit.delay }"
      >
        <div class="unit-head">
          <span class="unit-line unit-line-left"></span>
          <div class="unit-head-inner">
            <div class="unit-chip">Unidad {{ unit.id }}</div>
            <h2 class="unit-title">{{ unit.title }}</h2>
          </div>
          <span class="unit-line unit-line-right"></span>
        </div>

        <div class="levels">
          <template v-for="level in unit.levels" :key="level.n">
            <div v-if="level.connClass" class="path" :class="level.connClass"></div>
            <div class="level" :class="'side-' + level.side">
              <div class="node" :class="'node-' + level.state">
                <q-icon v-if="level.state === 'done'" name="check" class="node-icon" />
                <q-icon v-else-if="level.state === 'locked'" name="lock" class="node-icon" />
                <span v-else class="node-number">{{ level.n }}</span>
              </div>
              <div class="level-label">
                <div class="level-n" :class="'n-' + level.state">Nivel {{ level.n }}</div>
                <div class="level-title" :class="'title-' + level.state">{{ level.title }}</div>
              </div>
            </div>
          </template>
        </div>
      </section>
    </main>
  </div>
</template>

<script setup>
const units = [
  {
    id: 1,
    title: 'Fundamentos',
    delay: '0.05s',
    levels: [
      { n: 1, title: '¿Qué es programar?', state: 'done', side: 'center' },
      { n: 2, title: 'Variables', state: 'done', side: 'left', connClass: 'path-done' },
      { n: 3, title: 'Tipos de datos', state: 'done', side: 'right', connClass: 'path-done' },
      { n: 4, title: 'Operadores', state: 'current', side: 'left', connClass: 'path-done' },
      { n: 5, title: 'Condicionales', state: 'locked', side: 'right', connClass: 'path-muted' },
    ],
  },
  {
    id: 2,
    title: 'Estructuras de control',
    delay: '0.20s',
    levels: [
      { n: 6, title: 'Bucles', state: 'locked', side: 'center' },
      { n: 7, title: 'Funciones', state: 'locked', side: 'left', connClass: 'path-muted' },
    ],
  },
  {
    id: 3,
    title: 'Primer proyecto',
    delay: '0.35s',
    levels: [
      { n: 8, title: 'Proyecto guiado', state: 'locked', side: 'right' },
      { n: 9, title: 'Desafío final', state: 'locked', side: 'center', connClass: 'path-muted' },
    ],
  },
]
</script>

<style>
:root {
  --bg: #14121f;
  --violet: #6d56d8;
  --violet-strong: #7a5cf0;
  --text: #f5f2ff;
  --text-2: #a9a0cf;
  --text-3: #7c749c;
  --line: #211d35;
  --app-font: 'Manrope', sans-serif;
}

html,
body {
  margin: 0;
  padding: 0;
  background: var(--bg);
}

body {
  -webkit-font-smoothing: antialiased;
  overscroll-behavior: none;
  overflow-x: hidden;
}
</style>

<style scoped>
.screen {
  min-height: 100vh;
  font-family: var(--app-font);
  color: var(--text);
  background: var(--bg);
  -webkit-tap-highlight-color: transparent;
  padding-top: max(26px, env(safe-area-inset-top));
  padding-bottom: max(48px, env(safe-area-inset-bottom));
}

.header {
  max-width: 400px;
  margin: 0 auto;
  padding: 0 24px 22px;
  border-bottom: 1px solid var(--line);
}

.title {
  margin: 0;
  font-size: 27px;
  font-weight: 800;
  letter-spacing: -0.01em;
  line-height: 1.15;
}

.subtitle {
  margin: 6px 0 0;
  font-size: 13px;
  color: var(--text-2);
}

.progress {
  margin-top: 20px;
}

.progress-track {
  height: 5px;
  border-radius: 99px;
  background: #262239;
  overflow: hidden;
}

.progress-fill {
  display: block;
  width: 30%;
  height: 100%;
  border-radius: inherit;
  background: var(--violet-strong);
}

.progress-meta {
  margin-top: 8px;
  font-size: 11.5px;
  color: var(--text-3);
}

.map {
  max-width: 400px;
  margin: 0 auto;
  padding: 30px 24px 0;
}

.unit {
  animation: fade 0.5s ease both;
}

.unit + .unit {
  margin-top: 48px;
}

.unit-head {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 26px;
}

.unit-line {
  flex: 1;
  height: 1px;
  background: var(--line);
}

.unit-head-inner {
  text-align: center;
}

.unit-chip {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: #9c8cff;
}

.unit-title {
  margin: 3px 0 0;
  font-size: 18px;
  font-weight: 700;
}

.path {
  width: 3px;
  height: 30px;
  margin: 0 auto;
  border-radius: 99px;
}

.path-done {
  background: var(--violet);
}

.path-muted {
  background: #2b2740;
}

.level {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 0 10px;
}

.side-left.level {
  margin-left: 9%;
}

.side-right.level {
  margin-right: 9%;
}

.node {
  width: 54px;
  height: 54px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.25);
}

.node-done {
  background: var(--violet);
}

.node-done .node-icon {
  font-size: 22px;
  color: #fff;
}

.node-current {
  width: 56px;
  height: 56px;
  background: #fff;
  border: 2px solid var(--violet);
}

.node-number {
  font-size: 21px;
  font-weight: 800;
  color: #5b3fd4;
}

.node-locked {
  background: #262239;
  box-shadow: none;
}

.node-locked .node-icon {
  font-size: 20px;
  color: #6b6485;
}

.level-label {
  margin-top: 10px;
  text-align: center;
  max-width: 170px;
}

.level-n {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--text-3);
}

.level-title {
  margin-top: 3px;
  font-size: 13.5px;
  font-weight: 700;
  line-height: 1.3;
}

.title-done {
  color: #e6e1ff;
}

.title-current {
  color: #fff;
}

.title-locked {
  color: #6b6485;
}

@keyframes fade {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .unit {
    animation: none;
  }
}
</style>
