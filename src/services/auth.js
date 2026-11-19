import { computed, reactive } from 'vue'
import { supabase } from '@/supabase'
import { cargarProgreso } from '@/services/catalogo'
import { esAdmin as esAdminExpotecRpc } from '@/services/expotecnica-admin'

const URL_RESTABLECER = import.meta.env.VITE_SUPABASE_REDIRECT_URL

const ALIASES_RESERVADOS = ['admin', 'administrador', 'sistema', 'kodigo', 'perfil', 'mod']

export const estado = reactive({
  lista: false,
  usuario: null,
  perfil: null,
  esAdminExpotec: false,
})

let promesaInicial = null
let suscripcionRegistrada = false

export function normalizarAlias(alias) {
  return String(alias ?? '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '')
}

export function generarAliasDesdeNombre(nombre) {
  const base = normalizarAlias(nombre)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/^[.]+|[.]+$/g, '')
    .replace(/\.{2,}/g, '.')
    .slice(0, 20)
    .replace(/[._-]+$/, '')

  if (base.length < 3) return 'invitado'
  return base
}

export function validarAlias(alias) {
  const valor = normalizarAlias(alias)
  if (valor.length < 3) {
    return { valido: false, mensaje: 'El nombre de usuario debe tener al menos 3 caracteres.' }
  }
  if (valor.length > 20) {
    return { valido: false, mensaje: 'El nombre de usuario debe tener como máximo 20 caracteres.' }
  }
  if (!/^[a-z0-9]+(?:[._-][a-z0-9]+)*$/.test(valor)) {
    return {
      valido: false,
      mensaje:
        'Solo letras, números, puntos, guiones y guiones bajos, sin repetirlos ni al inicio o final.',
    }
  }
  if (ALIASES_RESERVADOS.includes(valor)) {
    return { valido: false, mensaje: 'Ese nombre de usuario está reservado. Probá otra variante.' }
  }
  return { valido: true, mensaje: '' }
}

export function validarCorreo(correo) {
  const valor = String(correo ?? '').trim()
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(valor)) {
    return { valido: false, mensaje: 'Ingresá un correo electrónico válido.' }
  }
  return { valido: true, mensaje: '' }
}

export function validarContrasena(contrasena) {
  const valor = String(contrasena ?? '')
  if (valor.length < 8) {
    return { valido: false, mensaje: 'La contraseña debe tener al menos 8 caracteres.' }
  }
  if (!/[a-zA-Z]/.test(valor) || !/[0-9]/.test(valor)) {
    return { valido: false, mensaje: 'La contraseña debe combinar letras y números.' }
  }
  return { valido: true, mensaje: '' }
}

export function esInvitado(usuario) {
  return Boolean(usuario?.is_anonymous || usuario?.app_metadata?.provider === 'anonymous')
}

export function usarAuth() {
  return {
    estado,
    esInvitado: computed(() => (estado.usuario ? esInvitado(estado.usuario) : false)),
    esAdminExpotec: computed(() => estado.esAdminExpotec),
  }
}

export async function inicializarSesion() {
  if (promesaInicial) return promesaInicial
  promesaInicial = (async () => {
    try {
      const { data } = await supabase.auth.getSession()
      if (data.session?.user) {
        await aplicarUsuario(data.session.user)
      }
    } catch {
      // Sesion perdida o corrupta (p. ej. token vencido): la app sigue
      // funcionando en modo publico en lugar de congelar la navegacion.
      estado.usuario = null
      estado.perfil = null
    } finally {
      estado.lista = true
    }
  })()
  await promesaInicial
  registrarSuscripcion()
  return promesaInicial
}

// Entra como invitado creando una sesion anonima real de Supabase. Cada llamada
// genera una identidad propia en auth.users; no existe una cuenta compartida.
export async function entrarComoInvitado() {
  const { data, error } = await supabase.auth.signInAnonymously()
  if (error) throw traducirError(error)
  if (!data.session?.user) {
    throw new Error('No pudimos crear la sesión de invitado. Intentá de nuevo.')
  }
  await aplicarUsuario(data.session.user)
  return data.session.user
}

/**
 * Garantiza una sesión válida para jugar o entrar al desafío: si ya hay una
 * sesión real o de invitado (vigente) la reutiliza; si no, inicia una anónima.
 * Evita crear identidades de más cuando la persona ya tiene sesión.
 */
export async function asegurarSesion() {
  try {
    const { data } = await supabase.auth.getSession()
    const usuarioActual = data.session?.user ?? null
    if (usuarioActual) {
      if (!estado.usuario || estado.usuario.id !== usuarioActual.id) {
        await aplicarUsuario(usuarioActual)
      }
      return usuarioActual
    }
  } catch {
    // Si no se puede consultar la sesión se conserva la que haya en memoria.
    if (estado.usuario) return estado.usuario
  }
  return entrarComoInvitado()
}

function registrarSuscripcion() {
  if (suscripcionRegistrada) return
  suscripcionRegistrada = true
  supabase.auth.onAuthStateChange((evento, sesion) => {
    if (evento === 'SIGNED_OUT') {
      estado.usuario = null
      estado.perfil = null
      return
    }
    if (sesion?.user) {
      aplicarUsuario(sesion.user)
    }
  })
}

// Dedupe para aplicar el mismo usuario en paralelo (arranque + onAuthStateChange).
let aplicacionUsuarioActiva = null

async function aplicarUsuario(usuario) {
  const id = usuario?.id
  if (aplicacionUsuarioActiva && aplicacionUsuarioActiva.id === id) {
    return aplicacionUsuarioActiva.promesa
  }

  const promesa = (async () => {
    estado.usuario = usuario
    await Promise.all([cargarPerfil(usuario.id), cargarProgreso().catch(() => {})])
    // Detectar si es administrador del panel de la ExpoTécnica. Nunca falla la
    // aplicación si la RPC falla: simplemente no es administrador.
    try {
      estado.esAdminExpotec = await esAdminExpotecRpc()
    } catch {
      estado.esAdminExpotec = false
    }
    return usuario
  })()

  const aplicacion = { id, promesa }
  aplicacionUsuarioActiva = aplicacion
  try {
    return await promesa
  } finally {
    if (aplicacionUsuarioActiva === aplicacion) {
      aplicacionUsuarioActiva = null
    }
  }
}

const CAMPOS_PERFIL =
  'id, nombre_usuario, nombre_visible, avatar_url, nivel, experiencia, racha_dias, racha_respuestas, created_at'

const espera = (ms) => new Promise((resolver) => setTimeout(resolver, ms))

async function leerPerfil(usuarioId) {
  const { data, error } = await supabase
    .from('perfiles')
    .select(CAMPOS_PERFIL)
    .eq('id', usuarioId)
    .maybeSingle()
  if (error) return null
  return data ?? null
}

/**
 * El perfil lo crea el trigger handle_new_user al crearse el usuario, y esa
 * insercion no es instantanea. Cuando el usuario recien creado todavia no
 * tiene fila, se reintenta unas veces antes de dar por perdido el perfil: de
 * eso depende que se vea el XP y que se pueda actualizar el alias.
 */
async function cargarPerfil(usuarioId, intentos = 5) {
  for (let intento = 1; intento <= intentos; intento += 1) {
    try {
      const perfil = await leerPerfil(usuarioId)
      if (perfil) {
        estado.perfil = perfil
        return perfil
      }
    } catch {
      estado.perfil = null
      return null
    }
    if (intento < intentos) await espera(intento * 120)
  }
  estado.perfil = null
  return null
}

/** Vuelve a leer el perfil propio, por ejemplo despues de ganar XP. */
export async function refrescarPerfil() {
  if (!estado.usuario) return null
  return cargarPerfil(estado.usuario.id, 2)
}

async function refrescarSesion() {
  try {
    const { data } = await supabase.auth.getSession()
    if (data.session?.user) {
      await aplicarUsuario(data.session.user)
    }
  } catch {
    // Se conserva el usuario en memoria aunque falle la consulta.
  }
}

// Registro. Hay dos caminos, ambos sobre Supabase Auth:
//   - con sesion de invitado: se convierte esa misma identidad (updateUser), por
//     lo que el id y los datos quedan intactos.
//   - sin sesion: signUp crea la cuenta desde cero.
export async function crearCuenta({ nombre, correo, contrasena }) {
  const nombreCompleto = String(nombre ?? '').trim()
  if (nombreCompleto.length < 2) {
    throw new Error('Ingresá tu nombre completo.')
  }

  const revisionCorreo = validarCorreo(correo)
  if (!revisionCorreo.valido) throw new Error(revisionCorreo.mensaje)

  const revisionContrasena = validarContrasena(contrasena)
  if (!revisionContrasena.valido) throw new Error(revisionContrasena.mensaje)

  const esInvitadoActual = estado.usuario ? esInvitado(estado.usuario) : false
  if (estado.usuario && !esInvitadoActual) {
    throw new Error('Ya tenés una cuenta asociada a esta sesión. Revisá tu perfil.')
  }

  if (esInvitadoActual) {
    return crearCuentaDesdeInvitado({ nombreCompleto, correo: correo.trim() })
  }

  return crearCuentaConSignUp({ nombreCompleto, correo: correo.trim(), contrasena })
}

async function crearCuentaDesdeInvitado({ nombreCompleto, correo }) {
  const aliasNormalizado = await resolverAliasUnico(generarAliasDesdeNombre(nombreCompleto))

  const { data: datosEmail, error: errorEmail } = await supabase.auth.updateUser({ email: correo })
  if (errorEmail) {
    if (correoYaRegistrado(errorEmail)) {
      throw new Error(
        'Ese correo ya pertenece a una cuenta existente. Usá otro correo o iniciá sesión con esa cuenta; la actividad de invitado no se traslada.',
      )
    }
    throw traducirError(errorEmail)
  }

  await actualizarPerfilPropio({ alias: aliasNormalizado, nombreVisible: nombreCompleto })

  // Si el proyecto no pide confirmar el correo, la identidad ya quedo vinculada.
  const verificadoAlMomento = Boolean(
    datosEmail.user?.email_confirmed_at || datosEmail.user?.confirmed_at,
  )

  return {
    via: 'conversion',
    requiereVerificacion: !verificadoAlMomento,
    correo,
    alias: aliasNormalizado,
  }
}

async function crearCuentaConSignUp({ nombreCompleto, correo, contrasena }) {
  const aliasNormalizado = await resolverAliasUnico(generarAliasDesdeNombre(nombreCompleto))

  const { data, error } = await supabase.auth.signUp({
    email: correo,
    password: contrasena,
    options: { data: { user_name: aliasNormalizado, name: nombreCompleto } },
  })
  if (error) throw traducirError(error)

  // El perfil lo crea el trigger al insertar en auth.users. Sin sesion no se
  // puede escribir (RLS), asi que el alias viaja en los metadatos del registro
  // y el trigger lo toma como nombre_usuario.
  if (data.session?.user) {
    await aplicarUsuario(data.session.user)
    await actualizarPerfilPropio({
      alias: aliasNormalizado,
      nombreVisible: nombreCompleto,
      usuarioId: data.session.user.id,
    })
  }

  const haySesion = Boolean(data.session?.user)
  return {
    via: 'registro',
    requiereConfirmacionCorreo: !haySesion,
    correo,
    alias: aliasNormalizado,
  }
}

async function resolverAliasUnico(aliasBase) {
  const base = normalizarAlias(aliasBase)
  const revision = validarAlias(base)
  if (!revision.valido) throw new Error(revision.mensaje)

  if (await aliasDisponible(base)) return base

  for (let intento = 2; intento <= 20; intento += 1) {
    const sufijo = String(intento)
    const candidato = `${base.slice(0, 20 - sufijo.length - 1)}${base.endsWith('.') ? '' : '.'}${sufijo}`
    const revisionCandidato = validarAlias(candidato)
    if (!revisionCandidato.valido) continue
    if (await aliasDisponible(candidato)) return candidato
  }

  throw new Error('No pudimos reservar tu nombre de usuario. Probá con otro nombre.')
}

export async function verificarCorreoCuenta({ correo, codigo }) {
  const { error } = await supabase.auth.verifyOtp({
    type: 'email_change',
    email: correo,
    token: String(codigo ?? '').trim(),
  })
  if (error) throw traducirError(error)
  await refrescarSesion()
}

export async function reenviarVerificacion({ correo, via }) {
  // Reenvía el correo de verificación. En usuarios invitados que se están
  // convirtiendo a cuenta real el tipo es 'email_change'; en signUp directo
  // el tipo es 'signup'. Si el proyecto no envía por rate limiting o por
  // plantilla, devolvemos un mensaje legible al caller.
  const email = String(correo ?? '').trim()
  if (!validarCorreo(email).valido) throw new Error('Correo inválido.')
  const tipo = via === 'conversion' ? 'email_change' : 'signup'
  const { error } = await supabase.auth.resend({ type: tipo, email })
  if (error) throw traducirError(error)
}

export async function correoVerificado() {
  try {
    const { data } = await supabase.auth.getUser()
    const u = data.user
    if (!u) return false
    estado.usuario = u
    await cargarPerfil(u.id)
    // La única señal clara de que el correo quedó verificado para esta sesión
    // es email_confirmed_at/confirmed_at. La mera existencia de un correo
    // o un usuario no anónimo no alcanza: un invitado convertido sigue
    // vinculado con el mismo ID siempre que confirme el correo.
    const confirmado = Boolean(u.email_confirmed_at || u.confirmed_at)
    const yaPermanente = !esInvitado(u)
    return confirmado && yaPermanente
  } catch {
    return false
  }
}

export async function establecerContrasena({ contrasena }) {
  const revision = validarContrasena(contrasena)
  if (!revision.valido) throw new Error(revision.mensaje)
  const { error } = await supabase.auth.updateUser({ password: contrasena })
  if (error) throw traducirError(error)
  await refrescarSesion()
}

export async function iniciarSesion({ correo, contrasena }) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email: String(correo ?? '').trim(),
    password: contrasena,
  })
  if (error) throw traducirError(error)
  if (data.session?.user) {
    await aplicarUsuario(data.session.user)
  }
  return data.user || null
}

export async function cerrarSesion() {
  const { error } = await supabase.auth.signOut()
  if (error) throw traducirError(error)
}

export async function recuperarContrasena({ correo }) {
  const revision = validarCorreo(correo)
  if (!revision.valido) throw new Error(revision.mensaje)
  const { error } = await supabase.auth.resetPasswordForEmail(String(correo ?? '').trim(), {
    redirectTo: urlRestablecer(),
  })
  if (error) throw traducirError(error)
}

export async function aliasDisponible(alias) {
  const { data, error } = await supabase
    .from('perfiles')
    .select('id')
    .ilike('nombre_usuario', alias)
    .maybeSingle()
  if (error) throw traducirError(error)
  return !data
}

async function actualizarPerfilPropio({ alias, nombreVisible, usuarioId }) {
  const cambios = { nombre_usuario: alias }
  if (nombreVisible && nombreVisible.trim()) {
    cambios.nombre_visible = String(nombreVisible).trim()
  }
  const id = usuarioId || estado.usuario?.id
  if (!id) throw new Error('No hay una sesión activa para guardar el perfil.')
  const { error } = await supabase.from('perfiles').update(cambios).eq('id', id)
  if (error) throw traducirError(error)
  if (!usuarioId || usuarioId === estado.usuario?.id) {
    await cargarPerfil(id)
  }
}

function urlOrigenActual() {
  if (typeof window !== 'undefined' && window.location && window.location.origin) {
    return window.location.origin
  }
  return ''
}

function corregirVentana() {
  // Capacitor compila y sirve el sitio dentro de un WebView (https://localhost).
  // Para que el correo de recuperación aterrice dentro de la app, se usa el
  // deep link kodigo://restablecer. Si no hay URL válida y tampoco estamos
  // en un origen web usable, caeremos a una URL de desarrollo únicamente
  // para que el flujo no quede roto; el usuario recibirá el correo y el
  // enlace abrirá la app gracias al intent-filter del APK.
  const base = URL_RESTABLECER || urlOrigenActual()
  if (base.startsWith('https://') || base.startsWith('http://') || base.startsWith('kodigo://')) {
    return base.replace(/\/$/, '')
  }
  // Último recurso: la vista de desarrollo si nada aplica.
  return 'http://localhost:5173'
}

function urlRestablecer() {
  return `${corregirVentana()}/acceso/restablecer`
}

function correoYaRegistrado(error) {
  const mensaje = String(error?.message || '').toLowerCase()
  const codigo = String(error?.code || '')
  return (
    mensaje.includes('already been registered') ||
    mensaje.includes('already exists') ||
    mensaje.includes('email already') ||
    mensaje.includes('ya está en uso') ||
    codigo === '23505' ||
    error?.status === 422
  )
}

function traducirError(error) {
  const mensaje = String(error?.message || '').toLowerCase()
  if (correoYaRegistrado(error)) {
    return new Error('Ese correo ya pertenece a una cuenta. Iniciá sesión o usá otro correo.')
  }
  if (mensaje.includes('anonymous sign-ins are disabled')) {
    return new Error('Los accesos de invitado están desactivados en este momento.')
  }
  if (mensaje.includes('manual linking') || mensaje.includes('link an identity')) {
    return new Error(
      'El registro desde invitado requiere la vinculación manual de identidades en Supabase.',
    )
  }
  if (
    mensaje.includes('invalid login credentials') ||
    mensaje.includes('invalid email or password') ||
    mensaje.includes('invalid credentials')
  ) {
    return new Error('Correo o contraseña incorrectos.')
  }
  if (mensaje.includes('email not allowed') || mensaje.includes('signup not allowed')) {
    return new Error('El registro con ese correo no está permitido.')
  }
  if (mensaje.includes('rate limit')) {
    return new Error('Demasiados intentos. Esperá unos minutos y volvé a intentar.')
  }
  if (
    mensaje.includes('reauthentication') ||
    mensaje.includes('reauth') ||
    mensaje.includes('recently used')
  ) {
    return new Error(
      'Para cambiar o restablecer tu contraseña, cerrá sesión y usá la opción "Olvidé mi contraseña".',
    )
  }
  if (mensaje.includes('password should be at least')) {
    return new Error('La contraseña es demasiado corta para la configuración del proyecto.')
  }
  // El perfil lo crea un trigger: si el alias ya existe, el INSERT falla y
  // gotrue lo reporta de forma generica.
  if (mensaje.includes('database error saving new user')) {
    return new Error('Ese nombre de usuario ya está en uso. Probá con otro nombre.')
  }
  if (mensaje.includes('network')) {
    return new Error('No hay conexión con el servidor. Revisá tu conexión e intentá de nuevo.')
  }
  return new Error(error?.message || 'No pudimos completar la operación. Intentá de nuevo.')
}
