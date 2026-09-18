import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '@/supabase'

const router = createRouter({
  history: createWebHistory(),
  scrollBehavior: () => ({ top: 0 }),
  routes: [
    {
      path: '/welcome',
      name: 'welcome',
      component: () => import('@/views/AuthView.vue'),
      meta: { mode: 'welcome' },
  },
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/AuthView.vue'),
    meta: { mode: 'login' },
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('@/views/AuthView.vue'),
    meta: { mode: 'register' },
  },
  {
    path: '/language',
    name: 'language',
    component: () => import('@/views/AuthView.vue'),
    meta: { mode: 'language' },
  },
  {
    path: '/',
    name: 'home',
    component: () => import('@/views/HomeView.vue'),
  },
  {
    path: '/courses',
    name: 'courses',
    component: () => import('@/views/CoursesView.vue'),
  },
  {
    path: '/courses/:courseId',
    name: 'course',
    component: () => import('@/views/CourseView.vue'),
  },
  {
    path: '/courses/:courseId/unit/:unitId',
    name: 'unit',
    component: () => import('@/views/UnitView.vue'),
  },
  {
    path: '/courses/:courseId/unit/:unitId/lesson/:lessonId',
    name: 'lesson',
    component: () => import('@/views/LessonView.vue'),
  },
  {
    path: '/activity/:activityId',
    name: 'activity',
    component: () => import('@/views/ActivityView.vue'),
  },
  ...['ranking', 'friends', 'profile', 'achievements', 'settings'].map((name) => ({
    path: `/${name}`,
    name,
    component: () => import('@/views/CommunityView.vue'),
  })),
  {
    path: '/:pathMatch(.*)*',
    redirect: '/',
  },
]})

router.beforeEach(async (to, from, next) => {
  const { data: { session } } = await supabase.auth.getSession()

  if (!session && !['welcome', 'login', 'register', 'language'].includes(to.name)) {
    next({ name: 'welcome' })
  } else if (session && ['welcome', 'login', 'register'].includes(to.name)) {
    next({ name: 'home' })
  } else {
    next()
  }
})

export default router