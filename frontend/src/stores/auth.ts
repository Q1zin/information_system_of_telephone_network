import { defineStore } from 'pinia'
import api from '@/api/client'
import type { CurrentUser } from '@/api/types'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as CurrentUser | null,
    loaded: false,
  }),
  getters: {
    isAuthenticated: (s) => !!s.user,
    can: (s) => (perm: string) =>
      !!s.user && (s.user.is_superadmin || s.user.permissions.includes(perm)),
  },
  actions: {
    async fetchMe() {
      try {
        const { data } = await api.get<CurrentUser>('/auth/me')
        this.user = data
      } catch {
        this.user = null
      } finally {
        this.loaded = true
      }
    },
    async login(username: string, password: string) {
      const { data } = await api.post<CurrentUser>('/auth/login', { username, password })
      this.user = data
    },
    async logout() {
      try {
        await api.post('/auth/logout')
      } finally {
        this.user = null
      }
    },
  },
})
