import { Quasar } from 'quasar'
import '@quasar/extras/material-icons/material-icons.css'
import 'quasar/src/css/index.sass'
import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { inicializarSesion } from './services/auth'
import './assets/styles/theme.css'

const app = createApp(App)

app.use(Quasar)
app.use(router)

inicializarSesion()

app.mount('#q-app')
