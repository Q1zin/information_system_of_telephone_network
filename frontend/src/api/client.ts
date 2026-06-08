import axios, { AxiosError } from 'axios'

const api = axios.create({ baseURL: '/api', withCredentials: true })

api.interceptors.response.use(
  (r) => r,
  (error: AxiosError<{ error?: string }>) => {
    const err = new Error(humanMessage(error)) as Error & { status?: number }
    err.status = error.response?.status
    return Promise.reject(err)
  },
)

function humanMessage(error: AxiosError<{ error?: string }>): string {
  const fromServer = error.response?.data?.error
  if (fromServer) return fromServer

  const status = error.response?.status
  if (status) {
    if (status === 401) return 'Требуется авторизация'
    if (status === 403) return 'Доступ запрещён'
    if (status === 404) return 'Запись не найдена'
    if (status === 400 || status === 422) return 'Некорректные данные в запросе'
    if (status >= 500) return 'Внутренняя ошибка сервера'
    return `Ошибка запроса (${status})`
  }
  if (error.code === 'ECONNABORTED') return 'Превышено время ожидания ответа сервера'
  return 'Нет связи с сервером'
}

export default api
