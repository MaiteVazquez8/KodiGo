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

        <section v-if="invitadoActual" class="card-invitado">
          <q-icon name="travel_explore" size="18px" />
          <div>
            <p class="card-invitado-titulo">Tu sesión de invitado está activa</p>
            <p class="card-invitado-texto">
              Podés practicar sin crear una cuenta y tu progreso se guarda en este dispositivo.
              Si te registrás con tu correo, esta misma sesión se convierte en tu cuenta y conserva
              todo tu avance.
            </p>
          </div>
        </section>

        <ExpotecnicaTutorialModal :abierto="mostrarTutorialExpotecnica" @cerrar="cerrarTutorialYParticipar" />
        <p v-if="errorInvitado || errorDesafio" class="acceso-error" role="alert">
          {{ errorInvitado || errorDesafio }}
        </p>

        <div class="acceso-acciones">
          <button
            type="button"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            @click="irAIngreso"
          >
            {{ cuentaActiva ? 'VER MI PERFIL' : 'INICIAR SESIÓN' }}
          </button>

          <button
            type="button"
            class="k-btn k-btn--ghost k-btn--block k-btn--lg"
            :disabled="entrandoInvitado"
            @click="iniciarSesionInvitado"
          >
            <q-spinner v-if="entrandoInvitado" size="17px" class="on-left" color="currentColor" />
            <q-icon v-else name="smartphone" size="19px" class="on-left" />
            {{ entrandoInvitado ? 'Creando tu sesión…' : invitadoActual ? 'CONTINUAR COMO INVITADO' : 'ENTRAR COMO INVITADO' }}
          </button>

          <button
            type="button"
            class="acceso-desafio"
            :disabled="entrandoDesafio"
            @click="irAlDesafio"
          >
            <span class="acceso-desafio-icono">
              <q-spinner v-if="entrandoDesafio" size="22px" color="currentColor" />
              <img v-else src="/logoTec.png" alt="ExpoTécnica" width="24" height="24" />
            </span>
            <span class="acceso-desafio-texto">
              <span class="acceso-desafio-titulo">Desafío ExpoTécnica</span>
              <span class="acceso-desafio-sub">
                {{ entrandoDesafio ? 'Creando tu sesión de invitado…' : 'Competinos 10 preguntas de JavaScript y Core Defender' }}
              </span>
            </span>
            <q-icon name="chevron_right" size="20px" class="acceso-desafio-chev" />
          </button>

          <p class="acceso-alternativa">
            ¿No tienes cuenta?
            <RouterLink to="/acceso/registro">Regístrate</RouterLink>
          </p>
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
import { asegurarSesion, entrarComoInvitado, esInvitado, usarAuth } from '@/services/auth'
import ExpotecnicaTutorialModal from '@/components/ExpotecnicaTutorialModal.vue'

const router = useRouter()
const { estado } = usarAuth()

const entrandoInvitado = ref(false)
const entrandoDesafio = ref(false)
const errorInvitado = ref('')
const errorDesafio = ref('')
const mostrarTutorialExpotecnica = ref(false)

const invitadoActual = computed(() => esInvitado(estado.usuario))
const cuentaActiva = computed(() => Boolean(estado.usuario) && !esInvitado(estado.usuario))

function irAIngreso() {
  router.push(cuentaActiva.value ? '/perfil' : '/acceso/ingreso')
}

async function irAlDesafio() {
  // Del inicio se entra directo al desafío: si no hay sesión (real o invitado)
  // se crea/recupera una anónima; la persona participa igual, como invitado.
  if (entrandoDesafio.value) return
  errorDesafio.value = ''
  errorInvitado.value = ''

  let yaVisto = false
  try { yaVisto = sessionStorage.getItem('kodigo.expotec-tutorial-visto') === '1' } catch { yaVisto = false }
  if (!yaVisto) {
    mostrarTutorialExpotecnica.value = true
    return
  }
  await entrarDesafio()
}

async function entrarDesafio() {
  entrandoDesafio.value = true
  try {
    await asegurarSesion()
    router.push('/expotecnica/desafio')
  } catch (error) {
    errorDesafio.value =
      (error.message || 'No pudimos iniciar tu sesión para el desafío.') + ' Probá de nuevo.'
  } finally {
    entrandoDesafio.value = false
  }
}

function cerrarTutorialYParticipar() {
  try { sessionStorage.setItem('kodigo.expotec-tutorial-visto', '1') } catch { /* sin almacenamiento */ }
  mostrarTutorialExpotecnica.value = false
  void entrarDesafio()
}

async function iniciarSesionInvitado() {
  // Si ya hay una sesión anónima válida, se reutiliza: no se crea otra.
  if (invitadoActual.value) {
    router.push('/learn')
    return
  }
  errorInvitado.value = ''
  entrandoInvitado.value = true
  try {
    await entrarComoInvitado()
    router.push('/learn')
  } catch (error) {
    errorInvitado.value =
      (error.message || 'No pudimos crear tu sesión de invitado.') + ' Probá de nuevo.'
  } finally {
    entrandoInvitado.value = false
  }
}
</script>

<style scoped>
.card-info,
.card-invitado,
.acceso-desafio,
.acceso-acciones > * {
  max-width: 100%;
  min-width: 0;
}

.acceso {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-8);
  min-width: 0;
}

.acceso-mensaje > div {
  min-width: 0;
}

.acceso-mensaje-texto,
.card-invitado-texto,
.card-info-texto {
  overflow-wrap: anywhere;
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
  gap: 10px;
  margin-top: auto;
  padding-top: var(--k-space-8);
}

.acceso-alternativa {
  margin-top: var(--k-space-2);
  text-align: center;
  font-size: 14px;
  color: var(--k-text-2);
}

.acceso-alternativa a {
  color: var(--k-accent);
  font-weight: 800;
  text-decoration: none;
}

/* Botón del desafío ExpoTécnica: opción especial destacada sin robar la jerarquía al login. */
.acceso-desafio {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  width: 100%;
  margin-top: 2px;
  padding: 12px 14px;
  border-radius: var(--k-radius);
  border: 1px solid rgba(142, 5, 194, 0.45);
  background: linear-gradient(160deg, #2a0b38 0%, #170722 100%);
  color: var(--k-text);
  font-family: inherit;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.15s ease, transform 0.08s ease, box-shadow 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}

.acceso-desafio:hover {
  border-color: var(--k-accent);
  box-shadow: 0 0 22px rgba(142, 5, 194, 0.28);
}

.acceso-desafio:disabled {
  opacity: 0.75;
  cursor: progress;
}

.acceso-desafio:active {
  transform: scale(0.985);
}

.acceso-desafio-icono {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: rgba(142, 5, 194, 0.18);
  border: 1px solid rgba(142, 5, 194, 0.4);
  color: var(--k-accent);
  flex-shrink: 0;
}

.acceso-desafio-texto {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.acceso-desafio-titulo {
  font-size: 15px;
  font-weight: 800;
  letter-spacing: 0.01em;
}

.acceso-desafio-sub {
  font-size: 12px;
  line-height: 1.4;
  color: var(--k-text-2);
}

.acceso-desafio-chev {
  margin-left: auto;
  color: var(--k-text-2);
  flex-shrink: 0;
}
</style>
