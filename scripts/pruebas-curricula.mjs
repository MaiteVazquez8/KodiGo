import { test } from 'node:test'
import assert from 'node:assert/strict'
import { leerSql, dividirSentencias } from './validar-sql.mjs'

// La curricula del curso JavaScript se verifica de forma estatica: 10
// lecciones encadenadas y 53 actividades en total, con la dificultad
// decreciente segun la unidad: 4/4/4 (facil), 5/5/5/5 (media) y 7/7/7
// (dificil). El contenido nuevo vive dentro del unico SQL del proyecto.

const SQL = leerSql()
const sentencias = dividirSentencias(SQL)

const bloqueDe = (marcador) => {
  const textos = sentencias.filter((s) => s.includes(marcador))
  assert.ok(textos.length >= 1, `debe existir el bloque que inserta ${marcador}`)
  // Si hay varios, el ultimo es el insert real (los update previos tambien
  // mencionan los mismos ids).
  return textos[textos.length - 1]
}

const clavesPorLeccion = (claveRegex, cuerpo) => {
  const contenidos = [...cuerpo.matchAll(claveRegex)].map((m) => m)
  return contenidos
}

test('la curricula de JavaScript tiene exactamente 10 lecciones', () => {
  // El bloque nuevo de lecciones usa ids ::uuid (el seed original no).
  const bloqueLecciones = bloqueDe("'30000000-0000-0000-0000-000000000008'::uuid,")
  const ids = [
    ...bloqueLecciones.matchAll(/'30000000-0000-0000-0000-0000000000(\d\d)'::uuid,/g),
  ].map((m) => m[1])
  assert.deepEqual(ids, ['08', '09', '10'], 'se agregan l08, l09 y l10 a la unidad 3')
  assert.match(bloqueLecciones, /'20000000-0000-0000-0000-000000000003'::uuid/)

  const unidad = bloqueDe("unidad_id = '20000000-0000-0000-0000-000000000002'::uuid")
  const enUnidad2 = [
    ...unidad.matchAll(/'30000000-0000-0000-0000-0000000000(\d\d)'::uuid/g),
  ].map((m) => m[1])
  assert.equal(enUnidad2.length, 8, 'la unidad 2 cubre cuatro de las diez lecciones (l04 a l07, case + where)')

  const remapeo1 = bloqueDe("unidad_id = '20000000-0000-0000-0000-000000000001'::uuid")
  const enUnidad1 = [
    ...remapeo1.matchAll(/'30000000-0000-0000-0000-0000000000(\d\d)'::uuid/g),
  ].map((m) => m[1])
  assert.equal(enUnidad1.length, 6, 'dos lecciones se quedan y cuatro mas se reasignan a la unidad 1')

  const remapeo3 = bloqueDe("unidad_id = '20000000-0000-0000-0000-000000000003'::uuid")
  const enUnidad3 = [
    ...remapeo3.matchAll(/'30000000-0000-0000-0000-0000000000(\d\d)'::uuid/g),
  ].map((m) => m[1])
  assert.equal(enUnidad3.length, 6, 'la unidad 3 cubre las 3 ultimas lecciones (l08 a l10)')
})

test('las unidades del curso son 3 con desbloqueo secuencial', () => {
  assert.match(SQL, /update unidades\s+set nombre = 'Conceptos basicos',/)
  assert.match(SQL, /estado_publicacion = 'publicado'\s+where id = '20000000-0000-0000-0000-000000000001'::uuid/)
  assert.match(SQL, /update unidades\s+set nombre = 'Control de flujo',/)
  assert.match(SQL, /estado_publicacion = 'bloqueada'\s+where id = '20000000-0000-0000-0000-000000000002'::uuid/)

  const bloqueUnidad3 = sentencias.find(
    (s) => s.includes('insert into unidades') && s.includes('Estructuras y datos'),
  )
  assert.ok(bloqueUnidad3, 'debe existir el insert de la unidad 3')
  assert.match(bloqueUnidad3, /Estructuras y datos/)
  assert.match(bloqueUnidad3, /'bloqueada'/)
})

const CLAVES_POR_LECCION = {
  l01: 4,
  l02: 4,
  l03: 4,
  l04: 5,
  l05: 5,
  l06: 5,
  l07: 5,
  l08: 7,
  l09: 7,
  l10: 7,
}

const contar = (marcadorInsert, regex) => {
  const cuerpo = bloqueDe(marcadorInsert)
  return cuerpo
}

test('cada leccion tiene la cantidad de actividades que pide su dificultad', () => {
  // Solo cuentan los pares (clave, leccion) de la VALUES de preguntas:
  // opciones y soluciones usan otros marcadores (':oN' y 'kodigo:sol:').
  const cuerpos = [
    bloqueDe('ACTIVIDADES JS: unidad 1'),
    bloqueDe('ACTIVIDADES JS: unidad 2'),
    bloqueDe('ACTIVIDADES JS: unidad 3'),
  ]
    .join('\n')
    // Recorta desde el comentario hasta el cierre del insert para no
    // contar las claves de opciones/soluciones que vienen despues.
    .split('insert into opciones')
    .flatMap((parte) => parte.split('\n'))
    .filter((linea) => /^\s*\('js:l\d\d:/.test(linea))
    .map((linea) => linea.trim())

  const porLeccion = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0 }
  const leccionDeClave = /'js:l(\d\d):a\d+', (\d+),/

  const vistos = new Set()
  for (const linea of cuerpos) {
    const match = linea.match(leccionDeClave)
    if (!match) continue
    const clave = match[1]
    assert.ok(!vistos.has(linea), `linea repetida de pregunta: ${linea}`)
    vistos.add(linea)
    const numeroLeccion = Number(match[2])
    porLeccion[numeroLeccion] += 1
  }

  for (const leccionTexto of Object.keys(CLAVES_POR_LECCION)) {
    const numeroLeccion = Number(leccionTexto.slice(1))
    assert.equal(
      porLeccion[numeroLeccion],
      CLAVES_POR_LECCION[leccionTexto],
      `leccion ${numeroLeccion} debe tener ${CLAVES_POR_LECCION[leccionTexto]} actividades`,
    )
  }

  const total = Object.values(porLeccion).reduce((a, b) => a + b, 0)
  assert.equal(total, 53, 'JavaScript suma 53 actividades')
})

test('los seis tipos de actividad estan en la curricula', () => {
  const cuerpos = [
    bloqueDe('ACTIVIDADES JS: unidad 1'),
    bloqueDe('ACTIVIDADES JS: unidad 2'),
    bloqueDe('ACTIVIDADES JS: unidad 3'),
  ]
    .join('\n')

  const porTipo = {}
  for (const tipo of [
    'seleccion',
    'verdadero_falso',
    'completar_texto',
    'completar_codigo',
    'ordenar',
    'relacionar',
  ]) {
    const regex = new RegExp(`'${tipo}',`, 'g')
    const cuenta = (cuerpos.match(regex) ?? []).length - (tipo === 'seleccion' ? 0 : 0)
    porTipo[tipo] = cuenta
  }

  for (const tipo of Object.keys(porTipo)) {
    assert.ok(porTipo[tipo] >= 2, `${tipo} debe aparecer por lo menos 2 veces (hay ${porTipo[tipo]})`)
  }
})

test('los ordenar guardan la solucion en soluciones (no en datos)', () => {
  const solucionesOrdenar = bloqueDe('kodigo:sol:ordenar:')
  for (const clave of ['js:l02:a4', 'js:l04:a3', 'js:l05:a3', 'js:l06:a4', 'js:l07:a3', 'js:l08:a3', 'js:l09:a6', 'js:l10:a1']) {
    assert.match(solucionesOrdenar, new RegExp(`'${clave}'`), `falta la solucion de ${clave}`)
  }
  assert.match(solucionesOrdenar, /jsonb_agg\(o\.id order by o\.orden\)/)
})

test('los relacionar guardan sus pares en soluciones', () => {
  const solucionesRelacionar = sentencias.find(
    (s) => s.includes('kodigo:sol:relacionar:') && s.includes("'js:l03:a4'"),
  )
  assert.ok(solucionesRelacionar, 'debe existir el bloque de relacionar JS')
  for (const clave of ['js:l03:a4', 'js:l06:a5', 'js:l09:a5', 'js:l10:a4']) {
    assert.match(solucionesRelacionar, new RegExp(`'${clave}'`))
  }
})

test('el curso HTML llega con 10 lecciones y 53 actividades', () => {
  const bloqueCurso = sentencias.find(
    (s) => s.includes('insert into cursos') && s.includes('htmlLogo'),
  )
  assert.ok(bloqueCurso, 'debe existir el insert del curso HTML')
  assert.match(bloqueCurso, /'HTML'/)
  assert.match(bloqueCurso, /'htmlLogo'/)

  const bloqueLecciones = bloqueDe('Lecciones: 10 con orden 1..10')
  const claves = [...bloqueLecciones.matchAll(/kodigo:leccion:html:l(\d\d)/g)].map((m) => m[1])
  const unicos = new Set(claves)
  assert.equal(unicos.size, 10, 'se insertan las lecciones html:l01 a l10')

  const cuerpos = [
    bloqueDe('ACTIVIDADES HTML: unidad 1'),
    bloqueDe('ACTIVIDADES HTML: unidad 2'),
    bloqueDe('ACTIVIDADES HTML: unidad 3'),
  ]
    .join('\n')
    .split('insert into opciones')

  const porLeccion = CLAVES_POR_LECCION
  const conteo = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0 }
  // El numero de leccion sale de la clave (html:l04...) porque cada bloque
  // usa su propio CTE con numeracion local 1..N.
  const leccionDeClave = /'html:l(\d\d):a\d+',/

  for (const parte of cuerpos) {
    for (const linea of parte.split('\n')) {
      if (!/^\s*\('html:l\d\d:/.test(linea)) continue
      const match = linea.match(leccionDeClave)
      if (!match) continue
      conteo[Number(match[1])] += 1
    }
  }

  for (const leccionTexto of Object.keys(porLeccion)) {
    const numeroLeccion = Number(leccionTexto.slice(1))
    assert.equal(
      conteo[numeroLeccion],
      porLeccion[leccionTexto],
      `leccion HTML ${numeroLeccion} debe tener ${porLeccion[leccionTexto]} actividades`,
    )
  }
  const total = Object.values(conteo).reduce((a, b) => a + b, 0)
  assert.equal(total, 53, 'HTML suma 53 actividades')

  const tipos = ['seleccion', 'verdadero_falso', 'completar_texto', 'completar_codigo', 'ordenar', 'relacionar']
  const preguntasHtml = cuerpos[0]
  for (const tipo of tipos) {
    assert.ok(preguntasHtml.includes(`'${tipo}'`), `${tipo} debe vivir en la curricula HTML`)
  }
})

test('el contenido HTML guarda sus soluciones en soluciones', () => {
  const solucionesOrdenarHtml = bloqueDe('kodigo:sol:html:ordenar:')
  assert.match(solucionesOrdenarHtml, /jsonb_agg\(o\.id order by o\.orden\)/)
  for (const clave of ['html:l02:a4', 'html:l04:a2', 'html:l06:a2', 'html:l10:a1']) {
    assert.match(solucionesOrdenarHtml, new RegExp(`'${clave}'`), `falta la solucion de ${clave}`)
  }

  const solucionesTextoHtml = bloqueDe('kodigo:sol:html:texto:')
  for (const clave of ['html:l02:a2', 'html:l09:a1', 'html:l10:a5']) {
    assert.match(solucionesTextoHtml, new RegExp(`'${clave}'`), `falta la solucion de ${clave}`)
  }

  const solucionesCorrectaHtml = sentencias.find(
    (s) => s.includes('kodigo:sol:html:') && s.includes('join opciones o on o.texto = s.correcta'),
  )
  assert.ok(solucionesCorrectaHtml, 'debe existir el bloque de correctas del HTML')
  assert.match(solucionesCorrectaHtml, /join opciones o on o\.texto = s\.correcta/)
})
