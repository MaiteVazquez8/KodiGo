<template>
  <div class="k-screen">
    <main class="k-container configuracion">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else>
        <button type="button" class="configuracion-volver" @click="volver">
          <q-icon name="arrow_back" size="18px" />
        </button>

        <p class="configuracion-titulo k-h1">Configuración</p>
        <p class="configuracion-subtitulo">Personaliza tu cuenta y aprendizaje</p>

        <section class="configuracion-grupo">
          <p class="configuracion-grupo-titulo">CUENTA Y APRENDIZAJE</p>

          <RouterLink to="/perfil" class="configuracion-item">
            <q-icon name="person" size="20px" />
            <span>Detalles de Cuenta</span>
            <q-icon name="chevron_right" size="20px" class="configuracion-item-flecha" />
          </RouterLink>

          <RouterLink v-if="!esInvitadoActual" to="/acceso/restablecer" class="configuracion-item">
            <q-icon name="lock_reset" size="20px" />
            <span>Cambiar contraseña</span>
            <q-icon name="chevron_right" size="20px" class="configuracion-item-flecha" />
          </RouterLink>

          <RouterLink v-else to="/acceso/registro" class="configuracion-item">
            <q-icon name="person_add" size="20px" />
            <span>Crear mi cuenta</span>
            <q-icon name="chevron_right" size="20px" class="configuracion-item-flecha" />
          </RouterLink>
        </section>

        <section class="configuracion-grupo">
          <p class="configuracion-grupo-titulo">SOPORTE Y PRIVACIDAD</p>
          <RouterLink to="/acceso/recuperar" class="configuracion-item">
            <q-icon name="help_outline" size="20px" />
            <span>Centro de Ayuda</span>
            <q-icon name="chevron_right" size="20px" class="configuracion-item-flecha" />
          </RouterLink>
        </section>

        <p v-if="errorSesion" class="configuracion-error">{{ errorSesion }}</p>

        <button type="button" class="configuracion-cerrar" :disabled="saliendo" @click="salir">
          {{ saliendo ? 'CERRANDO SESIÓN…' : 'CERRAR SESIÓN' }}
        </button>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import { cerrarSesion, esInvitado, usarAuth } from '@/services/auth'

const router = useRouter()
const { estado } = usarAuth()

const esInvitadoActual = computed(() => esInvitado(estado.usuario))
const saliendo = ref(false)
const errorSesion = ref('')

function volver() {
  router.back()
}

async function salir() {
  saliendo.value = true
  errorSesion.value = ''
  try {
    await cerrarSesion()
    router.push('/acceso')
  } catch (error) {
    errorSesion.value = error.message
  } finally {
    saliendo.value = false
  }
}
</script>

<style scoped>
.configuracion {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.configuracion-volver {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 12px;
  border: 1px solid var(--k-line);
  background: rgba(24, 9, 31, 0.9);
  color: var(--k-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.configuracion-titulo {
  margin-top: var(--k-space-4);
}

.configuracion-subtitulo {
  margin-top: var(--k-space-2);
  font-size: 15px;
  color: var(--k-text-2);
}

.configuracion-grupo {
  margin-top: var(--k-space-6);
}

.configuracion-grupo-titulo {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: var(--k-accent);
}

.configuracion-item {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-3);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
  color: var(--k-text);
  font-size: 15px;
  font-weight: 600;
  text-decoration: none;
}

.configuracion-item .q-icon {
  color: var(--k-text-2);
  flex-shrink: 0;
}

.configuracion-item-flecha {
  margin-left: auto;
  color: var(--k-text-3) !important;
}

.configuracion-error {
  margin-top: var(--k-space-4);
  font-size: 13px;
  font-weight: 700;
  color: var(--k-error);
}

.configuracion-cerrar {
  margin-top: var(--k-space-8);
  padding: 16px;
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-error);
  background: transparent;
  color: var(--k-error);
  font-size: 14px;
  font-weight: 800;
  letter-spacing: 0.02em;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.configuracion-cerrar:disabled {
  opacity: 0.5;
}
</style>
