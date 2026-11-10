import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { RUTA_SQL, leerSql, dividirSentencias, normalizar } from './validar-sql.mjs'
import {
  ANCHURA_JUEGO,
  ALTURA_JUEGO,
  cadenciaSpawn,
  crearEstadoJuego,
  multiplicadorVelocidad,
  nivelCantidad,
  nivelVelocidad,
  posicionEscudo,
  resultadoFinal,
  topeDestruidos,
} from '../src/services/coreDefender.js'

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

const aqui = dirname(fileURLToPath(import.meta.url))

function leer(rel) {
  return readFileSync(resolve(aqui, '..', rel), 'utf8')
}

/** Cuerpo de una funcion SQL (texto entre ella y el $$ primero $$ ;). */
function cuerpoDeFuncion(sql, nombre) {
  const re = new RegExp(
    'function\\s+' + nombre + '\\s*\\([^)]*\\)[\\s\\S]*?\\$\\$([\\s\\S]*?)\\$\\$\\s*;',
    'i',
  )
  const m = sql.match(re)
  return m ? m[1] : ''
}

/** Texto con comentarios y espaciado colapsados para asserts de substrings. */
function plano(texto) {
  return texto
    .replace(/--[^\n]*/g, ' ')
    .replace(/\s+/g, ' ')
    .toLowerCase()
}

const sql = leerSql()
const sentencias = dividirSentencias(sql)
const sentenciasPlanas = sentencias.map(normalizar)
const sqlPlano = plano(sql)

const RPCS_PARTICIPANTE = [
  'expotec_evento_activo',
  'expotec_alias_disponible',
  'expotec_iniciar_partida',
  'expotec_estado_partida',
  'expotec_responder',
  'expotec_iniciar_juego',
  'expotec_checkpoint_juego',
  'expotec_finalizar_juego',
  'expotec_abandonar',
  'expotec_obtener_soluciones',
  'expotec_mis_partidas',
  'expotec_resultado_propio',
  'expotec_ranking',
]

const RPCS_ALIAS_PROPIO = RPCS_PARTICIPANTE.filter((n) =>
  [
    'expotec_iniciar_partida',
    'expotec_estado_partida',
    'expotec_responder',
    'expotec_iniciar_juego',
    'expotec_checkpoint_juego',
    'expotec_finalizar_juego',
    'expotec_abandonar',
    'expotec_obtener_soluciones',
    'expotec_mis_partidas',
    'expotec_resultado_propio',
  ].includes(n),
)

const RPCS_ADMIN = [
  'expotec_admin_es_admin',
  'expotec_admin_guardar_curso',
  'expotec_admin_guardar_unidad',
  'expotec_admin_guardar_leccion',
  'expotec_admin_guardar_pregunta',
  'expotec_admin_crear_pregunta_completa',
  'expotec_admin_guardar_opcion',
  'expotec_admin_definir_solucion',
  'expotec_admin_cambiar_estado_contenido',
  'expotec_admin_crear_evento',
  'expotec_admin_actualizar_evento',
  'expotec_admin_cambiar_estado_evento',
  'expotec_admin_configurar_desafio',
  'expotec_admin_estadisticas_evento',
  'expotec_admin_resultados_evento',
]

const HELPERS_INTERNOS = [
  'expotec_guard_admin',
  'expotec_alias_normalizado',
  'expotec_alias_inconveniente',
  'expotec_evento_ventana_abierta',
  'expotec_desafio_congelado',
  'expotec_registrar_participante',
  'expotec_intentos_gastados',
  'expotec_progreso_partida_jsonb',
  'expotec_tope_destruidos',
  'expotec_inconveniente_pregunta',
  'expotec_inconveniente_leccion',
  'expotec_inconveniente_unidad',
  'expotec_inconveniente_curso',
  'expotec_inconveniente_desafio',
  'expotec_evento_editable',
]

const TABLAS_EXPOTEC = [
  'eventos',
  'desafios',
  'desafio_preguntas',
  'participantes',
  'partidas',
  'preguntas_asignadas',
  'respuestas',
  'sesiones_juego',
  'resultados_publicos',
  'admins',
]

// ---------------------------------------------------------------------------
// 1. Esquema: tablas, RLS y politicas de solo lectura
// ---------------------------------------------------------------------------

test('SQL: las 10 tablas del desafio existen con RLS habilitado', () => {
  for (const t of TABLAS_EXPOTEC) {
    assert.ok(
      sentenciasPlanas.some((s) => s.includes('create table if not exists expotec_' + t + ' ')),
      'falta la tabla expotec_' + t,
    )
    assert.ok(
      sentenciasPlanas.some(
        (s) =>
          s.startsWith('alter table expotec_' + t + ' ') &&
          s.includes('enable row level security'),
      ),
      'falta enable row level security en expotec_' + t,
    )
  }
})

test('SQL: todas las politicas sobre tablas expotec son de solo lectura', () => {
  const politicas = sentencias.filter(
    (s) => /create policy /.test(normalizar(s)) && / on expotec_/.test(normalizar(s)),
  )
  assert.ok(politicas.length >= 14, `menos de 14 politicas expotec: ${politicas.length}`)
  for (const p of politicas) {
    const n = normalizar(p)
    assert.ok(n.includes(' for select '), 'policy con escritura prohibida: ' + n)
  }
})

test('SQL: unicidad del alias case-insensitive por evento', () => {
  assert.ok(
    sqlPlano.includes('unique (evento_id, alias_normalizado)'),
    'el participante debe tener alias unico por evento',
  )
})

// ---------------------------------------------------------------------------
// 2. RPC: security definer, guard de identidad y admin via guard
// ---------------------------------------------------------------------------

test('SQL: las RPC de participante y admin son security definer', () => {
  for (const n of [...RPCS_PARTICIPANTE, ...RPCS_ADMIN]) {
    const definiciones = sentencias.filter((s) => {
      const d = normalizar(s)
      return d.startsWith('create or replace function') && d.includes('function ' + n + '(')
    })
    assert.ok(definiciones.length === 1, n + ' debe definirse exactamente una vez')
    for (const d of definiciones) {
      assert.ok(
        normalizar(d).includes('security definer'),
        n + ' debe ser security definer',
      )
    }
  }
})

test('SQL: las RPC de partida verifican la identidad con auth.uid()', () => {
  for (const n of RPCS_ALIAS_PROPIO) {
    const cuerpo = plano(cuerpoDeFuncion(sql, n))
    assert.ok(cuerpo.includes('auth.uid()'), n + ' debe verificar auth.uid()')
  }
})

test('SQL: las RPC de admin arrancan con el guard de administradores', () => {
  const guard = plano(cuerpoDeFuncion(sql, 'expotec_guard_admin'))
  assert.ok(guard.includes('es_administrador_expotec()'), 'el guard usa la identidad admin')
  assert.ok(guard.includes('auth.uid()') || guard.includes('es_administrador_expotec'))

  for (const n of RPCS_ADMIN) {
    if (n === 'expotec_admin_es_admin') continue
    const cuerpo = plano(cuerpoDeFuncion(sql, n))
    assert.ok(cuerpo.includes('expotec_guard_admin'), n + ' debe pasar por el guard admin')
  }
})

test('SQL: alta de administradores solo por SQL (insert a expotec_admins)', () => {
  // Documentado en un comentario del SQL: se busca sobre el texto crudo.
  assert.ok(
    sql.includes('insert into expotec_admins (usuario_id)'),
    'comentario de alta manual documentada en el SQL',
  )
})

// ---------------------------------------------------------------------------
// 3. Grants: revoke de publica + grant minimo por rol; helpers sin grant
// ---------------------------------------------------------------------------

test('SQL: cada RPC tiene revoke de PUBLIC y grant solo a los roles de la app', () => {
  for (const n of [...RPCS_PARTICIPANTE, ...RPCS_ADMIN]) {
    const revoca = sentenciasPlanas.some(
      (s) => s.startsWith('revoke all on function ' + n + '(') && s.includes('from public'),
    )
    assert.ok(revoca, 'falta revoke de public para ' + n)

    const otorga = sentencias.filter((s) => s.startsWith('grant execute on function ' + n + '('))
    assert.ok(otorga.length === 1, 'el grant de ' + n + ' debe aparecer una sola vez')
    const nGrant = normalizar(otorga[0])
    assert.ok(
      nGrant.includes('authenticated'),
      'el grant de ' + n + ' debe alcanzar a authenticated (anon tambien en las publicas)',
    )
  }
})

test('SQL: los helpers internos no son ejecutables desde el cliente', () => {
  for (const h of HELPERS_INTERNOS) {
    assert.ok(
      sentenciasPlanas.some(
        (s) => s.startsWith('revoke all on function ' + h + '(') && s.includes('from public'),
      ),
      'falta revoke para el helper ' + h,
    )
    const ntener = sentencias.some(
      (s) =>
        (normalizar(s).startsWith('grant execute') ||
          normalizar(s).startsWith('grant all')) &&
        normalizar(s).includes('on function ' + h + '('),
    )
    assert.ok(!ntener, 'el helper ' + h + ' no debe tener grant')
  }
})

// ---------------------------------------------------------------------------
// 4. Ranking: desempates oficiales y particion por evento
// ---------------------------------------------------------------------------

test('SQL: el ranking respeta el orden y solo por evento', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_ranking'))

  assert.ok(cuerpo.includes('puntaje_total desc'), 'primero puntaje total')
  assert.ok(cuerpo.includes('tiempo_cuestionario_seg asc'), 'segundo el tiempo del cuestionario')
  assert.ok(cuerpo.includes('nulls last'), 'los sin tiempo no bloquean el desempate')
  assert.ok(cuerpo.includes('puntaje_juego desc'), 'tercero los puntos del juego')
  assert.ok(cuerpo.includes('finalizado_at asc'), 'cuarto la fecha de envio')
  assert.ok(cuerpo.includes('evento_id = p_evento_id'), 'el ranking nunca mezcla eventos')
  assert.ok(cuerpo.includes('expotec_resultados_publicos'), 'solo resultados publicados')
})

test('SQL: los puestos del resultado propio usan el mismo desempate', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_resultado_propio'))
  assert.ok(cuerpo.includes('puntaje_total >')) // cuentas con puntaje mayor
  assert.ok(cuerpo.includes('puntaje_juego >'))
  assert.ok(cuerpo.includes('evento_id') && cuerpo.includes('v_partida.evento_id'))
})

// ---------------------------------------------------------------------------
// 5. Espejo de topes del juego (coreDefender.js vs SQL)
// ---------------------------------------------------------------------------

test('SQL: el techo de meteoritos coincide con el espejo del cliente', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_tope_destruidos'))
  assert.ok(cuerpo.includes('2.5 + 8'), 'formula duracion * 2.5 + 8')
  assert.ok(cuerpo.includes('2000'), 'techo absoluto de 2000')

  assert.equal(topeDestruidos(0), 8)
  assert.equal(topeDestruidos(9.9), 32)
  assert.equal(topeDestruidos(60), 158)
  assert.equal(topeDestruidos(900), 2000)
})

test('espejo: dificultad creciente cada 5/7 segundos y cap de cadencia', () => {
  assert.equal(nivelVelocidad(4.99), 0)
  assert.equal(nivelVelocidad(5), 1)
  assert.equal(nivelVelocidad(9.99), 1)
  assert.equal(nivelVelocidad(10), 2)
  assert.equal(nivelCantidad(6.99), 0)
  assert.equal(nivelCantidad(7.01), 1)

  const inicial = cadenciaSpawn(0)
  assert.ok(Math.abs(inicial - 0.75) < 1e-9)
  assert.ok(cadenciaSpawn(7.01) < inicial, 'la cantidad de meteoritos sube cada 7 segundos')
  assert.equal(cadenciaSpawn(120), 0.2, 'la cadencia tiene piso')

  const velocidad = multiplicadorVelocidad(10)
  assert.ok(Math.abs(velocidad - 1.3) < 1e-9, `nivel 2 de velocidad: quedo ${velocidad}`)
  assert.ok(multiplicadorVelocidad(0) === 1, 'arranca al 100% de velocidad')
})

test('espejo: el escudo orbita al nucleo sin clics', () => {
  const dimensiones = { ancho: ANCHURA_JUEGO, alto: ALTURA_JUEGO }
  assert.equal(ANCHURA_JUEGO, 640)
  assert.equal(ALTURA_JUEGO, 480)

  const borde = posicionEscudo({ x: 0, y: 241 }, dimensiones)
  const radio = Math.hypot(borde.x - 320, borde.y - 240)
  assert.ok(Math.abs(radio - 132) < 1e-6, 'orbita a 132 px, quedo ' + radio)

  const centro = posicionEscudo({ x: 320, y: 240 }, dimensiones)
  const radioCentro = Math.hypot(centro.x - 320, centro.y - 240)
  assert.ok(Math.abs(radioCentro - 132) < 1e-6)
})

test('espejo: resultadoFinal acota por los topes del servidor', () => {
  const estado = crearEstadoJuego(60, 3, () => 0.5)
  estado.destruidos = 500
  estado.tiempo = 60
  estado.impactos = 9
  const resumen = resultadoFinal(estado, 60)

  assert.equal(resumen.duracionSeg, 60)
  assert.equal(resumen.meteoritos, 158, 'capped por duracion girada: 60*2.5+8')
  assert.equal(resumen.impactos, 3, 'no mas impactos que vidas')
})

// ---------------------------------------------------------------------------
// 6. Validaciones del servidor al finalizar y cronometro
// ---------------------------------------------------------------------------

test('SQL: finalizar juego valida contra la sesion real', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_finalizar_juego'))

  assert.ok(cuerpo.includes('v_transcurrido + 2'), 'la duracion no supera el tiempo real')
  assert.ok(cuerpo.includes('expotec_tope_destruidos'), 'tope de destruidos aplicado')
  assert.ok(cuerpo.includes('least(p_impactos, v_vidas)'), 'impactos acotados por vidas')
  assert.ok(
    cuerpo.includes("estado = 'cerrada'"),
    'la sesion de juego queda cerrada',
  )
  assert.ok(
    cuerpo.includes('insert into expotec_resultados_publicos'),
    'publica el resultado oficial al cerrar',
  )
})

test('SQL: la partida de cuestionario se vence solo en el servidor', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_estado_partida'))

  assert.ok(cuerpo.includes('vencimiento_at'), 'lee el vencimiento del servidor')
  assert.ok(cuerpo.includes('servidor_at'), 'devuelve su reloj para sincronizar')
  assert.ok(cuerpo.includes("'vencida'"), 'marca vencida solo cuando ya paso la hora')
})

test('SQL: aleatorizacion de preguntas y opciones dentro del servidor', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_iniciar_partida'))

  assert.ok(cuerpo.includes('order by random()'), 'sortea preguntas con random()')
  assert.ok(
    cuerpo.includes('jsonb_agg(o.id order by random())'),
    'mezcla las opciones por partida',
  )
  assert.ok(
    cuerpo.includes('config_snapshot'),
    'congela la configuracion de la partida',
  )
})

// ---------------------------------------------------------------------------
// 7. Eventos: transiciones estrictas y desafio congelado
// ---------------------------------------------------------------------------

test('SQL: transiciones de evento estrictas borrador > programado > activo > cerrado', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_admin_cambiar_estado_evento'))

  assert.ok(
    cuerpo.includes("'borrador' and p_estado = 'programado'"),
    'borrador solo pasa a programado',
  )
  assert.ok(
    cuerpo.includes("'programado' and p_estado = 'activo'"),
    'programado solo pasa a activo',
  )
  assert.ok(
    cuerpo.includes("'activo' and p_estado = 'cerrado'"),
    'activo solo pasa a cerrado',
  )
  assert.ok(
    cuerpo.includes('el evento no puede pasar de'),
    'rechaza saltos regresivos',
  )
  assert.ok(
    cuerpo.includes('congelado_en = coalesce(congelado_en, now())'),
    'activar congela el desafio',
  )
  assert.ok(cuerpo.includes('expotec_inconveniente_desafio'), 'activar exige desafio completo')
})

test('SQL: el desafio configurado queda congelado con la primera partida', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_admin_configurar_desafio'))

  assert.ok(
    cuerpo.includes('congelado_en is not null or exists (select 1 from expotec_partidas'),
    'rechaza cambios con partidas',
  )
  assert.ok(
    cuerpo.includes('ya está en juego'),
    'devuelve el mensaje de desafio congelado',
  )
})

test('SQL: el sorteo del servidor sortea solo la cantidad configurada', () => {
  const cuerpo = plano(cuerpoDeFuncion(sql, 'expotec_iniciar_partida'))
  assert.ok(cuerpo.includes('limit v_cantidad'), 'recorta al azar la cantidad exigida')
})

// ---------------------------------------------------------------------------
// 8. Seeds completas y deterministas
// ---------------------------------------------------------------------------

test('seeds: evento, desafio y curso interno con ids deterministas', () => {
  assert.ok(sqlPlano.includes("uuid(md5('kodigo:evento:expotec-2026'))"), 'id del evento')
  assert.ok(sqlPlano.includes('expotécnica 2026'), 'nombre del evento sembrado')
  assert.ok(sqlPlano.includes("uuid(md5('kodigo:curso:expotec'))"), 'curso interno oculto')
  assert.ok(sqlPlano.includes("uuid(md5('kodigo:unidad:expotec:u01'))"), 'unidad del curso')
  assert.ok(sqlPlano.includes("uuid(md5('kodigo:leccion:expotec:l01'))"), 'clase del curso')
})

test('seeds: las 10 actividades del cuestionario con opciones y solucion', () => {
  // Los ids se componen en runtime con llaves de valores: se valida la
  // composicion y cada llave del banco sembrado.
  assert.ok(sql.includes("'kodigo:preg:expo:'"), 'prefijo de preguntas')
  assert.ok(sql.includes("'kodigo:opt:expo:'"), 'prefijo de opciones')
  assert.ok(sql.includes("'kodigo:sol:expo:'"), 'prefijo de soluciones')
  assert.ok(
    sql.includes('¿Qué devuelve 2 + "2" en JavaScript?'),
    'enunciado exacto de la primera actividad',
  )

  for (let i = 1; i <= 10; i += 1) {
    const par = String(i).padStart(2, '0')
    // El desafio incluye las 10 actividades en su orden de respaldo.
    assert.ok(sqlPlano.includes(`('q${par}', ${i - 1})`), `actividad q${par} del desafio`)
    for (let o = 0; o <= 3; o += 1) {
      assert.ok(sql.includes(`'q${par}:o${o}'`), `opcion ${o} de q${par}`)
    }
    // La solucion seed apunta a la opcion 0 con su explicacion.
    assert.ok(
      sql.includes(`'q${par}', 'q${par}:o0'`),
      `solucion de q${par} con la opcion correcta`,
    )
  }

  assert.ok(
    sqlPlano.includes('10, 100, 900, 180, 3, 1, true'),
    'parametros oficiales del desafio',
  )
})

// ---------------------------------------------------------------------------
// 9. Textos exactos del spec en las vistas
// ---------------------------------------------------------------------------

const vistaDesafio = leer('src/views/ExpotecnicaDesafioView.vue')
const vistaPresentacion = leer('src/views/ExpotecnicaView.vue')
const vistaRanking = leer('src/views/ExpotecnicaRankingView.vue')
const vistaAdmin = leer('src/views/AdminExpotecnicaView.vue')

test('vista desafio: textos de la consigna al pie de la letra', () => {
  assert.ok(vistaDesafio.includes('¿Seguro que querés terminar tu intento?'))
  assert.ok(vistaDesafio.includes('>Continuar<'))
  assert.ok(vistaDesafio.includes('>Terminar intento<'))
  assert.ok(vistaDesafio.includes('Iniciar cuestionario'))
  assert.ok(vistaDesafio.includes('Iniciar juego'))
  assert.ok(vistaDesafio.includes('Ver ranking'))
  assert.ok(vistaDesafio.includes('Volver al inicio'))
  assert.ok(vistaDesafio.includes('El nombre es obligatorio'), 'alias obligatorio')
})

test('vista desafio: sin respuestas correctas durante el cuestionario', () => {
  assert.ok(
    vistaDesafio.includes('recién al final del intento'),
    'la pantalla del cuestionario explica que nadie ve soluciones while',
  )
  // El solucionario solo es empaquetado por mostrarFinal.
  const llamadas = vistaDesafio.match(/obtenerSoluciones\(/g) || []
  assert.equal(llamadas.length, 1, 'obtenerSoluciones se llama una sola vez')
  const desdeColor = vistaDesafio.indexOf('async function mostrarFinal')
  const hastaColor = vistaDesafio.indexOf('fase.value = ', desdeColor)
  assert.ok(
    desdeColor !== -1 &&
      hastaColor > desdeColor &&
      vistaDesafio.slice(desdeColor, hastaColor).includes('obtenerSoluciones('),
    'la recarga de soluciones vive dentro de mostrarFinal',
  )
})

test('vista presentacion y ranking: accesos del spec', () => {
  assert.ok(vistaPresentacion.includes('Ver ranking'))
  assert.ok(vistaRanking.includes('Volver al inicio'))
  assert.ok(vistaAdmin.includes('Eventos') && vistaAdmin.includes('Resultados'))
})

// ---------------------------------------------------------------------------
// 10. Cronometro del servidor y reanudacion (frontend)
// ---------------------------------------------------------------------------

test('cronometro: restante derivado de vencimiento_at - servidor_at', () => {
  assert.ok(vistaDesafio.includes('data.partida.vencimientoAt'), 'toma el vencimiento')
  assert.ok(vistaDesafio.includes('data.servidorAt'), 'usa el reloj del servidor')
  assert.ok(
    vistaDesafio.includes('(new Date(data.partida.vencimientoAt) - new Date(data.servidorAt))'),
    'no usa el relojo local para el restante',
  )
})

test('reanudacion: partida guardada y alias resaltado en el ranking', () => {
  assert.ok(vistaDesafio.includes('kodigo.expotec.partida'), 'clave de reanudacion')
  assert.ok(vistaDesafio.includes('kodigo.expotec.ultimo-alias'), 'guarda el ultimo alias')
  assert.ok(
    vistaRanking.includes('kodigo.expotec.partida') ||
      vistaRanking.includes('kodigo.expotec.ultimo-alias'),
    'el ranking resalta al propio',
  )
  assert.ok(
    vistaDesafio.includes('beforeunload'),
    'avisa antes de cerrar la pestana en partida viva',
  )
})

// ---------------------------------------------------------------------------
// 11. Clientes: solo RPC y lecturas; sin escritura de tablas ni service_role
// ---------------------------------------------------------------------------

test('servicios expotec: sin escrituras directas ni claves de servicio', () => {
  const servicios = {
    participante: leer('src/services/expotecnica.js'),
    admin: leer('src/services/expotecnica-admin.js'),
  }

  for (const [nombre, texto] of Object.entries(servicios)) {
    assert.ok(!texto.includes('service_role'), `${nombre}: sin service_role`)
    assert.ok(!/\.(insert|update|delete|upsert)\(/.test(texto), `${nombre}: sin escrituras directas`)
    assert.ok(!texto.includes('disable row level security'), `${nombre}: no desactiva RLS`)
  }

  // El real time del ranking se Subscribe al evento concreto.
  const rankingTube = servicios.participante
  assert.ok(rankingTube.includes('expotec_resultados_publicos'), 'canal del ranking a la tabla publicada')
  assert.ok(rankingTube.includes('evento_id=eq.'), 'filtro por evento para no mezclar rankings')
})

test('timer realtime publicado en el SQL para postgres changes', () => {
  assert.ok(sqlPlano.includes('supabase_realtime'), 'publicacion realtime')
  assert.ok(
    sqlPlano.includes('expotec_resultados_publicos') &&
      plano(sql).includes('alter publication supabase_realtime add table public.expotec_resultados_publicos'),
    'la tabla del ranking entra en la publicacion',
  )
})

// ---------------------------------------------------------------------------
// 12. Integracion de rutas y navegacion
// ---------------------------------------------------------------------------

test('router: rutas del desafio, ranking y panel admin', () => {
  const router = leer('src/router/index.js')

  assert.ok(router.includes("path: '/expotecnica'"))
  assert.ok(router.includes("path: '/expotecnica/desafio'"))
  assert.ok(router.includes("path: '/expotecnica/ranking'"))
  assert.ok(router.includes("path: '/admin'"))
  assert.ok(
    router.includes("'expotecnica-desafio', 'admin'"),
    'el desafio y el panel exigen sesion',
  )
})

test('app: la barra de navegacion desaparece en desafio, ranking y panel', () => {
  const app = leer('src/App.vue')
  assert.ok(app.includes("'expotecnica-desafio'"))
  assert.ok(app.includes("'expotecnica-ranking'"))
  assert.ok(app.includes("'admin'"))
})

// ---------------------------------------------------------------------------
// 13. Motor puro del juego: reglas documentadas
// ---------------------------------------------------------------------------

test('coreDefender: estados y telemetria del motor puro', () => {
  const estado = crearEstadoJuego(180, 3, () => 0.25)
  assert.equal(estado.vidas, 3)
  assert.equal(estado.totalVidas, 3)
  assert.equal(estado.terminado, false)
  assert.ok(Array.isArray(estado.checkpoints))
  assert.ok(estado.proximoCheckpoint === 15, 'checkpoint cada 15 segundos')
})
