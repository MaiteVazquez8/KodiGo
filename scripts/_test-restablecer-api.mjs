// Script de prueba: crea una cuenta descartable, envía el correo de
// recuperación con redirect a kodigo://restablecer y verifica la
// respuesta de Supabase. No confirma el correo recibido (eso requiere un
// inbox real), pero sí valida que el backend acepta la petición y que el
// deep link está whitelisted.
//
// Uso: node scripts/_test-restablecer-api.mjs <correo>
import { readFileSync, existsSync } from 'node:fs'
import { argv } from 'node:process'

if (!process.env.VITE_SUPABASE_URL && existsSync('.env')) {
  const env = readFileSync('.env', 'utf8')
  const mUrl = env.match(/VITE_SUPABASE_URL=(\S+)/)
  const mKey = env.match(/VITE_SUPABASE_PUBLISHABLE_KEY=(\S+)/)
  if (mUrl && mKey) {
    process.env.VITE_SUPABASE_URL = mUrl[1]
    process.env.VITE_SUPABASE_ANON_KEY = mKey[1]
  }
}

const SUPABASE_URL = process.env.VITE_SUPABASE_URL
const SUPABASE_KEY = process.env.VITE_SUPABASE_ANON_KEY

const correo = argv[2]
if (!correo || !/^[^@\s]+@[^@\s]+$/.test(correo)) {
  console.error('Uso: node scripts/_test-restablecer-api.mjs <correo>')
  process.exit(1)
}

const ts = Date.now().toString(36)
const REDIRECT = 'kodigo://restablecer'
const tempPassword = `Kodigo-Test-${ts}-ABCD!`

console.log('== Kodigo :: test de reset vía Supabase ==\n')
console.log('Correo de prueba:', correo)
console.log('Redirect:        ', REDIRECT)
console.log()

const { createClient } = await import('@supabase/supabase-js')
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

console.log('1/3  signUp de cuenta temporal...')
const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
  email: correo,
  password: tempPassword,
})
if (signUpError) { console.error('  FALLO signUp:', signUpError.message); process.exit(1) }
console.log('  OK — id:', signUpData?.user?.id ?? '(revisá el dashboard: puede estar con Confirm expired)')

console.log('\n2/3  resetPasswordForEmail con redirect kodigo://restablecer')
const { error: resetError } = await supabase.auth.resetPasswordForEmail(correo, {
  redirectTo: REDIRECT,
})
if (resetError) {
  console.error('  FALLO reset:', resetError.message)
  console.error('  Causa probable: kodigo://restablecer no está en Redirect URLs (Auth → URL Configuration).')
  process.exit(1)
}
console.log('  OK — Supabase aceptó la petición.')

console.log('\n3/3  Verificación básica vía getSession')
const { data: sessionData, error: sessionError } = await supabase.auth.getSession()
console.log('  getSession:',
  sessionError ? `error: ${sessionError.message}` : JSON.stringify({ user: sessionData?.session?.user?.id }))

console.log('\nListo. Siguiente paso: abrí el APK instalado en tu teléfono y comprobá')
console.log('que el link que llegó al correo abre la pantalla "Restablecer contraseña".\n')
console.log('También podés probar el deep link manualmente con adb:')
console.log('  adb shell am start -a android.intent.action.VIEW -d "kodigo://restablecer" -n com.kodigo.app/.MainActivity')

