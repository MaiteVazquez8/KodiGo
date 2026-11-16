import { readFileSync } from 'node:fs'
const t = readFileSync('scripts/_migracion-robot.sql', 'utf8')
const count = (s, ch) => s.split(ch).length - 1
console.log('backticks:', count(t, '`'))
console.log('dollarBrace:', count(t, '${'))
console.log('backslashes:', count(t, '\\'))
console.log('chars:', t.length)
console.log('lines:', t.split('\n').length)
