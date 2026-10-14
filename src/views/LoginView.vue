<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Iniciar sesión" back />

    <main class="k-container ingreso">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else>
        <section class="ingreso-marca">
          <p class="ingreso-logo k-font-brand">KODI<span>GO</span></p>
        </section>

        <BurbujaFantasma
          mensaje="¡Hola de nuevo! Inicia sesión para continuar."
          :tamano-fantasma="64"
          estado="happy"
          class="ingreso-burbuja"
        />

        <section v-if="esInvitadoActual" class="card-invitado">
          <q-icon name="travel_explore" size="18px" />
          <p>
            Estás navegando como invitado. Si iniciás sesión con otra cuenta, tu actividad de
            invitado no se traslada a esa cuenta.
          </p>
        </section>

        <form class="ingreso-forma" @submit.prevent="ingresar">
          <CampoFormulario
            v-model="formulario.correo"
            etiqueta="Correo electrónico"
            tipo="email"
            inputmode="email"
            autocomplete="email"
            placeholder="nombre@correo.com"
            :mensaje-ayuda="errorCorreo"
          />

          <CampoFormulario
            v-model="formulario.contrasena"
            etiqueta="Contraseña"
            tipo="password"
            autocomplete="current-password"
            placeholder="Tu contraseña"
            :mensaje-ayuda="errorContrasena"
            @enviar="ingresar"
          />

          <p v-if="errorGeneral" class="ingreso-error">{{ errorGeneral }}</p>

          <button
            type="submit"
            class="k-btn k-btn--primary k-btn--block k-btn--lg ingreso-boton"
            :disabled="enviando"
          >
            {{ enviando ? 'INICIANDO SESIÓN…' : 'INICIAR SESIÓN' }}
          </button>

          <RouterLink to="/acceso/recuperar" class="ingreso-link"
            >¿Olvidaste tu contraseña?</RouterLink
          >

          <p class="ingreso-alternativa">
            ¿No tienes cuenta?
            <RouterLink to="/acceso/registro">Regístrate</RouterLink>
          </p>
        </form>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import BurbujaFantasma from '@/components/BurbujaFantasma.vue'
import CampoFormulario from '@/components/CampoFormulario.vue'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { esInvitado, iniciarSesion, usarAuth, validarCorreo } from '@/services/auth'

const router = useRouter()
const { estado } = usarAuth()
const esInvitadoActual = computed(() => esInvitado(estado.usuario))

const formulario = ref({ correo: '', contrasena: '' })
const enviando = ref(false)
const errorCorreo = ref('')
const errorContrasena = ref('')
const errorGeneral = ref('')

async function ingresar() {
  errorCorreo.value = ''
  errorContrasena.value = ''
  errorGeneral.value = ''

  const revision = validarCorreo(formulario.value.correo)
  if (!revision.valido) {
    errorCorreo.value = revision.mensaje
    return
  }
  if (!formulario.value.contrasena) {
    errorContrasena.value = 'Ingresá tu contraseña.'
    return
  }

  enviando.value = true
  try {
    await iniciarSesion({
      correo: formulario.value.correo,
      contrasena: formulario.value.contrasena,
    })
    router.replace('/perfil')
  } catch (error) {
    errorGeneral.value = error.message
  } finally {
    enviando.value = false
  }
}
</script>

<style scoped>
.ingreso {
  display: flex;
  flex-direction: column;
}

.ingreso-marca {
  text-align: center;
}

.ingreso-logo {
  font-size: 28px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.ingreso-logo span {
  color: var(--k-accent);
}

.ingreso-burbuja {
  margin-top: var(--k-space-5);
}

.card-invitado {
  display: flex;
  align-items: flex-start;
  gap: var(--k-space-2);
  margin-top: var(--k-space-5);
  padding: 12px 14px;
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(142, 5, 194, 0.35);
  background: var(--k-accent-softer);
  font-size: 12.5px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.card-invitado .q-icon {
  color: var(--k-accent);
  flex-shrink: 0;
  margin-top: 2px;
}

.ingreso-forma {
  display: flex;
  flex-direction: column;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
}

.ingreso-error {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.45;
  color: var(--k-error);
}

.ingreso-boton {
  margin-top: var(--k-space-2);
}

.ingreso-link {
  align-self: center;
  font-size: 13px;
  font-weight: 700;
  color: var(--k-text-2);
  text-decoration: none;
}

.ingreso-alternativa {
  text-align: center;
  font-size: 14px;
  color: var(--k-text-2);
}

.ingreso-alternativa a {
  color: var(--k-accent);
  font-weight: 800;
  text-decoration: none;
}
</style>
