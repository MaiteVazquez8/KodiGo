import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { buscarSentencias, leerSql } from './validar-sql.mjs'

const aqui = dirname(fileURLToPath(import.meta.url))
const leer = (...partes) => readFileSync(resolve(aqui, '..', ...partes), 'utf8')
const SQL = leerSql()

const catalogo = leer('src', 'services', 'catalogo.js')
const resultados = leer('src', 'views', 'ResultadosView.vue')
const actividad = leer('src', 'views', 'ActividadView.vue')
const auth = leer('src', 'services', 'auth.js')

test('una leccion bloqueada no se puede intentar desde el servidor', () => {
  const fn = buscarSentencias(SQL, 'create function es_leccion_publicada')
  assert.equal(fn.length, 1)
  assert.match(fn[0], /estado_publicacion = 'publicado'/)
  // 'bloqueada' puede quedar visible para listar, pero no se puede practicar.
  assert.ok(
    !/estado_publicacion in \('publicado', 'bloqueada'\)/.test(fn[0]),
    'no debe aceptar lecciones bloqueadas',
  )
})

test('los perfiles no se leen enteros entre usuarios', () => {
  const politica = buscarSentencias(SQL, 'create policy "perfiles para ranking"')
  assert.equal(politica.length, 0, 'no debe existir la politica que abre perfiles')
  const eliminada = buscarSentencias(SQL, 'drop policy if exists "perfiles para ranking"')
  assert.equal(eliminada.length, 1, 'debe eliminarse en bases ya aplicadas')

  // Tampoco debe quedar ninguna politica de select sobre perfiles sin filtrar.
  const selects = buscarSentencias(SQL, 'create policy "perfil propio visible"')
  assert.equal(selects.length, 1)
  assert.match(selects[0], /using \(id = auth\.uid\(\)\)/)
})

test('la vista publica de perfiles expone solo datos publicos', () => {
  const vista = buscarSentencias(SQL, 'create view perfiles_publicos')
  assert.equal(vista.length, 1)
  for (const columna of ['id', 'nombre_usuario', 'nivel', 'experiencia', 'racha_dias']) {
    assert.match(vista[0], new RegExp(`\\b${columna}\\b`), `falta ${columna}`)
  }
  // Ningun campo privado puede entrar en la vista.
  assert.ok(!/correo/.test(vista[0]), 'la vista no debe exponer correo')
  assert.ok(!/nombre_visible/.test(vista[0]), 'la vista no debe exponer nombre visible')
  assert.match(buscarSentencias(SQL, 'grant select on perfiles_publicos')[0], /to authenticated/)
})

test('el ranking se lee de la vista y no de la tabla completa', () => {
  const bloque = catalogo.slice(catalogo.indexOf('export async function obtenerRanking'))
  assert.match(bloque, /from\('perfiles_publicos'\)/)
  const publicos = catalogo.slice(catalogo.indexOf('export async function obtenerPerfilesPublicos'))
  assert.match(publicos.slice(0, 400), /from\('perfiles_publicos'\)/)
  assert.ok(!/from\('perfiles'\)/.test(bloque), 'el ranking no debe leer la tabla perfiles')
})

test('el XP no se pierde en silencio si el perfil todavia no existe', () => {
  const fn = buscarSentencias(SQL, 'create or replace function finalizar_intento')
  assert.equal(fn.length, 1)
  assert.match(fn[0], /update perfiles set experiencia/)
  assert.match(fn[0], /if not found then/)
  assert.match(fn[0], /todavia no esta disponible/)
})

test('el XP mostrado en resultados es el que devolvio el servidor', () => {
  // No puede quedar la cuenta local XP_POR_LECCION + correctas * XP_POR_CORRECTA.
  assert.ok(
    !/XP_POR_LECCION\s*\+/.test(resultados),
    'no se debe calcular el XP en el cliente',
  )
  assert.match(resultados, /resultados\.value\?\.xpGanado/)
})

test('tras cerrar el intento se relee el perfil para mostrar el XP guardado', () => {
  assert.match(resultados, /await refrescarPerfil\(\)/)
  assert.match(auth, /export async function refrescarPerfil/)
})

test('la vista espera a que el trigger cree el perfil', () => {
  // El perfil lo crea el trigger: leerlo una sola vez puede devolver null.
  assert.match(auth, /intentos\s*=\s*5/)
  assert.match(auth, /await espera\(/)
})

test('con sesion, un fallo del servidor no degrada a practica sin guardar', () => {
  const bloque = actividad.slice(actividad.indexOf('const intentoExistente'))
  assert.match(bloque, /else if \(!estadoAuth\.usuario\)/, 'debe comprobar la sesion')
  assert.match(bloque, /estado\.value = 'error'/, 'un fallo real debe mostrar error')
  assert.match(bloque, /return/, 'debe cortar la carga')
  // El catch no puede quedarse mudo convertingiendose en "sin sesion".
  assert.ok(!/catch \{[\s\S]{0,120}sinSesion\.value = true[\s\S]{0,40}\}/.test(bloque))
})

test('el visitante sin sesion ve el aviso de que no se guarda', () => {
  assert.match(actividad, /Entrar como invitado/)
  assert.match(actividad, /sinSesion/)
})

test('el modo invitado se crea con signInAnonymously y espera confirmacion', () => {
  assert.match(auth, /signInAnonymously\(\)/)
  assert.match(auth, /if \(!data\.session\?\.user\)/)
  // No puede haber un identificador fijo compartido para todos los invitados.
  assert.ok(!/invitado.{0,40}=\s*'[0-9a-f]{8}-[0-9a-f]{4}/i.test(auth), 'prohibido un id fijo')
})

test('esInvitado distingue el proveedor anonimo', () => {
  assert.match(auth, /is_anonymous/)
  assert.match(auth, /provider === 'anonymous'/)
})