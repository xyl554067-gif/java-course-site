import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHashHistory(),
  scrollBehavior: () => ({ top: 0 }),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
      meta: { public: true, bare: true },
    },
    {
      path: '/',
      name: 'home',
      component: () => import('@/views/HomeView.vue'),
    },
    {
      path: '/course/:slug',
      name: 'course',
      component: () => import('@/views/CourseView.vue'),
    },
    {
      path: '/lesson/:slug',
      name: 'lesson',
      component: () => import('@/views/LessonView.vue'),
    },
    {
      path: '/search',
      name: 'search',
      component: () => import('@/views/SearchView.vue'),
    },
    {
      path: '/qa',
      name: 'qa',
      component: () => import('@/views/QaView.vue'),
    },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.public) {
    //已登录时访问登录页，直接回首页
    return auth.isLogged && to.name === 'login' ? { name: 'home' } : true
  }
  if (!auth.isLogged) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router