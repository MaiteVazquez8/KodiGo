import { readFileSync } from 'node:fs'
const t = readFileSync('scripts/_migracion-robot.sql', 'utf8')
const i = t.indexOf('Como no hay')
const start = t.lastIndexOf("'robot', '", i) + "'robot', '".length
const end = t.indexOf("'::jsonb", i)
const s = t.slice(start, end)
console.log('raw literal:', JSON.stringify(s))
try {
  JSON.parse(s)
  console.log('PARSE OK')
} catch (e) {
  console.log('PARSE FAIL:', e.message)
}
