import { defineStore } from 'pinia'
import api from '@/api/client'

export interface Customer {
  id: number
  login: string
  last_name: string
  first_name: string
  middle_name?: string | null
  category: string
}

export const useCustomerStore = defineStore('customer', {
  state: () => ({
    customer: null as Customer | null,
    loaded: false,
  }),
  getters: {
    isAuthenticated: (s) => !!s.customer,
    fullName: (s) =>
      s.customer ? `${s.customer.last_name} ${s.customer.first_name}` : '',
  },
  actions: {
    async fetchMe() {
      try {
        const { data } = await api.get<Customer>('/portal/me')
        this.customer = data
      } catch {
        this.customer = null
      } finally {
        this.loaded = true
      }
    },
    async login(login: string, password: string) {
      const { data } = await api.post<Customer>('/portal/login', { login, password })
      this.customer = data
    },
    async register(payload: Record<string, any>) {
      const { data } = await api.post<Customer>('/portal/register', payload)
      this.customer = data
    },
    async logout() {
      try {
        await api.post('/portal/logout')
      } finally {
        this.customer = null
      }
    },
  },
})
