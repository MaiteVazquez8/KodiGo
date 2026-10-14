<template>
  <div class="k-screen">
    <main class="k-container registro">
      <EstadoPantalla v-if="!estado.lista" tipo="cargando" />

      <template v-else-if="tieneCuenta">
        <EstadoPantalla
          tipo="error"
          titulo="Ya tenés una cuenta"
          mensaje="Esta sesión ya está vinculada a una cuenta registrada. Revisá tu perfil."
        />
        <RouterLink to="/perfil" class="k-btn k-btn--primary k-btn--block k-btn--lg registro-boton">
          Ver mi perfil
        </RouterLink>
      </template>

      <template v-else>
        <form
          v-if="paso === 'formulario'"
          class="registro-pantalla"
          @submit.prevent="enviarRegistro"
        >
          <button type="button" class="registro-volver-enlace" @click="irAlAcceso">
            <q-icon name="arrow_back" size="18px" />
            Volver
          </button>

          <p class="registro-titulo k-h1">Crea tu perfil</p>
          <p class="registro-subtitulo">Únete a miles de programadores en racha.</p>

          <div class="registro-campos">
            <CampoFormulario
              v-model="formulario.nombre"
              etiqueta="Nombre completo"
              autocomplete="name"
              placeholder="Escribe tu nombre"
              :mensaje-ayuda="errorNombre"
              @enviar="enviarRegistro"
            />
            <CampoFormulario
              v-model="formulario.correo"
              etiqueta="Correo electrónico"
              tipo="email"
              inputmode="email"
              autocomplete="email"
              placeholder="tu@correo.com"
              :mensaje-ayuda="errorCorreo"
              @enviar="enviarRegistro"
            />
            <CampoFormulario
              v-model="formulario.contrasena"
              etiqueta="Contraseña"
              tipo="password"
              autocomplete="new-password"
              placeholder="Mínimo 8 caracteres"
              :mensaje-ayuda="errorContrasena"
              @enviar="enviarRegistro"
            />
          </div>

          <div class="card-promo">
            <q-icon name="workspace_premium" size="22px" />
            <p>Obtén 100 XP extras para tu primera racha de código hoy.</p>
          </div>

          <p v-if="errorGeneral" class="registro-error">{{ errorGeneral }}</p>

          <button
            type="submit"
            class="k-btn k-btn--primary k-btn--block k-btn--lg registro-boton"
            :disabled="enviando"
          >
            {{ enviando ? 'CREANDO CUENTA…' : 'CREAR CUENTA' }}
          </button>

          <p class="registro-alternativa">
            ¿Ya tienes cuenta?
            <RouterLink to="/acceso/ingreso">Inicia sesión</RouterLink>
          </p>
        </form>

        <!-- Paso 2: verificación de correo (exigido por Supabase, no aparece en el mock) -->
        <form
          v-else-if="paso === 'verificacion'"
          class="registro-pantalla registro-centrado"
          @submit.prevent="verificarConCodigo"
        >
          <FantasmaKodigo variant="happy" :size="88" />
          <p class="registro-titulo k-h1">Verificá tu correo</p>
          <p class="registro-subtitulo">
            Enviamos un enlace y un código de verificación a
            <strong class="k-mono">{{ correoEnUso }}</strong
            >. Abrí el enlace del correo o ingresá el código de 6 dígitos.
          </p>
          <p v-if="aliasReservado" class="registro-alias">
            Tu nombre de usuario en Kodigo será
            <strong class="k-mono">@{{ aliasReservado }}</strong
            >.
          </p>

          <CampoFormulario
            v-model="codigo"
            etiqueta="Código de verificación"
            inputmode="numeric"
            autocomplete="one-time-code"
            placeholder="000000"
            :mensaje-ayuda="errorGeneral"
          />

          <button
            type="submit"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            :disabled="enviando"
          >
            {{ enviando ? 'VERIFICANDO…' : 'VERIFICAR CÓDIGO' }}
          </button>

          <button
            type="button"
            class="k-btn k-btn--ghost k-btn--block"
            :disabled="enviando"
            @click="yaVerifique"
          >
            Ya abrí el enlace de verificación
          </button>

          <button
            type="button"
            class="registro-volver-enlace registro-centrar"
            :disabled="enviando"
            @click="volverAlFormulario"
          >
            Usar otro correo
          </button>
        </form>

        <!-- Registro creado; el proyecto pide confirmar el correo antes de iniciar sesión -->
        <section v-else-if="paso === 'confirmacion'" class="registro-pantalla registro-centrado">
          <FantasmaKodigo variant="happy" :size="88" />
          <p class="registro-titulo k-h1">Revisá tu correo</p>
          <p class="registro-subtitulo">
            Enviamos un enlace de confirmación a
            <strong class="k-mono">{{ correoEnUso }}</strong
            >. Abrilo para activar tu cuenta y después podés iniciar sesión.
          </p>
          <p v-if="aliasReservado" class="registro-alias">
            Tu nombre de usuario en Kodigo será
            <strong class="k-mono">@{{ aliasReservado }}</strong
            >.
          </p>

          <RouterLink to="/acceso/ingreso" class="k-btn k-btn--primary k-btn--block k-btn--lg">
            YA CONFIRMÉ MI CORREO
          </RouterLink>
        </section>

        <!-- Paso 3: contraseña (Supabase exige verificar el correo antes de fijarla) -->
        <form
          v-else-if="paso === 'contrasena'"
          class="registro-pantalla registro-centrado"
          @submit.prevent="guardarContrasena"
        >
          <FantasmaKodigo variant="happy" :size="88" />
          <p class="registro-titulo k-h1">Tu contraseña</p>
          <p class="registro-subtitulo">Correo verificado. Definí la contraseña de tu cuenta.</p>

          <CampoFormulario
            v-model="contrasena"
            etiqueta="Contraseña"
            tipo="password"
            autocomplete="new-password"
            placeholder="Mínimo 8 caracteres, con letras y números"
            :mensaje-ayuda="errorContrasena"
            @enviar="guardarContrasena"
          />
          <CampoFormulario
            v-model="confirmacion"
            etiqueta="Repetí la contraseña"
            tipo="password"
            autocomplete="new-password"
            placeholder="La misma contraseña"
            :mensaje-ayuda="errorConfirmacion"
            @enviar="guardarContrasena"
          />

          <p v-if="errorGeneral" class="registro-error">{{ errorGeneral }}</p>

          <button
            type="submit"
            class="k-btn k-btn--primary k-btn--block k-btn--lg"
            :disabled="enviando"
          >
            {{ enviando ? 'GUARDANDO…' : 'GUARDAR CONTRASEÑA' }}
          </button>
        </form>

        <!-- Paso 4: listo -->
        <section v-else class="registro-pantalla registro-centrado">
          <FantasmaKodigo variant="happy" :size="104" />
          <p class="registro-eyebrow k-eyebrow">Cuenta creada</p>
          <p class="registro-titulo k-h1">¡Listo, {{ nombreCorto }}!</p>
          <p class="registro-subtitulo">
            Tu cuenta quedó creada con el correo
            <strong class="k-mono">{{ correoEnUso || estado.usuario?.email }}</strong
            >. Ya podés iniciar sesión desde cualquier dispositivo.
          </p>
          <RouterLink to="/perfil" class="k-btn k-btn--primary k-btn--block k-btn--lg">
            IR A MI PERFIL
          </RouterLink>
        </section>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import CampoFormulario from '@/components/CampoFormulario.vue'
import EstadoPantalla from '@/components/EstadoPantalla.vue'
import FantasmaKodigo from '@/components/FantasmaKodigo.vue'
import {
  correoVerificado,
  crearCuenta,
  esInvitado,
  establecerContrasena,
  usarAuth,
  validarContrasena,
  validarCorreo,
  verificarCorreoCuenta,
} from '@/services/auth'

const router = useRouter()
const { estado } = usarAuth()
// Sin sesión no es "cuenta registrada": el registro con signUp está disponible.
// Antes esta condición daba por hecho que sin invitado había cuenta y bloqueaba
// el registro a cualquier visitante sin sesión.
const tieneCuenta = computed(() => Boolean(estado.usuario) && !esInvitado(estado.usuario))

const paso = ref('formulario')
const enviando = ref(false)
const formulario = ref({ nombre: '', correo: '', contrasena: '' })
const correoEnUso = ref('')
const aliasReservado = ref('')
const codigo = ref('')
const contrasena = ref('')
const confirmacion = ref('')

const errorNombre = ref('')
const errorCorreo = ref('')
const errorContrasena = ref('')
const errorConfirmacion = ref('')
const errorGeneral = ref('')

const nombreCorto = computed(() => {
  const visible = estado.perfil?.nombre_visible || formulario.value.nombre || ''
  return visible.trim() ? visible.trim().split(' ')[0] : 'coder'
})

async function enviarRegistro() {
  errorNombre.value = ''
  errorCorreo.value = ''
  errorContrasena.value = ''
  errorGeneral.value = ''

  if (String(formulario.value.nombre).trim().length < 2) {
    errorNombre.value = 'Ingresá tu nombre completo.'
  }
  const revisionCorreo = validarCorreo(formulario.value.correo)
  if (!revisionCorreo.valido) {
    errorCorreo.value = revisionCorreo.mensaje
  }
  const revisionContrasena = validarContrasena(formulario.value.contrasena)
  if (!revisionContrasena.valido) {
    errorContrasena.value = revisionContrasena.mensaje
  }
  if (errorNombre.value || errorCorreo.value || errorContrasena.value) return

  enviando.value = true
  try {
    const resultado = await crearCuenta({
      nombre: formulario.value.nombre,
      correo: formulario.value.correo,
      contrasena: formulario.value.contrasena,
    })
    correoEnUso.value = resultado.correo || formulario.value.correo.trim()
    aliasReservado.value = resultado.alias || ''

    if (resultado.via === 'registro') {
      paso.value = resultado.requiereConfirmacionCorreo ? 'confirmacion' : 'listo'
      return
    }
    paso.value = resultado.requiereVerificacion ? 'verificacion' : 'contrasena'
  } catch (error) {
    errorGeneral.value = error.message
  } finally {
    enviando.value = false
  }
}

async function verificarConCodigo() {
  errorGeneral.value = ''
  if (!String(codigo.value).trim()) {
    errorGeneral.value = 'Ingresá el código de 6 dígitos que recibiste por correo.'
    return
  }
  enviando.value = true
  try {
    await verificarCorreoCuenta({ correo: correoEnUso.value, codigo: codigo.value })
    paso.value = 'contrasena'
  } catch (error) {
    errorGeneral.value = error.message
  } finally {
    enviando.value = false
  }
}

async function yaVerifique() {
  errorGeneral.value = ''
  enviando.value = true
  try {
    if (await correoVerificado()) {
      paso.value = 'contrasena'
    } else {
      errorGeneral.value =
        'Todavía no vemos tu correo verificado. Abrí el enlace que te enviamos y volvé a intentar.'
    }
  } finally {
    enviando.value = false
  }
}

function volverAlFormulario() {
  errorGeneral.value = ''
  correoEnUso.value = ''
  aliasReservado.value = ''
  codigo.value = ''
  paso.value = 'formulario'
}

async function guardarContrasena() {
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
    paso.value = 'listo'
  } catch (error) {
    errorGeneral.value = error.message
  } finally {
    enviando.value = false
  }
}

function irAlAcceso() {
  router.push('/acceso')
}
</script>

<style scoped>
.registro {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.registro-pantalla {
  display: flex;
  flex-direction: column;
}

.registro-centrado {
  align-items: center;
  text-align: center;
}

.registro-volver-enlace {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  align-self: flex-start;
  padding: 6px 0;
  border: 0;
  background: transparent;
  color: var(--k-text-2);
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.registro-centrar {
  align-self: center;
  margin-top: var(--k-space-4);
}

.registro-titulo {
  margin-top: var(--k-space-5);
}

.registro-subtitulo {
  margin-top: var(--k-space-2);
  max-width: 320px;
  font-size: 14.5px;
  line-height: 1.5;
  color: var(--k-text-2);
}

.registro-campos {
  display: grid;
  gap: var(--k-space-4);
  margin-top: var(--k-space-6);
}

.registro-centrado .campo-formulario,
.registro-centrado > * {
  width: 100%;
  max-width: 340px;
}

.card-promo {
  display: flex;
  align-items: center;
  gap: var(--k-space-3);
  margin-top: var(--k-space-5);
  padding: var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid rgba(142, 5, 194, 0.35);
  background: var(--k-accent-softer);
}

.card-promo .q-icon {
  color: var(--k-accent);
  flex-shrink: 0;
}

.card-promo p {
  font-size: 13.5px;
  line-height: 1.45;
  color: var(--k-text-2);
}

.registro-alias {
  margin-top: var(--k-space-2);
  font-size: 13px;
  color: var(--k-text-2);
}

.registro-error {
  margin-top: var(--k-space-4);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.45;
  color: var(--k-error);
}

.registro-boton {
  margin-top: var(--k-space-6);
}

.registro-centrado .k-btn {
  margin-top: var(--k-space-5);
}

.registro-alternativa {
  margin-top: var(--k-space-4);
  text-align: center;
  font-size: 14px;
  color: var(--k-text-2);
}

.registro-alternativa a {
  color: var(--k-accent);
  font-weight: 800;
  text-decoration: none;
}

.registro-eyebrow {
  margin-top: var(--k-space-4);
}

.k-mono {
  color: var(--k-text);
}
</style>
