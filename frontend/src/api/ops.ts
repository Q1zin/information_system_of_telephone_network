import api from './client'
import type { Row } from './types'

export const listApplications = () => api.get<Row[]>('/ops/applications').then((r) => r.data)
export const provision = (id: number, body: Row) =>
  api.post(`/ops/applications/${id}/provision`, body).then((r) => r.data)
