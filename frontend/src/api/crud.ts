import api from './client'
import type { Page, Row } from './types'

export const listResource = (path: string, page: number, pageSize: number) =>
  api.get<Page<Row>>(`/${path}`, { params: { page, page_size: pageSize } }).then((r) => r.data)

export const getResource = (path: string, id: number) =>
  api.get<Row>(`/${path}/${id}`).then((r) => r.data)

export const createResource = (path: string, body: Row) =>
  api.post(`/${path}`, body).then((r) => r.data)

export const updateResource = (path: string, id: number, body: Row) =>
  api.put(`/${path}/${id}`, body).then((r) => r.data)

export const deleteResource = (path: string, id: number) =>
  api.delete(`/${path}/${id}`).then((r) => r.data)

export const runAnalytics = (path: string, params: Row) =>
  api.get<Row[]>(`/${path}`, { params }).then((r) => r.data)

export const runRawQuery = (sql: string) =>
  api.post<Row[]>('/raw-query', { sql }).then((r) => r.data)
