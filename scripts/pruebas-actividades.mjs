import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import {
  buscarSentencias,
  dividirSentencias,
  leerSql,
  normalizar,
} from './validar-sql.mjs'

// ---------------------------------------------------------------------------
// Pruebas de las modalidades de actividad y de las pantallas que las consumen.
//
// El proyecto no ejecuta PostgreSQL en las pruebas: se verifica el contrato
// que el SQL y los componentes exponen (tipos, validaciones, proteccion de
// soluciones, administracion, progreso individual, logros y estadisticas).
// ---------------------------------------------------------------------------

const aqui = dirname(fileURLToPath(import.meta.url))
const leer = (...partes) => readFileSync(resolve(aqui, '..', ...partes), 'utf8')

const SQL = leerSql()
const sentencias = dividirSentencias(SQL)

const catalogo = leer('src', 'services', 'catalogo.js')
const ejecutor = leer('src', 'components', 'EjecutorActividad.vue')
const adminVista = leer('src', 'views', 'AdminExpotecnicaView.vue')
const adminServicio = leer('src', 'services', 'expotecnica-admin.js')
const logrosVista = leer('src', 'views', 'LogrosView.vue')
const perfilVista = leer('src', 'views', 'PerfilView.vue')
const estadisticasVista = leer('src', 'views', 'EstadisticasView.vue')
const revisionVista = leer('src', 'views', 'ReviewView.vue')
const diccionarioVista = leer('src', 'views', 'DiccionarioView.vue')
const amigosVista = leer('src', 'views', 'AmigosView.vue')
const buscarAmigosVista = leer('src', 'views', 'BuscarAmigosView.vue')
const ayudaVista = leer('src', 'views', 'AyudaView.vue')
const configuracionVista = leer('src', 'views', 'ConfiguracionView.vue')
const leccionVista = leer('src', 'views', 'LeccionView.vue')
const resultadosVista = leer('src', 'views', 'ResultadosView.vue')
const router = leer('src', 'router', 'index.js')

/** Devuelve el texto normalizado de la ultima definicion de una funcion. */
function funcion(nombre) {
  const lista = buscarSentencias(SQL, `create (or replace )?function ${nombre}\\(`)
  assert.ok(lista.length >= 1, `debe existir la funcion ${nombre}`)
  return normalizar(lista[lista.length - 1])
}

/** Devuelve la version jsonb de comprobar_respuesta (la que corrige). */
function corrector() {
  const lista = buscarSentencias(
    SQL,
    'create (or replace )?function comprobar_respuesta\\(',
  )
  const jsonb = lista.find((s) => /p_respuesta jsonb/.test(normalizar(s)))
  assert.ok(jsonb, 'debe existir la version jsonb de comprobar_respuesta')
  return normalizar(jsonb)
}

/** Devuelve la version jsonb de registrar_respuesta (la que corrige). */
function registrador() {
  const lista = buscarSentencias(
    SQL,
    'create (or replace )?function registrar_respuesta\\(',
  )
  const jsonb = lista.find((s) => /p_respuesta jsonb/.test(normalizar(s)))
  assert.ok(jsonb, 'debe existir la version jsonb de registrar_respuesta')
  return normalizar(jsonb)
}

function ultimaSentencia(patron) {
  const lista = buscarSentencias(SQL, patron)
  assert.ok(lista.length >= 1, `falta la sentencia ${patron}`)
  return normalizar(lista[lista.length - 1])
}

// ---------------------------------------------------------------------------
// 1. Modelo de once modalidades
// ---------------------------------------------------------------------------

test('el modelo acepta las once modalidades sin romper las seis historicas', () => {
  const restriccion = ultimaSentencia('add constraint preguntas_tipo_check')
  for (const tipo of [
    'seleccion',
    'verdadero_falso',
    'completar_texto',
    'completar_codigo',
    'ordenar',
    'relacionar',
    'escribir_codigo',
    'corregir_codigo',
    'salida_codigo',
    'predecir',
    'bloques',
  ]) {
    assert.match(restriccion, new RegExp(`'${tipo}'`), `falta el tipo ${tipo}`)
  }
  assert.match(restriccion, /preguntas_tipo_check/)
})

test('las actividades guardan datos publicos y soluciones separadas', () => {
  const tablaPreguntas = ultimaSentencia('create table if not exists preguntas')
  assert.match(tablaPreguntas, /datos jsonb/)
  assert.match(tablaPreguntas, /estado_publicacion/)

  const tablaSoluciones = ultimaSentencia('create table if not exists soluciones')
  assert.match(tablaSoluciones, /solucion jsonb/)
  assert.match(tablaSoluciones, /pregunta_id/)
})

// ---------------------------------------------------------------------------
// 2. Correccion del servidor: estructura, tipos y equivalencias
// ---------------------------------------------------------------------------

test('comprobar_respuesta valida el JSON y corrige los once tipos', () => {
  const texto = corrector()

  assert.match(texto, /jsonb_typeof\(p_respuesta\) <> 'object'/)
  assert.match(texto, /v_tipo in \('seleccion', 'verdadero_falso'\)/)
  for (const tipo of [
    'completar_texto',
    'completar_codigo',
    'ordenar',
    'relacionar',
    'escribir_codigo',
    'corregir_codigo',
    'salida_codigo',
    'predecir',
    'bloques',
  ]) {
    assert.match(texto, new RegExp(`'${tipo}'`), `falta corregir ${tipo}`)
  }
  // El cliente manda una respuesta, nunca el veredicto.
  assert.ok(!/p_correcta/.test(texto), 'el cliente no decide el resultado')
})

test('seleccion y verdadero_falso exigen una opcion que pertenezca a la pregunta', () => {
  const texto = corrector()
  assert.match(texto, /p_respuesta -> 'opcion_id'/)
  assert.match(texto, /where id = \(v_valor #>> '\{\}'\)::uuid/)
  assert.match(texto, /and pregunta_id = p_pregunta_id/)
  assert.match(texto, /v_opcion_correcta = \(v_valor #>> '\{\}'\)::uuid/)
})

test('completar_texto ignora espacios, respeta mayusculas y acepta alternativas', () => {
  const texto = corrector()
  assert.match(texto, /texto_coincide_respuesta/)
  assert.match(texto, /v_solucion ->> 'valor'/)
  assert.match(texto, /v_datos ->> 'valor'/, 'debe mantener compatibilidad con datos viejos')
  assert.match(texto, /v_solucion -> 'alternativas'/)
  assert.match(texto, /v_datos -> 'alternativas'/)
  assert.match(texto, /v_solucion ->> 'estricta'/)
  assert.match(SQL, /create or replace function normalizar_texto_respuesta/)
})

test('completar_codigo exige blancos y compara solo textos', () => {
  const texto = corrector()
  assert.match(texto, /v_tipo = 'completar_codigo'/)
  assert.match(texto, /v_solucion -> 'blancos'/)
  assert.match(texto, /v_datos -> 'blancos'/)
  assert.match(texto, /jsonb_typeof\(v_valor\) <> 'string'/)
  assert.match(texto, /texto_coincide_respuesta/)
})

test('ordenar exige todos los elementos en el orden exacto', () => {
  const texto = corrector()
  assert.match(texto, /v_tipo = 'ordenar'/)
  assert.match(texto, /v_longitud = jsonb_array_length\(v_orden_enviada\)/)
  assert.match(texto, /v_orden_esperada = v_orden_enviada/)
  assert.match(texto, /join opciones o on o\.id::text = ids/)
})

test('relacionar exige pares completos, distintos y exactos', () => {
  const texto = corrector()
  assert.match(texto, /v_tipo = 'relacionar'/)
  assert.match(texto, /v_total_pares > 0/)
  assert.match(texto, /v_total_pares = jsonb_array_length\(v_respuesta\)/)
  assert.match(texto, /count\(distinct value ->> 'id_a'\)/)
  assert.match(texto, /re ->> 'id_a' = sp ->> 'id_a'/)
  assert.match(texto, /re ->> 'id_b' = sp ->> 'id_b'/)
})

test('escribir y corregir codigo comparan contra soluciones o patrones del servidor', () => {
  const texto = corrector()
  assert.match(texto, /v_tipo in \('escribir_codigo', 'corregir_codigo'\)/)
  assert.match(texto, /v_valor := p_respuesta -> 'codigo'/)
  assert.match(texto, /codigo_coincide_respuesta/)
  assert.match(texto, /v_soluciones/)
  assert.match(texto, /v_requeridos/)
  assert.match(texto, /v_prohibidos/)
  assert.match(texto, /if btrim\(v_codigo\) = ''/)
  // Sin sandbox: no se ejecuta JavaScript dentro de PostgreSQL.
  assert.ok(!/plv8|\beval\s*\(/i.test(SQL), 'el SQL no debe ejecutar codigo JS')
})

test('salida de codigo y predecir aceptan opciones o texto, nunca ambos a la vez', () => {
  const texto = corrector()
  assert.match(texto, /v_tipo in \('salida_codigo', 'predecir'\)/)
  assert.match(texto, /if p_respuesta \? 'opcion_id'/)
  assert.match(texto, /elsif p_respuesta \? 'valor'/)
  assert.match(texto, /la respuesta debe indicar una opcion o un valor/)
})

test('bloques exige ids conocidos, sin repetir y en el orden correcto', () => {
  const texto = corrector()
  assert.match(texto, /v_tipo = 'bloques'/)
  assert.match(texto, /v_bloques := p_respuesta -> 'bloques'/)
  assert.match(texto, /v_orden_esperada := v_solucion -> 'orden'/)
  assert.match(texto, /v_ids_conocidos = v_longitud/)
  assert.match(texto, /count\(distinct value\) from jsonb_array_elements_text\(v_bloques\)/)
  assert.match(texto, /v_orden_esperada = v_bloques/)
})

// ---------------------------------------------------------------------------
// 3. Persistencia y proteccion de soluciones
// ---------------------------------------------------------------------------

test('registrar_respuesta guarda lo enviado y corrige en el servidor', () => {
  const texto = registrador()
  assert.match(texto, /comprobar_respuesta\(p_pregunta_id, p_respuesta\)/)
  assert.match(
    texto,
    /insert into respuestas_intento \(intento_id, pregunta_id, opcion_id, respuesta, correcta\)/,
  )
  assert.match(texto, /on conflict \(intento_id, pregunta_id\) do nothing/)
  assert.match(texto, /el intento ya fue finalizado/i)
})

test('las soluciones no son legibles por el cliente', () => {
  const bloqueadas = buscarSentencias(SQL, 'create policy "soluciones bloqueadas"')
  assert.equal(bloqueadas.length, 1)
  assert.match(normalizar(bloqueadas[0]), /using \(false\)/)
  // Solo el administrador puede leerlas para editarlas.
  const admin = buscarSentencias(SQL, 'create policy "soluciones para administrador"')
  assert.equal(admin.length, 1)
  assert.match(normalizar(admin[0]), /es_administrador_expotec\(\)/)
})

test('las respuestas historicas migran de datos a soluciones', () => {
  assert.match(
    SQL,
    /update soluciones s[\s\S]{0,400}from preguntas p[\s\S]{0,400}p\.tipo = 'completar_texto'/,
  )
  assert.match(SQL, /set datos = p\.datos - 'valor' - 'alternativas'/)
  assert.match(SQL, /set datos = p\.datos - 'blancos'/)
})

test('el cliente sanea cualquier respuesta que venga dentro de datos', () => {
  assert.match(catalogo, /export function sanearDatosPregunta/)
  for (const clave of [
    'valor',
    'alternativas',
    'soluciones',
    'requeridos',
    'prohibidos',
    'salida_esperada',
  ]) {
    assert.match(
      catalogo,
      new RegExp(`delete copia\\.${clave}`),
      `sanearDatosPregunta debe borrar ${clave}`,
    )
  }
  assert.match(catalogo, /copia\.blancos = copia\.blancos\.map\(\(blanco\) => \(\{ clave: blanco\.clave \}\)\)/)
  assert.match(catalogo, /datos: sanearDatosPregunta\(fila\.datos \|\| null\)/)
})

// ---------------------------------------------------------------------------
// 4. Administracion de todas las modalidades
// ---------------------------------------------------------------------------

test('el panel admin ofrece los once tipos y campos dinamicos', () => {
  const tipos = adminVista.match(/TIPOS_ACTIVIDAD = \[([\s\S]*?)\n\]/)
  assert.ok(tipos, 'debe existir TIPOS_ACTIVIDAD')
  for (const tipo of [
    'seleccion',
    'verdadero_falso',
    'completar_texto',
    'completar_codigo',
    'ordenar',
    'relacionar',
    'escribir_codigo',
    'corregir_codigo',
    'salida_codigo',
    'predecir',
    'bloques',
  ]) {
    assert.match(tipos[1], new RegExp(`'${tipo}'`), `falta ${tipo} en el selector`)
  }
  assert.match(adminVista, /v-model="actividadForm\.tipo"/)
  assert.match(adminVista, /actividadForm\.tipo === 'completar_codigo'/)
  assert.match(adminVista, /actividadForm\.tipo === 'bloques'/)
  assert.match(adminVista, /actividadForm\.tipo === 'escribir_codigo' \|\| actividadForm\.tipo === 'corregir_codigo'/)
})

test('el panel admin guarda borradores, valida al publicar y edita existentes', () => {
  assert.match(adminVista, /<option value="borrador">Guardar como borrador<\/option>/)
  assert.match(adminVista, /<option value="publicado">Publicar \(valida antes\)<\/option>/)
  assert.match(adminVista, /guardarActividad\(\{/)
  assert.match(adminVista, /id: actividadForm\.id/)
  assert.match(adminVista, /editarActividad\(p\)/)
  assert.match(adminVista, /resetActividadForm\(\)/)
  assert.match(adminServicio, /export async function guardarActividad/)
  assert.match(adminServicio, /supabase\.rpc\('expotec_admin_guardar_actividad'/)
})

test('el servidor bloquea publicar actividades incompletas', () => {
  const texto = funcion('expotec_admin_guardar_actividad')
  assert.match(texto, /perform expotec_guard_admin\(\)/)
  assert.match(texto, /v_inconveniente := expotec_inconveniente_pregunta\(v_id\)/)
  assert.match(texto, /if v_inconveniente is not null then/)
  assert.match(texto, /raise exception '%', v_inconveniente/)
  // Se guarda primero como borrador y solo se publica si pasa la validacion.
  assert.match(texto, /estado_publicacion = 'borrador'/)
  assert.match(texto, /update preguntas set estado_publicacion = 'publicado'/)
})

test('el servidor impide cambiar opciones con respuestas registradas', () => {
  const texto = funcion('expotec_admin_guardar_actividad')
  assert.match(
    texto,
    /if exists \(select 1 from respuestas_intento where pregunta_id = v_id\) then/,
  )
  assert.match(texto, /No se pueden cambiar las opciones de una actividad que ya tiene respuestas/i)
})

test('el validador de publicacion cubre las once modalidades', () => {
  const texto = funcion('expotec_inconveniente_pregunta')
  for (const tipo of [
    'seleccion',
    'verdadero_falso',
    'completar_texto',
    'completar_codigo',
    'ordenar',
    'relacionar',
    'escribir_codigo',
    'corregir_codigo',
    'salida_codigo',
    'predecir',
    'bloques',
  ]) {
    assert.match(texto, new RegExp(`'${tipo}'`), `falta validar ${tipo}`)
  }
  assert.match(texto, /La actividad necesita una explicacion/i)
})

// ---------------------------------------------------------------------------
// 5. Render e interaccion en el cliente
// ---------------------------------------------------------------------------

test('el ejecutor muestra tipo, enunciado e instrucciones antes de comprobar', () => {
  assert.match(ejecutor, /class="activity-tipo"/)
  assert.match(ejecutor, /class="activity-instrucciones"/)
  assert.match(ejecutor, /etiquetaTipo/)
  assert.match(ejecutor, /const instrucciones = computed/)
  assert.match(ejecutor, /ETIQUETAS_TIPO/)
  assert.ok(!/solucion|respuesta_correcta/i.test(ejecutor.slice(0, ejecutor.indexOf('<script'))), 'el template no debe mostrar la solución')
})

test('el ejecutor renderiza las once modalidades', () => {
  for (const tipo of [
    'seleccion',
    'verdadero_falso',
    'completar_texto',
    'completar_codigo',
    'ordenar',
    'relacionar',
    'escribir_codigo',
    'corregir_codigo',
    'salida_codigo',
    'predecir',
    'bloques',
  ]) {
    assert.match(
      ejecutor,
      new RegExp(`tipo === '${tipo}'`),
      `el template debe renderizar ${tipo}`,
    )
  }
})

test('el ejecutor arma el payload correcto para cada modalidad', () => {
  const cuerpo = ejecutor.slice(ejecutor.indexOf('function cuerpoRespuesta'))
  assert.match(cuerpo, /opcion_id: seleccionId\.value/)
  assert.match(cuerpo, /valor: textoLibre\.value/)
  assert.match(cuerpo, /blancos: \{ \.\.\.blancos\.value \}/)
  assert.match(cuerpo, /orden: \[\.\.\.ordenElementos\.value\]/)
  assert.match(cuerpo, /pares: Object\.entries\(paresFormados\.value\)/)
  assert.match(cuerpo, /codigo: codigoEscrito\.value/)
  assert.match(cuerpo, /bloques: bloquesElegidos\.value\.map\(\(bloque\) => bloque\.id\)/)
})

test('bloques se arma eligiendo, borrando y reordenando, no solo ordenando', () => {
  assert.match(ejecutor, /function agregarBloque/)
  assert.match(ejecutor, /function quitarBloque/)
  assert.match(ejecutor, /function moverBloque/)
  assert.match(ejecutor, /const bloquesPaleta = computed/)
  // Los bloques ya usados desaparecen de la paleta y quedan los distractores.
  assert.match(ejecutor, /!bloquesElegidos\.value\.some/)
  assert.match(ejecutor, /aria-label="Quitar bloque"/)
})

test('la vista previa de codigo es local y no corrige', () => {
  assert.match(ejecutor, /new Worker/)
  assert.match(ejecutor, /No corrige: solo muestra console\.log/)
  assert.match(ejecutor, /La vista previa tardó demasiado/)
  assert.ok(!/emit\('comprobar'[\s\S]{0,80}vistaPrevia/i.test(ejecutor))
})

// ---------------------------------------------------------------------------
// 6. Contenido progresivo de JavaScript
// ---------------------------------------------------------------------------

test('la practica ampliada tiene 23 actividades en las 10 lecciones', () => {
  const inicio = SQL.indexOf('-- 18. Practica ampliada')
  const fin = SQL.indexOf('-- 18.1.')
  assert.ok(inicio !== -1 && fin !== -1, 'deben existir las secciones 18 y 18.1')
  const bloque = SQL.slice(inicio, SQL.length)
  const claves = [...bloque.matchAll(/\('(js2:[^']+)',\s*\d+,\s*\n/g)].map((m) => m[1])
  assert.equal(claves.length, 23)
  const lecciones = new Set(
    [...bloque.matchAll(/\('(js2:[^']+)',\s*(\d+),\s*\n/g)].map((m) => Number(m[2])),
  )
  assert.deepEqual([...lecciones].sort((a, b) => a - b), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  assert.equal(new Set(claves).size, claves.length, 'no debe haber claves repetidas')
})

test('la practica ampliada con opciones usa modo opciones', () => {
  assert.match(SQL, /js2:l03:a3/)
  assert.match(SQL, /js2:l09:a3/)
  assert.match(SQL, /"modo": "opciones"/)
  assert.match(SQL, /kodigo:opt:js2:/)
  assert.match(SQL, /kodigo:sol:js2:/)
})

test('la practica ampliada mezcla modalidades nuevas en todas las unidades', () => {
  const bloque = SQL.slice(SQL.indexOf("uuid(md5('kodigo:preg:js2:'"))
  for (const tipo of [
    'predecir',
    'escribir_codigo',
    'salida_codigo',
    'corregir_codigo',
    'bloques',
    'completar_codigo',
    'completar_texto',
  ]) {
    assert.match(bloque, new RegExp(`'${tipo}'`), `falta ${tipo} en la practica`)
  }
})

test('las respuestas de la practica ampliada viven en soluciones', () => {
  const soluciones = SQL.slice(SQL.indexOf("insert into soluciones (pregunta_id, opcion_correcta_id, solucion, explicacion)"))
  for (const clave of ['js2:l01:a1', 'js2:l03:a1', 'js2:l06:a1', 'js2:l10:a2']) {
    assert.match(soluciones, new RegExp(`'${clave}'`), `falta la solucion de ${clave}`)
  }
  assert.match(soluciones, /solucion,/)
  assert.match(soluciones, /explicacion/)
})

test('los datos publicos de la practica no incluyen la respuesta correcta', () => {
  const inicio = SQL.indexOf("uuid(md5('kodigo:preg:js2:'")
  const fin = SQL.indexOf('-- Soluciones de la practica ampliada')
  const bloque = SQL.slice(inicio, fin)
  assert.ok(!/"soluciones"\s*:/.test(bloque), 'datos no debe incluir soluciones')
  assert.ok(!/"requeridos"\s*:/.test(bloque), 'datos no debe incluir patrones requeridos')
  assert.ok(!/"prohibidos"\s*:/.test(bloque), 'datos no debe incluir patrones prohibidos')
  // Los blancos de completar_codigo solo exponen la clave, no el valor.
  const blancos = [...bloque.matchAll(/"blancos"\s*:\s*(\[[^\]]*\])/g)].map((m) => m[1])
  for (const lista of blancos) {
    assert.ok(!/"valor"\s*:/.test(lista), `blanco con respuesta filtrada: ${lista}`)
  }
})

// ---------------------------------------------------------------------------
// 7. Progreso individual, XP y logros
// ---------------------------------------------------------------------------

test('el desbloqueo es por usuario y no publica la unidad global', () => {
  const tabla = ultimaSentencia('create table if not exists progreso_unidades')
  assert.match(tabla, /usuario_id/)
  assert.match(tabla, /unidad_id/)
  assert.match(tabla, /completada_en/)

  const desbloqueo = funcion('desbloquear_siguiente_unidad')
  assert.match(desbloqueo, /insert into progreso_unidades/)
  assert.ok(!/update unidades/.test(desbloqueo), 'no debe mutar el estado global de la unidad')

  const acceso = funcion('es_leccion_publicada')
  assert.match(acceso, /progreso_unidades/)
  assert.match(acceso, /pu\.usuario_id = auth\.uid\(\)/)

  const listado = funcion('obtener_unidades_desbloqueadas')
  assert.match(listado, /from progreso_unidades pu/)
  assert.match(listado, /pu\.usuario_id = auth\.uid\(\)/)
})

test('el cliente respeta el desbloqueo individual', () => {
  assert.match(catalogo, /const unidadesDesbloqueadas = new Map\(\)/)
  assert.match(catalogo, /export function unidadHabilitada/)
  assert.match(catalogo, /unidadesDesbloqueadas\.has\(unidad\.id\)/)
  assert.match(catalogo, /supabase\.rpc\('obtener_unidades_desbloqueadas'\)/)
  assert.match(catalogo, /estado = 'bloqueada'/)
})

test('el XP se otorga una sola vez y los reintentos no lo duplican', () => {
  const texto = funcion('finalizar_intento')
  assert.match(texto, /if v_estado <> 'en_curso' then/)
  assert.match(texto, /if v_resumen\.aprobado and not v_ya_aprobada then/)
  assert.match(texto, /v_xp := 20 \+ v_resumen\.correctas \* 5/)
  assert.match(texto, /update perfiles set experiencia = experiencia \+ v_xp/)
  assert.match(texto, /update intentos set xp_ganado = v_xp/)
  assert.match(texto, /select i\.xp_ganado into v_xp/)
})

test('finalizar intento actualiza nivel, racha y evalua logros', () => {
  const texto = funcion('finalizar_intento')
  assert.match(texto, /nivel = nivel_por_experiencia\(experiencia \+ v_xp\)/)
  assert.match(texto, /racha_dias = case/)
  assert.match(texto, /ultima_actividad_en = current_date/)
  assert.match(texto, /perform evaluar_logros\(v_usuario\)/)
})

test('los logros tienen clave, criterio y recompensa pagada una sola vez', () => {
  const catalogoLogros = buscarSentencias(SQL, 'insert into logros ')
  assert.ok(catalogoLogros.length >= 1)
  const texto = normalizar(catalogoLogros[catalogoLogros.length - 1])
  assert.match(texto, /experiencia_recompensa/)
  assert.match(texto, /'primera_leccion'/)
  assert.match(texto, /'criterio'|clave, criterio|clave,/)
  assert.match(texto, /on conflict \(nombre\) do update/)

  const evaluar = funcion('evaluar_logros')
  assert.match(evaluar, /on conflict \(usuario_id, logro_id\) do nothing/)
  assert.match(evaluar, /if found and coalesce\(v_logro\.experiencia_recompensa, 0\) > 0 then/)
  assert.match(evaluar, /experiencia = experiencia \+ v_logro\.experiencia_recompensa/)
})

test('la pantalla de logros usa datos reales con progreso', () => {
  assert.match(logrosVista, /obtenerLogros/)
  assert.match(logrosVista, /logro\.actual/)
  assert.match(logrosVista, /logro\.objetivo/)
  assert.match(logrosVista, /logro\.obtenido/)
  assert.match(logrosVista, /class="k-progress"/)
  assert.match(catalogo, /export async function obtenerLogros/)
})

test('el perfil muestra los logros reales del usuario', () => {
  assert.match(perfilVista, /obtenerLogros/)
  assert.match(perfilVista, /logros\.value = todos\.filter\(\(logro\) => logro\.obtenido\)/)
})

test('las estadisticas salen de la RPC y no de valores simulados', () => {
  const texto = funcion('obtener_estadisticas')
  for (const campo of [
    'precision',
    'xp',
    'nivel',
    'racha',
    'actividades_realizadas',
    'lecciones_aprobadas',
    'unidades_completadas',
    'logros_obtenidos',
  ]) {
    assert.match(texto, new RegExp(`'${campo}'`), `falta ${campo}`)
  }
  assert.match(estadisticasVista, /obtenerEstadisticas/)
  assert.ok(!/>—</.test(estadisticasVista), 'no debe mostrar guiones como dato')
})

// ---------------------------------------------------------------------------
// 8. Pantallas pendientes y navegacion
// ---------------------------------------------------------------------------

test('el repaso usa el progreso real y arma rutas con slugs', () => {
  assert.match(revisionVista, /obtenerRevision/)
  assert.match(revisionVista, /aSlug\(fila\.curso_nombre\)/)
  assert.match(revisionVista, /name: 'leccion'/)
  const texto = funcion('obtener_revision')
  assert.match(texto, /from progreso_lecciones p/)
  assert.match(texto, /p\.usuario_id = auth\.uid\(\)/)
})

test('el diccionario es un glosario real con busqueda', () => {
  const tabla = ultimaSentencia('create table if not exists diccionario')
  assert.match(tabla, /termino/)
  assert.match(tabla, /definicion/)
  const textos = buscarSentencias(SQL, 'insert into diccionario')
  assert.ok(textos.length >= 1)
  assert.match(normalizar(textos[textos.length - 1]), /'variable'/)
  assert.match(diccionarioVista, /obtenerDiccionario/)
  assert.match(diccionarioVista, /v-model="busqueda"/)
})

test('amigos usa solicitudes reales sobre la tabla existente', () => {
  const enviar = funcion('enviar_solicitud_amistad')
  assert.match(enviar, /insert into amistades/)
  assert.match(enviar, /'pendiente'/)
  const responder = funcion('responder_solicitud_amistad')
  assert.match(responder, /estado = case when p_aceptar then 'aceptada' else 'rechazada' end/)
  assert.match(responder, /and amigo_id = auth\.uid\(\)/)

  assert.match(amigosVista, /obtenerAmistades/)
  assert.match(amigosVista, /responderSolicitudAmistad/)
  assert.match(buscarAmigosVista, /enviarSolicitudAmistad/)
  assert.match(catalogo, /export async function obtenerAmistades/)
})

test('las rutas de leccion y resultados usan el slug de la unidad', () => {
  for (const vista of [leccionVista, resultadosVista]) {
    assert.match(vista, /rutaUnidad/)
    assert.ok(!/courseId|unitId/.test(vista), 'no debe quedar el parametro viejo')
  }
  assert.match(catalogo, /export function rutaUnidad/)
  assert.match(catalogo, /params: \{ curso: aSlug\(curso\?\.nombre\), unidad: aSlug\(unidad\?\.nombre\) \}/)
})

test('el centro de ayuda tiene ruta propia y el enlace apunta ahi', () => {
  assert.match(router, /path: '\/ayuda'/)
  assert.match(router, /AyudaView\.vue/)
  assert.match(configuracionVista, /to="\/ayuda"/)
  assert.match(ayudaVista, /Centro de Ayuda/)
  assert.match(ayudaVista, /desbloqueo/)
})

test('no quedan textos con mojibake en las pantallas nuevas', () => {
  const archivos = {
    sql: SQL,
    ejecutor,
    catalogo,
    adminVista,
    adminServicio,
    logrosVista,
    estadisticasVista,
    revisionVista,
    diccionarioVista,
    amigosVista,
    buscarAmigosVista,
    ayudaVista,
  }
  for (const [nombre, texto] of Object.entries(archivos)) {
    assert.ok(!/Ã|Â|â€|ï¿½/.test(texto), `${nombre} tiene texto corrupto`)
  }
})

// ---------------------------------------------------------------------------
// 9. Rutas y pantallas conectadas
// ---------------------------------------------------------------------------

test('las pantallas pendientes tienen ruta y no hay botones muertos', () => {
  for (const ruta of ['/review', '/diccionario', '/logros', '/amigos', '/buscar-amigos']) {
    assert.match(router, new RegExp(`path: '${ruta.replace('/', '\\/')}'`), `falta la ruta ${ruta}`)
  }
  for (const vista of [logrosVista, estadisticasVista, revisionVista, diccionarioVista, amigosVista, buscarAmigosVista]) {
    assert.ok(!/TODO|Próximamente|proximamente/i.test(vista), 'no debe quedar un placeholder')
  }
})

// ---------------------------------------------------------------------------
// 10. Endurecimiento y cierre de pendientes (Etapa 9)
// ---------------------------------------------------------------------------

test('los blancos de completar_codigo exigen valor no vacio y claves unicas', () => {
  const validador = funcion('expotec_inconveniente_pregunta')
  assert.match(validador, /cada blanco debe aparecer en el codigo como \{clave\}/)
  assert.match(validador, /las claves de los blancos no pueden repetirse/)
  assert.match(validador, /btrim\(coalesce\(b ->> 'valor', ''\)\) = ''/)
})

test('el validador rechaza relacionar con pares huerfanos o duplicados', () => {
  const validador = funcion('expotec_inconveniente_pregunta')
  assert.match(validador, /los pares de la solucion deben unir elementos de las dos columnas/)
  assert.match(validador, /cada elemento solo puede estar en un par/)
})

test('el validador rechaza ordenar y bloques con elementos repetidos', () => {
  const validador = funcion('expotec_inconveniente_pregunta')
  assert.match(validador, /la solucion de orden no puede repetir elementos/)
  assert.match(validador, /la solucion de orden incluye elementos que no existen/)
  assert.match(validador, /la solucion no puede repetir bloques/)
  assert.match(validador, /los ids de los bloques no pueden repetirse/)
  assert.match(validador, /cada bloque necesita un id y un texto/)
})

test('el validador exige la opcion correcta perteneciente en salida y predecir', () => {
  const validador = funcion('expotec_inconveniente_pregunta')
  const salida = validador.indexOf("'salida_codigo', 'predecir'")
  assert.notEqual(salida, -1)
  const rama = validador.slice(salida)
  assert.match(rama, /opcion_correcta_id is null or not exists/)
})

test('el validador exige exactamente dos opciones en verdadero o falso', () => {
  const validador = funcion('expotec_inconveniente_pregunta')
  assert.match(validador, /verdadero o falso necesita exactamente dos opciones/)
})

test('el validador compila los patrones requeridos y prohibidos', () => {
  const validador = funcion('expotec_inconveniente_pregunta')
  assert.match(validador, /un patron de evaluacion no es una expresion regular valida/)
})

test('el servidor protege la edicion de actividades sin opciones con respuestas', () => {
  const guardar = funcion('expotec_admin_guardar_actividad')
  assert.match(guardar, /la actividad ya tiene respuestas de estudiantes/)
  // Al pasar de modalidad con opciones a una sin opciones se borran las huerfanas.
  assert.match(guardar, /delete from opciones where pregunta_id = v_id/)
})

test('el XP se serializa con bloqueo de la fila del perfil', () => {
  const finalizar = funcion('finalizar_intento')
  assert.match(finalizar, /from perfiles where id = v_usuario for update/)
})

test('el perfil no puede escribir experiencia ni nivel desde el cliente', () => {
  assert.match(SQL, /revoke update on public\.perfiles from authenticated, anon/)
  assert.match(SQL, /grant update \(nombre_usuario, nombre_visible, avatar_url\) on public\.perfiles to authenticated/)
})

test('los eventos solo admiten actividades en estado publicado', () => {
  const desafio = funcion('expotec_inconveniente_desafio')
  assert.ok(!/in \('publicado', 'borrador'\)/.test(desafio), 'el evento no debe admitir borradores')
  const configurar = funcion('expotec_admin_configurar_desafio')
  assert.ok(!/in \('publicado', 'borrador'\)/.test(configurar))
  assert.match(SQL, /estado_publicacion = 'publicado'/)
})

test('el centro de ayuda describe el cambio de contrasena y el invitado', () => {
  assert.match(ayudaVista, /¿Olvidaste tu contraseña\?/)
  assert.ok(!/estos datos se pierden/i.test(ayudaVista))
  assert.match(ayudaVista, /sesión anónima real/)
})

test('el perfil muestra los cursos iniciados reales y no el catalogo global', () => {
  assert.match(perfilVista, /CURSOS INICIADOS/)
  assert.match(perfilVista, /obtenerEstadisticas/)
  assert.ok(!/CURSOS ACTIVOS/.test(perfilVista), 'no debe prometer cursos activos sin medirlos')
})

test('buscar amigos carga la lista una sola vez y no en cada tecla', () => {
  assert.match(buscarAmigosVista, /asegurarPerfiles/)
  assert.match(buscarAmigosVista, /intentoPerfiles/)
  const watch = buscarAmigosVista.slice(buscarAmigosVista.indexOf('watch('))
  assert.ok(!/await obtenerPerfilesPublicos\(\)\s*$/.test(watch), 'la tecla no debe disparar la RPC directamente')
})

test('los resultados sobreviven a una recarga con el XP persistido', () => {
  assert.match(catalogo, /xpGanado: Number\(fila\.xp_ganado \?\? 0\)/)
  assert.match(resultadosVista, /obtenerHistorialLeccion\(dataLeccion\.id\)/)
})

test('el administrador debe indicar el codigo con errores en corregir codigo', () => {
  assert.match(adminVista, /Indicá el código con errores/)
  assert.match(adminVista, /indexOf\('='\)/)
})
