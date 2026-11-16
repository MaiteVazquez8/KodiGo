// Verifica que las 14 actividades de tipo robot sean resolubles con BFS.
import { readFileSync } from 'node:fs'

const preguntas = JSON.parse(readFileSync('scripts/_robot-levels.json', 'utf8'))
const DIRS = [[-1, 0], [0, 1], [1, 0], [0, -1]]

function expandir(tokens) {
  const out = []
  let i = 0
  while (i < tokens.length) {
    if (tokens[i] === 'repetir') {
      const next = tokens[i + 1]
      if (!next) break
      for (let k = 0; k < 3; k += 1) out.push(next)
      i += 2
    } else {
      out.push(tokens[i])
      i += 1
    }
  }
  return out
}

function resolver(p) {
  const { inicio, rumbo, meta, muros } = p.datos.tablero
  const permitidas = p.datos.instrucciones
  const max = Math.min(Number(p.datos.maxInstrucciones ?? 30), 30)
  const murosSet = new Set(muros)
  // BFS sobre (pos, rumbo, pasos) — verifica distancia mínima en instrucciones "expandidas".
  const visitado = new Set()
  const cola = [[inicio, rumbo, []]]
  while (cola.length) {
    const [pos, rd, seq] = cola.shift()
    if (pos === meta) return seq
    if (seq.length >= max) continue
    const clave = `${pos}:${rd}:${seq.length}`
    if (visitado.has(clave)) continue
    visitado.add(clave)
    for (const inst of permitidas) {
      let np = pos, nr = rd
      if (inst === 'izquierda') nr = (rd + 3) % 4
      else if (inst === 'derecha') nr = (rd + 1) % 4
      else if (inst === 'avanzar') {
        const fila = Math.floor(pos / 5) + DIRS[rd][0]
        const col = (pos % 5) + DIRS[rd][1]
        if (fila < 0 || fila > 4 || col < 0 || col > 4) continue
        const sig = fila * 5 + col
        if (murosSet.has(sig)) continue
        np = sig
      } else if (inst === 'repetir') {
        continue // se expande abajo: repetir sólo precede a otra instrucción
      }
      cola.push([np, nr, [...seq, inst]])
    }
    // Simular "repetir X" como un token que actúa 3 veces sobre el estado actual.
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
            if (murosSet.has(sig)) { ok = false; break }
            np = sig
          } else { ok = false }
        }
        if (ok && seq.length + 2 <= max) cola.push([np, nr, [...seq, 'repetir', inst]])
      }
    }
  }
  return null
}

let ok = 0, fallidas = []
preguntas.forEach((p, i) => {
  const sol = resolver(p)
  if (sol) {
    ok += 1
    console.log(`OK  Nivel ${i + 1} (${sol.length} instrucciones): ${sol.join(' ')}`)
  } else {
    fallidas.push(i + 1)
    console.log(`FALLA Nivel ${i + 1}: sin solución`)
  }
})
console.log(`\nResueltas: ${ok}/${preguntas.length}`)
if (fallidas.length) process.exit(1)

// Validación adicional: la expansión de tokens del juego coincide con la simulación.
preguntas.forEach((p, i) => {
  const sol = resolver(p)
  if (!sol) return
  const expandido = expandir(sol)
  let pos = p.datos.tablero.inicio, rd = p.datos.tablero.rumbo
  const murosSet = new Set(p.datos.tablero.muros)
  for (const inst of expandido) {
    if (inst === 'izquierda') rd = (rd + 3) % 4
    else if (inst === 'derecha') rd = (rd + 1) % 4
    else {
      const fila = Math.floor(pos / 5) + DIRS[rd][0]
      const col = (pos % 5) + DIRS[rd][1]
      pos = fila * 5 + col
    }
  }
  const llegadaOk = pos === p.datos.tablero.meta
  console.log(`SimNivel ${i + 1}: expandidas ${expandido.length} instrucciones -> pos ${pos} (meta ${p.datos.tablero.meta}) ${llegadaOk ? 'OK' : 'FALLA'}`)
})
