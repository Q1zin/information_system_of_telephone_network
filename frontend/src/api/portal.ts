import api from './client'
import type { Row } from './types'

export const overview = () => api.get<Row>('/portal/overview').then((r) => r.data)
export const apply = (b: Row) => api.post('/portal/applications', b).then((r) => r.data)
export const pbxOptions = () => api.get<Row[]>('/portal/pbx-options').then((r) => r.data)
export const cities = () => api.get<Row[]>('/portal/cities').then((r) => r.data)
export const tariffs = () => api.get<Row[]>('/portal/tariffs').then((r) => r.data)

export const setIntercity = (numberId: number, enabled: boolean) =>
  api.put(`/portal/lines/${numberId}/intercity`, { enabled }).then((r) => r.data)
export const makeCall = (numberId: number, b: Row) =>
  api.post(`/portal/lines/${numberId}/call`, b).then((r) => r.data)
export const callHistory = (numberId: number) =>
  api.get<Row[]>(`/portal/lines/${numberId}/calls`).then((r) => r.data)

export const invoices = () => api.get<Row[]>('/portal/invoices').then((r) => r.data)
export const payInvoice = (id: number) =>
  api.post(`/portal/invoices/${id}/pay`).then((r) => r.data)
