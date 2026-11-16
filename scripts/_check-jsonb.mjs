import { readFileSync } from 'node:fs'

const t = readFileSync('scripts/_migracion-robot.sql', 'utf8')
// Extrae cada literal '...'::jsonb (plantilla server) y valida JSON.
const re = /'((?:[^']|'')*)'::jsonb/g
let m, i = 0, bad = 0
while ((m = re.exec(t))) {
  i += 1
  const raw = m[1].replace(/''/g, "'")
  try {
    JSON.parse(raw)
  } catch (e) {
    bad += 1
    console.log(`Inválido #${i} (offset ${m.index}): ${e.message}`)
    console.log('  →', raw.slice(0, 220))
  }
}
console.log(`literales jsonb: ${i}, inválidos: ${bad}`)
