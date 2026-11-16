import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

const dir = 'src/views'
for (const f of readdirSync(dir).filter((n) => n.endsWith('.vue'))) {
  const t = readFileSync(join(dir, f), 'utf8')
  const hasLocalRef = /const estado = ref\(/.test(t)
  const hasAuthDestructure = /const \{ estado \} = usarAuth\(\)/.test(t) || /import \{[^}]*estado[^}]*\} from '@\/services\/auth'/.test(t)
  const tplUsesEstadoStr = /estado === '(cargando|error|listo|inexistente|vacio)'/.test(t)
  if (tplUsesEstadoStr) {
    console.log(`${f}: template-refs=${tplUsesEstadoStr} localRef=${hasLocalRef} authEstado=${hasAuthDestructure}`)
  }
}
