<template>
  <div class="k-screen">
    <main class="k-container acceso">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else>
        <header class="acceso-marca">
          <p class="acceso-logo k-font-brand">KODI<span>GO</span></p>
          <p class="acceso-lema">Gamifica tu aprendizaje de código</p>
        </header>

        <section class="card-info">
          <p class="card-info-titulo">¿Qué es KodiGo?</p>
          <p class="card-info-texto">
            KodiGo es una plataforma que te permite aprender a programar de forma fácil y sencilla.
          </p>
        </section>

        <section class="acceso-mensaje">
          <FantasmaKodigo variant="happy" :size="88" class="acceso-fantasma" />
          <div>
            <p class="acceso-mensaje-titulo">Nunca había sido tan fácil aprender a programar</p>
            <p class="acceso-mensaje-texto">
              Con KodiGo podes tener calificaciones al instante, repasar tus lecciones, tener un
              seguimiento actualizado de tu aprendizaje y mostrarlo con tus amigos
            </p>
          </div>
        </section>

        <section v-if="esInvitadoActual" class="card-invitado">
          <q-icon name="travel_explore" size="18px" />
          <div>
            <p class="card-invitado-titulo">Estás entrando como invitado</p>
            <p class="card-invitado-texto">
              Podés practicar sin crear una cuenta. Si te registrás, esta misma sesión se convierte
              en tu cuenta y conserva tu progreso.
            </p>
          </div>
        </section>

        <p v-if="errorInvitado" class="acceso-error">{{ errorInvitado }}</p>

        <div class="acceso-acciones">
          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            @click="irAIngreso"
          >
            {{ cuentaActiva ? 'VER MI PERFIL' : 'INICIAR SESIÓN' }}
          </button>

          <p class="acceso-alternativa">
            ¿No tienes cuenta?
            <RouterLink to="/acceso/registro">Regístrate</RouterLink>
          </p>

          <button
            v-if="!esInvitadoActual"
            type="button"
            class="acceso-invitado"
            :disabled="entrandoInvitado"
            @click="iniciarSesionInvitado"
          >
            {{ entrandoInvitado ? 'Entrando como invitado…' : 'Entrar como invitado' }}
          </button>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import { entrarComoInvitado, esInvitado, usarAuth } from '@/services/auth'

const router = useRouter()
const { estado } = usarAuth()

const entrandoInvitado = ref(false)
const errorInvitado = ref('')

const esInvitadoActual = computed(() => esInvitado(estado.usuario))
const cuentaActiva = computed(() => Boolean(estado.usuario) && !esInvitado(estado.usuario))

function irAIngreso() {
  router.push(cuentaActiva.value ? '/perfil' : '/acceso/ingreso')
}

async function iniciarSesionInvitado() {
  errorInvitado.value = ''
  entrandoInvitado.value = true
  try {
    await entrarComoInvitado()
    router.push('/perfil')
  } catch (error) {
    errorInvitado.value = error.message
  } finally {
    entrandoInvitado.value = false
  }
}
</script>

<style scoped>
.acceso {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-8);
}

.acceso-marca {
  text-align: center;
}

.acceso-logo {
  font-size: 38px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1;
}

.acceso-logo span {
  color: var(--k-accent);
}

.acceso-lema {
  margin-top: var(--k-space-2);
  font-size: 15px;
  font-weight: 600;
  color: var(--k-text-2);
}

.card-info {
  margin-top: var(--k-space-6);
  padding: var(--k-space-5);
  border-radius: var(--k-radius);
  border: 1px solid rgba(142, 5, 194, 0.45);
  background: rgba(24, 9, 31, 0.9);
}

.card-info-titulo {
  font-size: 16px;
  font-weight: 800;
}

.card-info-texto {
  margin-top: var(--k-space-2);
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.acceso-mensaje {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-4);
  margin-top: var(--k-space-7);
}

.acceso-fantasma {
  flex-shrink: 0;
}

.acceso-mensaje-titulo {
  font-size: 21px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.acceso-mensaje-texto {
  margin-top: var(--k-space-3);
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.card-invitado {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-3);
  margin-top: var(--k-space-6);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(142, 5, 194, 0.35);
  background: var(--k-accent-softer);
}

.card-invitado .q-icon {
  color: var(--k-accent);
  flex-shrink: 0;
  margin-top: 2px;
}

.card-invitado-titulo {
  font-size: 13.5px;
  font-weight: 800;
}

.card-invitado-texto {
  margin-top: 2px;
  font-size: 12.5px;
  line-height: 1.5;
  color: var(--k-text-2);
}

/* Entrada como invitado: link de texto, no compite con el botón primario.
   El mock no la muestra; se ubica debajo del link "Regístrate" para no alterar
   la jerarquía visual de la pantalla. */
.acceso-invitado {
  align-self: center;
  margin-top: var(--k-space-3);
  padding: 6px 0;
  border: 0;
  background: transparent;
  color: var(--k-text-3);
  font-family: inherit;
  font-size: 13px;
  font-weight: 700;
  text-decoration: underline;
  text-underline-offset: 3px;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.acceso-invitado:hover:not(:disabled) {
  color: var(--k-text-2);
}

.acceso-invitado:disabled {
  opacity: 0.6;
  cursor: default;
}

.acceso-error {
  margin-top: var(--k-space-4);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.45;
  color: var(--k-error);
}

.acceso-acciones {
  display: flex;
  flex-direction: column;
  margin-top: auto;
  padding-top: var(--k-space-8);
}

.acceso-alternativa {
  margin-top: var(--k-space-4);
  text-align: center;
  font-size: 14px;
  color: var(--k-text-2);
}

.acceso-alternativa a {
  color: var(--k-accent);
  font-weight: 800;
  text-decoration: none;
}
</style>
