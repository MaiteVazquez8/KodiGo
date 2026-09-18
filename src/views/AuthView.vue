<template>
  <div class="k-screen auth-screen">
    <main class="k-container auth">
      <RouterLink to="/" class="auth-logo k-font-brand"><b>KODI</b><strong>GO</strong></RouterLink>

      <template v-if="mode === 'welcome'">
        <p class="auth-tagline">Gamificá tu aprendizaje de código</p>
        <section class="auth-intro">
          <h1>¿Qué es Kodigo?</h1>
          <p>Kodigo es una plataforma que te permite aprender a programar de forma fácil y sencilla.</p>
        </section>
        <GhostBubble message="Nunca había sido tan fácil aprender a programar" ghost-size="66" mood="happy" class="auth-bubble" />
        <p class="auth-copy">Con Kodigo podés tener calificaciones al instante, repasar tus lecciones, tener un seguimiento actualizado de tu aprendizaje y mostrarlo a tus amigos.</p>
        <RouterLink to="/login" class="k-btn k-btn--primary k-btn--block k-btn--lg auth-action">INICIAR SESIÓN</RouterLink>
        <p class="auth-switch">¿No tenés cuenta? <RouterLink to="/register">Registrate</RouterLink></p>
      </template>

      <template v-else-if="mode === 'register'">
        <RouterLink to="/login" class="auth-back">‹ Volver</RouterLink>
        <h1 class="auth-title">Crea tu perfil</h1>
        <p class="auth-copy">Unite a miles de programadores en racha.</p>
        <form class="auth-form" @submit.prevent="goLanguage">
          <label>Nombre completo<input type="text" placeholder="Escribe tu nombre" required /></label>
          <label>Correo electrónico<input type="email" placeholder="tu@correo.com" required /></label>
          <label>Contraseña<input type="password" placeholder="Mínimo 8 caracteres" minlength="8" required /></label>
          <div class="auth-reward">▣ Obtené 100 XP extras para tu primera racha de código hoy.</div>
          <button type="submit" class="k-btn k-btn--primary k-btn--block k-btn--lg">CREAR CUENTA</button>
        </form>
        <p class="auth-switch">¿Ya tenés cuenta? <RouterLink to="/login">Iniciá sesión</RouterLink></p>
      </template>

      <template v-else>
        <h1 class="auth-title auth-title-center">{{ mode === 'language' ? 'Elegí tu lenguaje' : 'Iniciar sesión' }}</h1>
        <p class="auth-copy auth-copy-center">{{ mode === 'language' ? '¿Qué lenguaje te gustaría dominar?' : 'Continuá tu aprendizaje de código.' }}</p>
        <form v-if="mode === 'login'" class="auth-form" @submit.prevent="goLanguage">
          <label>Usuario o Correo<input type="text" placeholder="dev_juan" required /></label>
          <label>Contraseña<input type="password" placeholder="••••••••••" required /></label>
          <button type="submit" class="k-btn k-btn--primary k-btn--block k-btn--lg">INICIAR SESIÓN</button>
        </form>
        <div v-else class="language-list">
          <button v-for="language in languages" :key="language.name" type="button" class="language-option" @click="goHome">
            <span class="language-mark" :style="{ background: language.color }">{{ language.mark }}</span>
            <span><b>{{ language.name }}</b><small>{{ language.detail }}</small></span>
          </button>
          <button type="button" class="k-btn k-btn--primary k-btn--block k-btn--lg" @click="goHome">CONFIRMAR</button>
        </div>
        <p class="auth-switch">{{ mode === 'login' ? '¿No tenés cuenta?' : '¿Ya tenés cuenta?' }} <RouterLink :to="mode === 'login' ? '/register' : '/login'">{{ mode === 'login' ? 'Registrate' : 'Iniciá sesión' }}</RouterLink></p>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import GhostBubble from '@/components/GhostBubble.vue'

const route = useRoute()
const router = useRouter()
const mode = computed(() => route.meta.mode || 'welcome')
const languages = [
  { name: 'JavaScript', mark: 'JS', color: '#f7df1e', detail: 'Web, Aplicaciones Móviles, Frontend' },
  { name: 'Python', mark: 'PY', color: '#3776ab', detail: 'Fácil, Inteligencia Artificial, Ciencia de datos' },
  { name: 'Java', mark: 'JV', color: '#e76f00', detail: 'Empresarial, Robusto, Backend' },
  { name: 'C++', mark: 'C+', color: '#4f7cac', detail: 'Videojuegos, Sistemas, Alto rendimiento' },
]

function goLanguage() {
  router.push('/language')
}

function goHome() {
  router.push('/')
}
</script>

<style scoped>
.auth { min-height: calc(100vh - 32px); padding-top: 28px; }
.auth-logo { display: block; color: #fff; font-size: 25px; font-weight: 800; text-align: center; text-decoration: none; }
.auth-logo strong { color: var(--k-accent); }
.auth-tagline, .auth-switch { text-align: center; color: var(--k-text-2); font-size: 12px; }
.auth-tagline { margin-top: 8px; }
.auth-intro { margin-top: 18px; padding: 14px 12px; border: 1px solid var(--k-deep); border-radius: 10px; background: var(--k-surface-2); }
.auth-intro h1, .auth-title { font-size: 21px; font-weight: 800; }
.auth-intro p, .auth-copy { margin-top: 5px; color: var(--k-text-2); font-size: 12px; line-height: 1.35; }
.auth-bubble { margin-top: 52px; align-items: center; }
.auth-bubble :deep(.ghost-bubble-text) { font-size: 16px; font-weight: 800; }
.auth-copy { margin-top: 16px; }
.auth-action { margin-top: 64px; }
.auth-switch { margin-top: 12px; }
.auth-switch a { color: var(--k-accent); font-weight: 800; text-decoration: none; }
.auth-back { display: block; margin-top: 6px; color: var(--k-text-2); text-decoration: none; font-size: 13px; }
.auth-title { margin-top: 18px; }
.auth-title-center, .auth-copy-center { text-align: center; }
.auth-form { display: grid; gap: 13px; margin-top: 22px; }
.auth-form label { display: grid; gap: 6px; color: var(--k-text-2); font-size: 11px; font-weight: 700; }
.auth-form input { width: 100%; padding: 11px 12px; border: 1px solid var(--k-deep); border-radius: 8px; background: var(--k-surface-2); color: #fff; outline: 0; }
.auth-form input:focus { border-color: var(--k-accent); }
.auth-reward { padding: 10px; border-radius: 8px; background: var(--k-deep); color: var(--k-text-2); font-size: 11px; }
.language-list { display: grid; gap: 8px; margin-top: 26px; }
.language-option { display: flex; align-items: center; gap: 12px; padding: 11px; border: 1px solid var(--k-deep); border-radius: 10px; background: var(--k-surface-2); color: #fff; text-align: left; }
.language-mark { display: grid; place-items: center; width: 32px; height: 32px; border-radius: 4px; color: #111; font-weight: 900; }
.language-option span:last-child { display: grid; gap: 2px; }
.language-option small { color: var(--k-text-3); font-size: 10px; }
.language-list .k-btn { margin-top: 10px; }
</style>
