<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Recuperar contraseña" back />

    <main class="k-container recuperar">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else-if="enviado">
        <section class="recuperar-exito">
          <FantasmaKodigo variant="happy" :size="92" class="recuperar-ghost" />
          <p class="k-eyebrow recuperar-eyebrow">Revisá tu correo</p>
          <h1 class="k-h1 recuperar-titulo">Listo</h1>
          <p class="recuperar-detalle">
            Si existe una cuenta con
            <strong class="k-mono">{{ correo }}</strong
            >, te enviamos un enlace para restablecer tu contraseña.
          </p>
          <RouterLink to="/acceso/ingreso" class="k-btn k-btn--ghost k-btn--block recuperar-volver">
            Volver a iniciar sesión
          </RouterLink>
        </section>
      </template>

      <form v-else class="recuperar-forma" @submit.prevent="enviarEnlace">
        <FantasmaKodigo variant="normal" :size="72" class="recuperar-ghost" />
        <p class="recuperar-intro">
          Ingresá el correo de tu cuenta y te enviaremos un enlace para restablecer la contraseña.
        </p>

        <CampoFormulario
          v-model="correo"
          etiqueta="Correo electrónico"
          tipo="email"
          inputmode="email"
          autocomplete="email"
          placeholder="nombre@correo.com"
          :mensaje-ayuda="errorCorreo"
          @enviar="enviarEnlace"
        />

        <p v-if="errorGeneral" class="recuperar-error">{{ errorGeneral }}</p>

        <button
          type="submit"
          class="k-btn k-btn--primary k-btn--block k-btn--lg"
          :disabled="enviando"
        >
          <q-icon name="mail" size="19px" />
          {{ enviando ? 'Enviando…' : 'Enviar enlace' }}
        </button>
      </form>
    </main>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import CampoFormulario from '@/components/CampoFormulario.vue'
import { recuperarContrasena, usarAuth, validarCorreo } from '@/services/auth'

const { estado } = usarAuth()

const correo = ref('')
const enviando = ref(false)
const enviado = ref(false)
const errorCorreo = ref('')
const errorGeneral = ref('')

async function enviarEnlace() {
  errorCorreo.value = ''
  errorGeneral.value = ''

  const revision = validarCorreo(correo.value)
  if (!revision.valido) {
    errorCorreo.value = revision.mensaje
    return
  }

  enviando.value = true
  try {
    await recuperarContrasena({ correo: correo.value })
    enviado.value = true
  } catch (error) {
    errorGeneral.value = error.message
  } finally {
    enviando.value = false
  }
}
</script>

<style scoped>
.recuperar-forma,
.recuperar-exito {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.recuperar-ghost {
  opacity: 0.9;
}

.recuperar-intro,
.recuperar-detalle {
  margin-top: var(--k-space-3);
  max-width: 320px;
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.recuperar-forma .campo-formulario {
  width: 100%;
  margin-top: var(--k-space-6);
}

.recuperar-error {
  margin-top: var(--k-space-4);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.45;
  color: var(--k-error);
}

.recuperar-forma .k-btn--primary {
  margin-top: var(--k-space-5);
}

.recuperar-eyebrow {
  margin-top: var(--k-space-4);
}

.recuperar-titulo {
  margin-top: var(--k-space-2);
}

.recuperar-volver {
  margin-top: var(--k-space-6);
  text-decoration: none;
}

.k-mono {
  color: var(--k-text);
}
</style>
