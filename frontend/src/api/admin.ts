import api from './client'
import type { Row } from './types'

export const listUsers = () => api.get<Row[]>('/admin/users').then((r) => r.data)
export const createUser = (b: Row) => api.post('/admin/users', b).then((r) => r.data)
export const updateUser = (id: number, b: Row) => api.put(`/admin/users/${id}`, b).then((r) => r.data)
export const deleteUser = (id: number) => api.delete(`/admin/users/${id}`).then((r) => r.data)
export const setUserRoles = (id: number, role_ids: number[]) =>
  api.post(`/admin/users/${id}/roles`, { role_ids }).then((r) => r.data)

export const listRoles = () => api.get<Row[]>('/admin/roles').then((r) => r.data)
export const createRole = (b: Row) => api.post<{ id: number }>('/admin/roles', b).then((r) => r.data)
export const updateRole = (id: number, b: Row) => api.put(`/admin/roles/${id}`, b).then((r) => r.data)
export const deleteRole = (id: number) => api.delete(`/admin/roles/${id}`).then((r) => r.data)
export const setRolePermissions = (id: number, permission_ids: number[]) =>
  api.post(`/admin/roles/${id}/permissions`, { permission_ids }).then((r) => r.data)

export const listPermissions = () => api.get<Row[]>('/admin/permissions').then((r) => r.data)
