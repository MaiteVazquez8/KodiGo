import { createRouter, createWebHistory } from 'vue-router'

const routes = [
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
  {
    path: '/:pathMatch(.*)*',
    redirect: '/',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

export default router
