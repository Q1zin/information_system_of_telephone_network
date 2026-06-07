import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useCustomerStore } from '@/stores/customer'

const routes: RouteRecordRaw[] = [
  { path: '/', name: 'landing', component: () => import('@/views/LandingView.vue'), meta: { public: true } },
  { path: '/staff/login', name: 'staff-login', component: () => import('@/views/LoginView.vue'), meta: { public: true } },
  { path: '/portal/login', name: 'portal-login', component: () => import('@/views/portal/PortalLoginView.vue'), meta: { public: true } },

  // ---- operator / admin area ----
  {
    path: '/app',
    component: () => import('@/layouts/MainLayout.vue'),
    meta: { area: 'staff' },
    children: [
      { path: '', redirect: { name: 'dashboard' } },
      { path: 'dashboard', name: 'dashboard', component: () => import('@/views/DashboardView.vue') },
      { path: 'crud/:resource', name: 'crud', component: () => import('@/views/CrudView.vue') },
      { path: 'applications', name: 'applications', component: () => import('@/views/ApplicationsView.vue'), meta: { perm: 'queue:read' } },
      { path: 'analytics', name: 'analytics', component: () => import('@/views/AnalyticsView.vue'), meta: { perm: 'analytics:read' } },
      { path: 'raw-query', name: 'raw-query', component: () => import('@/views/RawQueryView.vue'), meta: { perm: 'raw_query:run' } },
      { path: 'settings', name: 'settings', component: () => import('@/views/SettingsView.vue'), meta: { perm: 'billing_settings:read' } },
      { path: 'admin/users', name: 'admin-users', component: () => import('@/views/admin/UsersView.vue'), meta: { perm: 'user:read' } },
      { path: 'admin/roles', name: 'admin-roles', component: () => import('@/views/admin/RolesView.vue'), meta: { perm: 'role:read' } },
    ],
  },

  // ---- customer self-service portal ----
  {
    path: '/portal',
    component: () => import('@/layouts/PortalLayout.vue'),
    meta: { area: 'portal' },
    children: [
      { path: '', name: 'portal-home', component: () => import('@/views/portal/PortalDashboard.vue') },
      { path: 'apply', name: 'portal-apply', component: () => import('@/views/portal/PortalApply.vue') },
      { path: 'line/:id', name: 'portal-line', component: () => import('@/views/portal/PortalLine.vue') },
    ],
  },

  { path: '/:pathMatch(.*)*', redirect: { name: 'landing' } },
]

const router = createRouter({ history: createWebHistory(), routes })

router.beforeEach(async (to) => {
  if (to.meta.public) return true

  // customer portal area
  if (to.meta.area === 'portal') {
    const c = useCustomerStore()
    if (!c.loaded) await c.fetchMe()
    if (!c.isAuthenticated) return { name: 'portal-login', query: { redirect: to.fullPath } }
    return true
  }

  // operator / admin area
  const auth = useAuthStore()
  if (!auth.loaded) await auth.fetchMe()
  if (!auth.isAuthenticated) return { name: 'staff-login', query: { redirect: to.fullPath } }
  const perm = to.meta.perm as string | undefined
  if (perm && !auth.can(perm)) return { name: 'dashboard' }
  return true
})

export default router
