import axios, { type AxiosInstance } from 'axios'

/** 后端统一响应包装 */
export interface ApiResult<T = any> {
  code: number
  message: string
  data: T
}

const TOKEN_KEY = 'javacourse_token'

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token)
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY)
}

const http: AxiosInstance = axios.create({
  baseURL: '/api',
  timeout: 30000,
})

http.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

http.interceptors.response.use(
  (resp) => resp.data,
  (error) => {
    //登录态失效时清理并跳回登录页
    const status = error?.response?.status
    if (status === 401) {
      clearToken()
      if (!location.hash.includes('/login')) {
        location.hash = '#/login'
      }
    }
    return Promise.reject(error)
  },
)

/** 拆包统一响应，失败时抛出后端给的中文提示 */
export async function request<T = any>(promise: Promise<ApiResult<T>>): Promise<T> {
  const res = await promise
  if (res.code !== 200) {
    throw new Error(res.message || '请求失败')
  }
  return res.data
}

/** 把 axios 错误转成可展示的中文文案 */
export function errMsg(e: unknown): string {
  if (e instanceof Error) return e.message
  const anyE = e as any
  return anyE?.response?.data?.message || '网络开小差了，请稍后再试'
}

export default http