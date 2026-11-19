// Capacitor App (deep link): permite que el APK abra con el enlace de
// "olvidé mi contraseña" que envía Supabase, ignorando el navegador del sistema.
// El esquema se registra en AndroidManifest.xml como <data android:scheme="kodigo" ...>.
import { App } from '@capacitor/app'

// Ruta interna en el webView (no en el navegador) que debe abrir el usuario
// cuando llega el correo de recuperación/verificación.
const RUTA_INTERNA = '/acceso/restablecer'

export function registrarDeepLink() {
  // En nativo, Capacitor reenviará cada appUrlOpen al listener; en web es no-op.
  return App.addListener('appUrlOpen', ({ url }) => {
    try {
      const parsed = new URL(url)
      if (parsed.protocol !== 'kodigo:') return

      // La ruta interna coincide con el host (restablecer | verificar). Si viene
      // un host desconocido, aterrizamos siempre en restablecer.
      const hash = parsed.hash // conserva #access_token=... & type=...
      const destino = `${window.location.origin}${RUTA_INTERNA}${hash}`
      window.location.href = destino
    } catch (error) {
      // No romper la app por un deep link inválido.
      console.warn('[Kodigo] deep link inválido:', error)
    }
  })
}
