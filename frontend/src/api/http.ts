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

/**
 * API 基址解析优先级：
 *   1. 运行时 window.__APP_CONFIG__.apiBase —— GitHub Pages 运维直接改 config.js
 *      即可切换后端，无需重新构建。
 *   2. 构建期 VITE_API_BASE_URL —— CI 里注入。
 *   3. 默认 '/api' —— 本地 dev（Vite 代理）与前后端同域部署。
 *
 * 注意：Pages 子路径部署时 '/api' 会解析到域名根（https://user.github.io/api），
 * 因此静态部署务必通过 config.js 或 VITE_API_BASE_URL 指定真实后端地址。
 */
function resolveApiBase(): string {
  const runtime = (window as any).__APP_CONFIG__?.apiBase
  if (typeof runtime === 'string') return runtime
  const buildTime = import.meta.env.VITE_API_BASE_URL as string | undefined
  if (buildTime) return buildTime
  return '/api'
}

const API_BASE_URL = resolveApiBase()

/** 导出解析后的基址，供需要绕过 axios 的场景（如页面卸载时的 keepalive 请求）使用 */
export { API_BASE_URL }

const http: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
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