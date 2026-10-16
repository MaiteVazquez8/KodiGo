import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { dividirSentencias, leerSql, normalizar, buscarSentencias } from './validar-sql.mjs'

const aqui = dirname(fileURLToPath(import.meta.url))
const CATALOGO = resolve(aqui, '..', 'src', 'services', 'catalogo.js')
const SQL = leerSql()

const cuerpo = (nombre) => {
  const sentencia = buscarSentencias(SQL, `create (or replace )?function ${nombre}\\b`)
  assert.equal(sentencia.length, 1, `debe existir una sola funcion ${nombre}`)
  return sentencia[0]
}

test('el SQL es sintacticamente parseable', () => {
  const sentencias = dividirSentencias(SQL)
  assert.ok(sentencias.length > 50, 'el script debe tener sentencias')
})

test('las funciones de progreso existen y son security definer', () => {
  for (const nombre of [
    'iniciar_intento',
    'registrar_respuesta',
    'finalizar_intento',
    'recalcular_intento',
  ]) {
    assert.match(cuerpo(nombre), /security definer/, `${nombre} debe ser security definer`)
    assert.match(cuerpo(nombre), /set search_path = public/, `${nombre} debe fijar search_path`)
  }
})

test('cada RPC exige sesion y valida que el intento sea del usuario', () => {
  for (const nombre of ['iniciar_intento', 'registrar_respuesta', 'finalizar_intento']) {
    const texto = cuerpo(nombre)
    assert.match(texto, /auth\.uid\(\)/, `${nombre} debe usar auth.uid()`)
    assert.match(
      texto,
      /usuario_id = auth\.uid\(\)|usuario_id = v_usuario/,
      `${nombre} debe filtrar por el usuario de la sesion`,
    )
  }
})

test('recalcular_intento no se puede ejecutar desde el exterior', () => {
  const permisos = buscarSentencias(SQL, 'revoke all on function recalcular_intento').length
  assert.equal(permisos, 1, 'recalcular_intento debe estar revokeada')
  const concessiones = buscarSentencias(SQL, 'grant execute on function recalcular_intento')
  assert.equal(concessiones.length, 0, 'recalcular_intento no debe recibir grant')
})

test('las RPC de escritura solo se conceden a authenticated', () => {
  for (const firma of [
    'iniciar_intento(uuid, uuid)',
    'registrar_respuesta(uuid, uuid, uuid)',
    'finalizar_intento(uuid)',
    'obtener_progreso()',
  ]) {
    const grant = buscarSentencias(
      SQL,
      `grant execute on function ${firma.replace(/[()]/g, (c) => '\\' + c)}`,
    )
    assert.equal(grant.length, 1, `falta el grant de ${firma}`)
    assert.match(grant[0], /to authenticated/, `${firma} debe concederse a authenticated`)
  }
})

test('la regla de aprobacion sigue siendo 2 de 3 y vive en el servidor', () => {
  assert.match(cuerpo('recalcular_intento'), /v_correctas >= 2/, 'la regla debe seguir siendo 2')
  // El porcentaje nunca decide la aprobacion.
  assert.match(cuerpo('recalcular_intento'), /completado and v_correctas >= 2/)
})

test('la regla del servidor coincide con la constante del cliente', () => {
  const codigo = readFileSync(CATALOGO, 'utf8')
  const match = codigo.match(/CORRECTAS_MINIMAS_PARA_APROBAR\s*=\s*(\d+)/)
  assert.ok(match, 'el cliente debe exportar CORRECTAS_MINIMAS_PARA_APROBAR')
  assert.equal(Number(match[1]), 2, 'el cliente debe usar el mismo 2 que el servidor')
})

test('iniciar_intento es idempotente por clave', () => {
  const texto = cuerpo('iniciar_intento')
  assert.match(texto, /clave_idempotencia/, 'debe usar la clave de idempotencia')
  assert.match(texto, /on conflict \(usuario_id, clave_idempotencia\) do nothing/)
  assert.match(texto, /ya_existia/)
  assert.match(buscarSentencias(SQL, 'intentos_clave_unica')[0], /unique \(usuario_id, clave_idempotencia\)/)
})

test('una misma clave no se puede reutilizar en otra leccion', () => {
  assert.match(cuerpo('iniciar_intento'), /La clave de idempotencia ya fue usada para otra leccion/)
})

test('registrar_respuesta corrige contra soluciones y no acepta aciertos del cliente', () => {
  const texto = cuerpo('registrar_respuesta')
  assert.match(texto, /comprobar_respuesta\(p_pregunta_id, p_opcion_id\)/, 'debe corregir en el servidor')
  assert.match(texto, /on conflict \(intento_id, pregunta_id\) do nothing/, 'una respuesta por pregunta')
  assert.match(texto, /ya_registrada/)
  assert.match(texto, /El intento ya fue finalizado/, 'no acepta respuestas en un intento cerrado')
})

test('los contadores del intento se recalculan desde las respuestas guardadas', () => {
  const texto = cuerpo('registrar_respuesta')
  assert.match(texto, /respuestas_correctas = \(select count\(\*\)::integer from respuestas_intento/)
  assert.match(texto, /respuestas_incorrectas = \(select count\(\*\)::integer from respuestas_intento/)
})

test('finalizar_intento es idempotente y no duplica XP', () => {
  const texto = cuerpo('finalizar_intento')
  assert.match(texto, /if v_estado <> 'en_curso' then/, 'debe_short-circuitear si ya estaba cerrado')
  assert.match(texto, /v_resumen\.aprobado and not v_ya_aprobada/, 'el XP es solo la primera aprobacion')
  assert.match(texto, /select p\.aprobada into v_ya_aprobada/, 'debe leer si la leccion ya estaba aprobada')
  assert.match(buscarSentencias(SQL, 'xp_ganado')[0] ?? '', /xp_ganado/)
})

test('finalizar_intento acumula progreso sin perder el mejor resultado', () => {
  const texto = cuerpo('finalizar_intento')
  assert.match(texto, /on conflict \(usuario_id, leccion_id\) do update/)
  assert.match(texto, /mejor_porcentaje = greatest\(/)
  assert.match(texto, /intentos = progreso_lecciones\.intentos \+ 1/)
  assert.match(texto, /aprobada = progreso_lecciones\.aprobada or excluded\.aprobada/)
})

test('el cliente no puede escribir progreso, intentos ni respuestas directamente', () => {
  const escritas = ['progreso propio inserta', 'progreso propio modifica', 'intentos propios inserta', 'respuestas propias inserta']
  for (const politica of escritas) {
    const creada = buscarSentencias(SQL, `create policy "${politica}"`)
    assert.equal(creada.length, 0, `no debe existir la politica de escritura "${politica}"`)
    const eliminada = buscarSentencias(SQL, `drop policy if exists "${politica}"`)
    assert.equal(eliminada.length, 1, `debe eliminarse la politica "${politica}"`)
  }
})

test('el cliente solo puede leer su propio progreso', () => {
  const visible = buscarSentencias(SQL, 'create policy "progreso propio visible"')
  assert.equal(visible.length, 1)
  assert.match(visible[0], /for select/)
  assert.match(visible[0], /using \(usuario_id = auth\.uid\(\)\)/)
})

test('registrar_respuesta rechaza preguntas de otra leccion', () => {
  assert.match(cuerpo('registrar_respuesta'), /La pregunta no pertenece a la leccion o no esta publicada/)
})

test('el progreso se lee siempre por leccion', () => {
  const texto = cuerpo('obtener_progreso')
  assert.match(texto, /where p\.usuario_id = auth\.uid\(\)/)
  assert.match(texto, /for select|security invoker/)
})

test('la migracion es idempotente y no invalida intentos en curso', () => {
  // Las columnas se agregan dentro de un bloque do $$ $$: se cuenta sobre el
  // SQL crudo, no sobre las sentencias ya divididas.
  const columnas = [...SQL.matchAll(/alter table (intentos|progreso_lecciones) add column/gi)]
  assert.ok(columnas.length >= 8, `deben agregarse todas las columnas nuevas (hay ${columnas.length})`)
  assert.match(SQL, /information_schema\.columns/, 'las columnas se agregan si no existen')

  // Nunca debe cerrar intentos que siguen en curso.
  assert.match(SQL, /where estado = 'en_curso' and completado;/)
  assert.ok(!/where estado = 'en_curso' and \(completado or/.test(normalizar(SQL)))
})

test('las soluciones siguen bloqueadas para el cliente', () => {
  const politica = buscarSentencias(SQL, 'create policy "soluciones bloqueadas"')
  assert.equal(politica.length, 1)
  assert.match(politica[0], /using \(false\)/)
})
