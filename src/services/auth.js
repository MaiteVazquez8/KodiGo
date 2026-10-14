import { computed, reactive } from 'vue'
import { supabase } from '@/supabase'

const URL_RESTABLECER = import.meta.env.VITE_SUPABASE_REDIRECT_URL

const ALIASES_RESERVADOS = ['admin', 'administrador', 'sistema', 'kodigo', 'perfil', 'mod']

export const estado = reactive({
  lista: false,
  usuario: null,
  perfil: null,
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

async function aplicarUsuario(usuario) {
  estado.usuario = usuario
  await cargarPerfil(usuario.id)
}

async function cargarPerfil(usuarioId) {
  try {
    const { data, error } = await supabase
      .from('perfiles')
      .select(
        'id, nombre_usuario, nombre_visible, avatar_url, nivel, experiencia, racha_dias, racha_respuestas, created_at',
      )
      .eq('id', usuarioId)
      .maybeSingle()
    estado.perfil = error ? null : data
  } catch {
    estado.perfil = null
  }
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

export async function correoVerificado() {
  try {
    const { data } = await supabase.auth.getUser()
    const u = data.user
    if (!u) return false
    estado.usuario = u
    await cargarPerfil(u.id)
    const tieneCorreo = Boolean(u.email)
    const confirmado = Boolean(u.email_confirmed_at)
    const yaPermanente = !esInvitado(u)
    return confirmado || (tieneCorreo && yaPermanente)
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

function urlRestablecer() {
  const base = URL_RESTABLECER || (typeof window !== 'undefined' ? window.location.origin : '')
  return `${base}/acceso/restablecer`
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
