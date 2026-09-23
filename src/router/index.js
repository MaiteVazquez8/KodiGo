import { createRouter, createWebHistory } from 'vue-router'

const rutas = [
  {
    path: '/',
    name: 'inicio',
    component: () => import('@/views/InicioView.vue'),
  },
  {
    path: '/courses',
    name: 'cursos',
    component: () => import('@/views/CursosView.vue'),
  },
  {
    path: '/courses/:courseId',
    name: 'curso',
    component: () => import('@/views/CursoView.vue'),
  },
  {
    path: '/courses/:courseId/unit/:unitId',
    name: 'unidad',
    component: () => import('@/views/UnidadView.vue'),
  },
  {
    path: '/courses/:courseId/unit/:unitId/lesson/:lessonId',
    name: 'leccion',
    component: () => import('@/views/LeccionView.vue'),
  },
  {
    path: '/courses/:courseId/unit/:unitId/lesson/:lessonId/activity/:activityId',
    name: 'actividad-leccion',
    component: () => import('@/views/ActividadView.vue'),
  },
  {
    path: '/courses/:courseId/unit/:unitId/lesson/:lessonId/results',
    name: 'resultados-leccion',
    component: () => import('@/views/ResultadosView.vue'),
  },
  {
    path: '/activity/:activityId',
    name: 'actividad',
    component: () => import('@/views/ActividadView.vue'),
  },
  {
    path: '/lesson/:lessonId',
    name: 'leccion-legada',
    component: () => import('@/views/LeccionView.vue'),
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

export default enrutador
