import axios, { AxiosError } from 'axios'

// Same-origin in dev thanks to the Vite proxy; cookies carry the session.
const api = axios.create({ baseURL: '/api', withCredentials: true })

// Normalise backend `{ "error": "..." }` payloads into Error.message.
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
