import { test } from 'node:test'
import assert from 'node:assert/strict'
import { leerSql, dividirSentencias } from './validar-sql.mjs'

// Curso "Pensamiento Logico": curricula de tipo robot. Las pruebas estaticas
// verifican la presencia del seed y la estructura de los tableros; los tableros
// se resuelven ademas con una busqueda en amplitud como prueba de solvabilidad.
const SQL = leerSql()
const sentencias = dividirSentencias(SQL)

// ---------------------------------------------------------------------------
// 1. Presencia del seed en el unico SQL del proyecto
// ---------------------------------------------------------------------------

test('el seed del curso Pensamiento Logico agrega el curso y sus unidades', () => {
  assert.match(SQL, /insert into cursos \(id, nombre, descripcion/i)
  assert.match(SQL, /10000000-0000-0000-0000-000000000003/)
  assert.match(SQL, /Pensamiento Lógico/)
  assert.match(SQL, /40000000-0000-0000-0000-000000000001/)
  assert.match(SQL, /40000000-0000-0000-0000-000000000002/)
  assert.match(SQL, /40000000-0000-0000-0000-000000000003/)
})

test('las 15 lecciones del curso estan sembradas con su estado', () => {
  const ids = Array.from({ length: 15 }, (_, i) => `50000000-0000-0000-0000-00000000000${(i + 1).toString(16)}`)
  for (const id of ids) {
    assert.ok(
      sentencias.some((s) => s.includes(id) && s.includes('insert into lecciones')),
      `falta la leccion ${id}`,
    )
  }
  // Unidad 1 publicada, unidades 2 y 3 bloqueadas.
  const bloqueU2 = sentencias.find((s) => s.includes("'40000000-0000-0000-0000-000000000002'") && s.includes('unidades'))
  assert.match(bloqueU2, /bloqueada/)
  const bloqueU3 = sentencias.find((s) => s.includes("'40000000-0000-0000-0000-000000000003'") && s.includes('unidades'))
  assert.match(bloqueU3, /bloqueada/)
})

test('hay exactamente 15 actividades de tipo robot, una por leccion', () => {
  const preguntasRobot = sentencias.filter((s) => /insert into preguntas/i.test(s) && s.includes("'robot'"))
  assert.equal(preguntasRobot.length, 15)
  const solucionesRobot = preguntasRobot.map((s) => s.match(/on conflict \(id\)/) ? s : null)
  assert.equal(solucionesRobot.filter(Boolean).length, 15)
})

// ---------------------------------------------------------------------------
// 2. Validacion en el lado servidor
// ---------------------------------------------------------------------------

test('comprobar_respuesta tiene una rama para robot con expansion de bucles', () => {
  assert.match(SQL, /elsif v_tipo = 'robot' then/)
  assert.match(SQL, /v_expanded/)
  assert.match(SQL, /'repetir'/)
})

test('el constraint preguntas_tipo_check incluye robot', () => {
  const bloqueETAPA8 = sentencias.find(
    (s) => s.includes('add constraint preguntas_tipo_check') && s.includes("'robot'"),
  )
  assert.ok(bloqueETAPA8, 'la restriccion definitiva debe incluir robot')
})

test('el panel administrativo valida la modalidad robot', () => {
  assert.match(SQL, /elsif v_pregunta\.tipo = 'robot' then/)
  assert.match(SQL, /La actividad robot necesita el tablero/)
})

// ---------------------------------------------------------------------------
// 3. Solvabilidad de los 15 tableros (BFS sobre el estado del robot)
// ---------------------------------------------------------------------------

const extraerDatos = () => {
  const preguntas = []
  const re = /insert into preguntas \(id, leccion_id, enunciado, tipo, datos, orden, estado_publicacion\)\s+values \('([0-9a-f-]+)', '([0-9a-f-]+)', '(?:[^']|'')+', 'robot', '((?:[^']|'')*)'::jsonb/g
  let m
  while ((m = re.exec(SQL)) !== null) {
    preguntas.push({
      id: m[1],
      leccion: m[2],
      datos: JSON.parse(m[3].replace(/''/g, "'")),
    })
  }
  return preguntas
}

const DIRS = [[-1, 0], [0, 1], [1, 0], [0, -1]]

const resolver = (p) => {
  const { inicio, rumbo, meta, muros } = p.datos.tablero
  const permitidas = p.datos.instrucciones
  const max = Math.min(Number(p.datos.maxInstrucciones ?? 30), 30)
  const bloqueados = new Set(muros ?? [])
  const visitados = new Set()
  const cola = [[inicio, rumbo, []]]
  while (cola.length) {
    const [pos, rd, seq] = cola.shift()
    if (pos === meta) return seq
    if (seq.length >= max) continue
    const clave = `${pos}:${rd}:${seq.length}`
    if (visitados.has(clave)) continue
    visitados.add(clave)
    for (const inst of permitidas) {
      let np = pos, nr = rd
      if (inst === 'izquierda') nr = (rd + 3) % 4
      else if (inst === 'derecha') nr = (rd + 1) % 4
      else if (inst === 'avanzar') {
        const fila = Math.floor(pos / 5) + DIRS[rd][0]
        const col = (pos % 5) + DIRS[rd][1]
        if (fila < 0 || fila > 4 || col < 0 || col > 4) continue
        np = fila * 5 + col
        if (bloqueados.has(np)) continue
      } else if (inst === 'repetir') continue
      cola.push([np, nr, [...seq, inst]])
    }
    // El bucle "repetir X" equivale a tres ejecuciones de X como una sola ficha.
    if (permitidas.includes('repetir')) {
      for (const inst of permitidas) {
        if (inst === 'repetir') continue
        let np = pos, nr = rd, ok = true
        for (let k = 0; k < 3 && ok; k += 1) {
          if (inst === 'izquierda') nr = (nr + 3) % 4
          else if (inst === 'derecha') nr = (nr + 1) % 4
          else if (inst === 'avanzar') {
            const fila = Math.floor(np / 5) + DIRS[nr][0]
            const col = (np % 5) + DIRS[nr][1]
            if (fila < 0 || fila > 4 || col < 0 || col > 4) { ok = false; break }
            const sig = fila * 5 + col
            if (bloqueados.has(sig)) { ok = false; break }
            np = sig
          } else ok = false
        }
        if (ok && seq.length + 2 <= max) cola.push([np, nr, [...seq, 'repetir', inst]])
      }
    }
  }
  return null
}

test('los 15 tableros de robot son resolubles dentro de su limite de instrucciones', () => {
  const preguntas = extraerDatos()
  assert.equal(preguntas.length, 15, 'deben encontrarse las 15 actividades robot en el seed')
  for (const [i, p] of preguntas.entries()) {
    const sol = resolver(p)
    assert.ok(sol, `el tablero de la leccion ${i + 1} (${p.id.slice(0, 8)}) no tiene solucion`)
    assert.ok(sol.length <= Math.min(Number(p.datos.maxInstrucciones ?? 30), 30))
    assert.ok(!sol.includes('undefined'))
  }
})

test('las actividades robot referencian las lecciones del curso', () => {
  const preguntas = extraerDatos()
  const leccionesSql = sentencias.filter((s) => /insert into lecciones/i.test(s) && s.includes('50000000'))
  const ids = new Set(leccionesSql.map((s) => s.match(/'50000000-[0-9a-f-]+'/)?.[0]).filter(Boolean))
  for (const p of preguntas) {
    assert.ok(ids.has(`'${p.leccion}'`), `la actividad ${p.id.slice(0, 8)} apunta a una leccion sembrada`)
  }
})
