import { createRouter, createWebHistory } from 'vue-router'
import { esInvitado, inicializarSesion } from '@/services/auth'
import { estado } from '@/services/auth'

const rutas = [
  {
    // Primera pantalla del mock: bienvenida con acceso/registro.
    path: '/',
    name: 'bienvenida',
    component: () => import('@/views/AccesoView.vue'),
  },
  {
    // Portal KODIGO ("Tu portal de aprendizaje gamificado").
    path: '/learn',
    name: 'learn',
    component: () => import('@/views/InicioView.vue'),
  },
  {
    path: '/courses',
    name: 'cursos',
    component: () => import('@/views/CursosView.vue'),
  },
  {
    path: '/review',
    name: 'review',
    component: () => import('@/views/ReviewView.vue'),
  },
  {
    path: '/diccionario',
    name: 'diccionario',
    component: () => import('@/views/DiccionarioView.vue'),
  },
  {
    path: '/mas',
    name: 'mas',
    component: () => import('@/views/MasView.vue'),
  },
  {
    path: '/logros',
    name: 'logros',
    component: () => import('@/views/LogrosView.vue'),
  },
  {
    path: '/estadisticas',
    name: 'estadisticas',
    component: () => import('@/views/EstadisticasView.vue'),
  },
  {
    path: '/amigos',
    name: 'amigos',
    component: () => import('@/views/AmigosView.vue'),
  },
  {
    path: '/buscar-amigos',
    name: 'buscar-amigos',
    component: () => import('@/views/BuscarAmigosView.vue'),
  },
  {
    path: '/liga',
    name: 'liga',
    component: () => import('@/views/LigaView.vue'),
  },
  {
    path: '/courses/:curso',
    name: 'curso',
    component: () => import('@/views/CursoView.vue'),
  },
  {
    path: '/courses/:curso/unit/:unidad',
    name: 'unidad',
    component: () => import('@/views/UnidadView.vue'),
  },
  {
    path: '/courses/:curso/unit/:unidad/lesson/:leccion',
    name: 'leccion',
    component: () => import('@/views/LeccionView.vue'),
  },
  {
    path: '/courses/:curso/unit/:unidad/lesson/:leccion/activity/:pregunta',
    name: 'actividad-leccion',
    component: () => import('@/views/ActividadView.vue'),
  },
  {
    path: '/courses/:curso/unit/:unidad/lesson/:leccion/results',
    name: 'resultados-leccion',
    component: () => import('@/views/ResultadosView.vue'),
  },
  // Rutas legadas (con IDs). Siguen resolviendose y redirigen a la canonica.
  {
    path: '/activity/:activityId',
    name: 'actividad',
    component: () => import('@/views/ActividadView.vue'),
  },
  {
    path: '/lesson/:leccion',
    name: 'leccion-legada',
    component: () => import('@/views/LeccionView.vue'),
  },
  {
    path: '/acceso',
    name: 'acceso',
    component: () => import('@/views/AccesoView.vue'),
  },
  {
    path: '/acceso/registro',
    name: 'registro',
    component: () => import('@/views/RegistroView.vue'),
  },
  {
    path: '/acceso/ingreso',
    name: 'ingreso',
    component: () => import('@/views/LoginView.vue'),
  },
  {
    path: '/acceso/recuperar',
    name: 'recuperar',
    component: () => import('@/views/RecuperarView.vue'),
  },
  {
    path: '/acceso/restablecer',
    name: 'restablecer',
    component: () => import('@/views/RestablecerView.vue'),
  },
  {
    path: '/perfil',
    name: 'perfil',
    component: () => import('@/views/PerfilView.vue'),
  },
  {
    path: '/configuracion',
    name: 'configuracion',
    component: () => import('@/views/ConfiguracionView.vue'),
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/',
  },
]

const enrutador = createRouter({
  history: createWebHistory(),
  routes: rutas,
  scrollBehavior: () => ({ top: 0 }),
})

const rutasAcceso = ['bienvenida', 'acceso', 'registro', 'ingreso', 'recuperar', 'restablecer']
const rutasQueRequierenSesion = ['perfil', 'configuracion']

enrutador.beforeEach(async (destino) => {
  // Se espera a conocer el estado real antes de redirigir: sin esto la app
  // podria expulsar a un usuario con sesion valida durante el arranque.
  await inicializarSesion()

  const haySesion = Boolean(estado.usuario)
  const esCuenta = haySesion && !esInvitado(estado.usuario)

  // Con una cuenta activa no tiene sentido mostrar las pantallas de acceso.
  if (rutasAcceso.includes(destino.name) && esCuenta) {
    return { name: 'perfil' }
  }

  // El contenido publico de Stage 3 sigue abierto sin sesion.
  if (rutasQueRequierenSesion.includes(destino.name) && !haySesion) {
    return { name: 'acceso' }
  }

  return true
})

export default enrutador
