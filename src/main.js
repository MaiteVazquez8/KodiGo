import { Quasar } from 'quasar'
import '@quasar/extras/material-icons/material-icons.css'
import 'quasar/src/css/index.sass'
import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { inicializarSesion } from './services/auth'
import { registrarDeepLink } from './services/deepLink'
import './assets/styles/theme.css'

const app = createApp(App)

// Registrar antes del mount para que, si el APK llegó desde el deep link,
// el navegador redireccione al usuario a la pantalla de restablecer contraseña
// con los tokens que mandó Supabase en la URL.
registrarDeepLink()

app.use(Quasar)
app.use(router)

inicializarSesion()

app.mount('#q-app')
