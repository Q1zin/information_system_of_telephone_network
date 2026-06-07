import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes: RouteRecordRaw[] = [
  { path: '/login', name: 'login', component: () => import('@/views/LoginView.vue'), meta: { public: true } },
  {
    path: '/',
    component: () => import('@/layouts/MainLayout.vue'),
    children: [
      { path: '', redirect: { name: 'dashboard' } },
      { path: 'dashboard', name: 'dashboard', component: () => import('@/views/DashboardView.vue') },
      { path: 'crud/:resource', name: 'crud', component: () => import('@/views/CrudView.vue') },
      { path: 'analytics', name: 'analytics', component: () => import('@/views/AnalyticsView.vue'), meta: { perm: 'analytics:read' } },
      { path: 'raw-query', name: 'raw-query', component: () => import('@/views/RawQueryView.vue'), meta: { perm: 'raw_query:run' } },
      { path: 'settings', name: 'settings', component: () => import('@/views/SettingsView.vue'), meta: { perm: 'billing_settings:read' } },
      { path: 'admin/users', name: 'admin-users', component: () => import('@/views/admin/UsersView.vue'), meta: { perm: 'user:read' } },
      { path: 'admin/roles', name: 'admin-roles', component: () => import('@/views/admin/RolesView.vue'), meta: { perm: 'role:read' } },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: { name: 'dashboard' } },
]

const router = createRouter({ history: createWebHistory(), routes })

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (!auth.loaded) await auth.fetchMe()

  if (to.meta.public) {
    return auth.isAuthenticated && to.name === 'login' ? { name: 'dashboard' } : true
  }
  if (!auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  const perm = to.meta.perm as string | undefined
  if (perm && !auth.can(perm)) {
    return { name: 'dashboard' }
  }
  return true
})

export default router
