import axios, { AxiosError } from 'axios'

const api = axios.create({ baseURL: '/api', withCredentials: true })

api.interceptors.response.use(
  (r) => r,
  (error: AxiosError<{ error?: string }>) => {
    const msg = error.response?.data?.error || error.message || 'Request failed'
    const err = new Error(msg) as Error & { status?: number }
    err.status = error.response?.status
    return Promise.reject(err)
  },
)

export default api
