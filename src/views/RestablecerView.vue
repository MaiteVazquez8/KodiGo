<template>
  <div class="k-screen">
    <EncabezadoApp titulo="Restablecer contraseña" back />

    <main class="k-container restablecer">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else-if="!estado.usuario">
        <section class="restablecer-estado">
          <FantasmaKodigo variant="sad" :size="88" class="restablecer-ghost" />
          <h1 class="k-h1 restablecer-titulo">Enlace no válido</h1>
          <p class="restablecer-detalle">
            No encontramos una sesión asociada a este enlace. Podés pedir un enlace nuevo desde la
            pantalla de recuperación.
          </p>
          <RouterLink
            to="/acceso/recuperar"
            class="k-btn k-btn--primary k-btn--block k-btn--lg restablecer-accion"
          >
            Pedir enlace nuevo
          </RouterLink>
        </section>
      </template>

      <form v-else-if="!listo" class="restablecer-forma" @submit.prevent="guardar">
        <FantasmaKodigo variant="normal" :size="72" class="restablecer-ghost" />
        <h1 class="k-h1 restablecer-titulo">Nueva contraseña</h1>
        <p class="restablecer-detalle">Definí una nueva contraseña para tu cuenta.</p>

        <div class="restablecer-campos">
          <CampoFormulario
            v-model="contrasena"
            etiqueta="Nueva contraseña"
            tipo="password"
            autocomplete="new-password"
            placeholder="Al menos 8 caracteres, con letras y números"
            :mensaje-ayuda="errorContrasena"
            @enviar="guardar"
          />
          <CampoFormulario
            v-model="confirmacion"
            etiqueta="Repetí la contraseña"
            tipo="password"
            autocomplete="new-password"
            placeholder="La misma contraseña"
            :mensaje-ayuda="errorConfirmacion"
            @enviar="guardar"
          />
        </div>

        <p v-if="errorGeneral" class="restablecer-error">{{ errorGeneral }}</p>

        <button
          type="submit"
          class="k-btn k-btn--primary k-btn--block k-btn--lg"
          :disabled="enviando"
        >
          <q-icon name="check_circle" size="19px" />
          {{ enviando ? 'Guardando…' : 'Guardar contraseña' }}
        </button>
      </form>

      <section v-else class="restablecer-estado">
        <FantasmaKodigo variant="happy" :size="92" class="restablecer-ghost" />
        <p class="k-eyebrow restablecer-eyebrow">Contraseña actualizada</p>
        <h1 class="k-h1 restablecer-titulo">¡Listo!</h1>
        <p class="restablecer-detalle">
          Tu contraseña se guardó correctamente. Ya podés usarla para iniciar sesión.
        </p>
        <RouterLink
          to="/perfil"
          class="k-btn k-btn--primary k-btn--block k-btn--lg restablecer-accion"
        >
          Ir a mi perfil
        </RouterLink>
      </section>
    </main>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import EncabezadoApp from '@/components/EncabezadoApp.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import CampoFormulario from '@/components/CampoFormulario.vue'
import { establecerContrasena, usarAuth, validarContrasena } from '@/services/auth'

const { estado } = usarAuth()

const contrasena = ref('')
const confirmacion = ref('')
const enviando = ref(false)
const listo = ref(false)
const errorContrasena = ref('')
const errorConfirmacion = ref('')
const errorGeneral = ref('')

async function guardar() {
  errorContrasena.value = ''
  errorConfirmacion.value = ''
  errorGeneral.value = ''

  const revision = validarContrasena(contrasena.value)
  if (!revision.valido) {
    errorContrasena.value = revision.mensaje
    return
  }
  if (confirmacion.value !== contrasena.value) {
    errorConfirmacion.value = 'Las contraseñas no coinciden.'
    return
  }

  enviando.value = true
  try {
    await establecerContrasena({ contrasena: contrasena.value })
    listo.value = true
  } catch (error) {
    errorGeneral.value = error.message
  } finally {
    enviando.value = false
  }
}
</script>

<style scoped>
.restablecer-forma,
.restablecer-estado {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.restablecer-ghost {
  opacity: 0.9;
}

.restablecer-titulo {
  margin-top: var(--k-space-3);
}

.restablecer-eyebrow {
  margin-top: var(--k-space-4);
}

.restablecer-detalle {
  margin-top: var(--k-space-3);
  max-width: 320px;
  font-size: 13.5px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.restablecer-campos {
  display: grid;
  gap: var(--k-space-4);
  width: 100%;
  margin-top: var(--k-space-6);
}

.restablecer-error {
  margin-top: var(--k-space-4);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.45;
  color: var(--k-error);
}

.restablecer-forma .k-btn--primary {
  margin-top: var(--k-space-5);
}

.restablecer-accion {
  margin-top: var(--k-space-6);
  text-decoration: none;
  max-width: 280px;
}
</style>
