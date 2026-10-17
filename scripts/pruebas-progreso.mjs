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
  assert.ok(sentencia.length >= 1, `debe existir la funcion ${nombre}`)
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

test('la regla de aprobacion es 2/3 con redondeo hacia arriba y vive en el servidor', () => {
  const texto = cuerpo('recalcular_intento')
  assert.match(texto, /v_correctas >= ceiling\(v_total::numeric \* 2 \/ 3\)/, 'debe usar el techo de 2/3')
  // El porcentaje nunca decide la aprobacion.
  assert.match(texto, /completado and v_correctas >= ceiling/)
})

test('la regla del servidor coincide con la constante del cliente', () => {
  const codigo = readFileSync(CATALOGO, 'utf8')
  const match = codigo.match(/FRACCION_MINIMA_PARA_APROBAR\s*=\s*2\s*\/\s*3/)
  assert.ok(match, 'el cliente debe exportar FRACCION_MINIMA_PARA_APROBAR')
  assert.match(codigo, /correctas >= Math\.ceil\(total \* FRACCION_MINIMA_PARA_APROBAR\)/)
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
  const jsonb = buscarSentencias(
    SQL,
    'create or replace function registrar_respuesta\\(|p_respuesta jsonb',
  ).length
  void jsonb

  const versionJsonb = buscarSentencias(SQL, 'create (or replace )?function registrar_respuesta').find(
    (texto) => /p_pregunta_id uuid,\s*\n\s*p_respuesta jsonb/.test(texto),
  )
  assert.ok(versionJsonb, 'debe existir la version jsonb de registrar_respuesta')

  const texto = versionJsonb
  assert.match(texto, /comprobar_respuesta\(p_pregunta_id, p_respuesta\)/, 'debe corregir en el servidor')
  assert.match(texto, /on conflict \(intento_id, pregunta_id\) do nothing/, 'una respuesta por pregunta')
  assert.match(texto, /ya_registrada/)
  assert.match(texto, /El intento ya fue finalizado/, 'no acepta respuestas en un intento cerrado')
  // El payload queda guardado para auditar y re-corregir.
  assert.match(
    texto,
    /insert into respuestas_intento\s*\(intento_id, pregunta_id, opcion_id, respuesta, correcta\)/,
  )
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

test('la migracion de tipos normaliza el modelo viejo (multiple_choice)', () => {
  // multiple_choice se traslada a 'seleccion' en bases ya aplicadas.
  assert.match(SQL, /update preguntas set tipo = 'seleccion' where tipo = 'multiple_choice'/)
})

test('el modelo de actividades soporta seis tipos con datos por pregunta', () => {
  const tabla = buscarSentencias(SQL, 'create table if not exists preguntas')[0]
  for (
    const tipo of [
      'seleccion',
      'verdadero_falso',
      'completar_texto',
      'completar_codigo',
      'ordenar',
      'relacionar',
    ]
  ) {
    assert.match(tabla, new RegExp(`'${tipo}'`), `el check debe incluir ${tipo}`)
  }
  assert.match(tabla, /datos jsonb/, 'preguntas debe tener datos jsonb')

  assert.match(buscarSentencias(SQL, 'create table if not exists soluciones')[0], /solucion jsonb/)
  assert.match(buscarSentencias(SQL, 'create table if not exists respuestas_intento')[0], /respuesta jsonb/)
})

test('comprobar_respuesta corrige cada tipo sin exponer soluciones', () => {
  const versionJsonb = buscarSentencias(SQL, 'create (or replace )?function comprobar_respuesta').find(
    (texto) => /p_pregunta_id uuid,\s*\n\s*p_respuesta jsonb/.test(texto),
  )
  assert.ok(versionJsonb, 'debe existir la version jsonb de comprobar_respuesta')
  for (const tipo of ['seleccion', 'verdadero_falso', 'completar_texto', 'completar_codigo', 'ordenar', 'relacionar']) {
    assert.match(versionJsonb, new RegExp(`'${tipo}'`), `${tipo} debe estar corregido`)
  }
  assert.match(versionJsonb, /texto_coincide_respuesta/)
  // normaliza: espacios, mayusculas y modo estricto para codigo.
  assert.match(SQL, /create or replace function normalizar_texto_respuesta/)
})

test('aprobar las actividades de la unidad desbloquea la unidad siguiente', () => {
  const desbloqueo = cuerpo('desbloquear_siguiente_unidad')
  assert.match(desbloqueo, /security definer/)
  assert.match(desbloqueo, /update unidades\s*\n\s*set estado_publicacion = 'publicado'/)

  const finalizar = cuerpo('finalizar_intento')
  assert.match(finalizar, /perform desbloquear_siguiente_unidad\(v_usuario, v_leccion\)/)
})

test('el seed de la curricula es idempotente y determinista', () => {
  // Ids por md5 de clave: re-aplicar no duplica contenido.
  assert.match(SQL, /uuid\(md5\('kodigo:preg:js:'/)
  assert.match(SQL, /uuid\(md5\('kodigo:opc:'/)

  // El problema de 'el cliente lee la solucion' se evita con valores
  // fuera de data de datos... el jsonb de solucion para texto/codigo
  // es vacio porque la correcta vive en datos de la propia pregunta.
  const bloqueTexto = buscarSentencias(SQL, 'kodigo:sol:texto:')[0]
  assert.ok(bloqueTexto, 'debe existir el bloque de soluciones de texto')
  assert.match(bloqueTexto, /'\{\}'::jsonb/)
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
