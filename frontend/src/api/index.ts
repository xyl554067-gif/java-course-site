import http, { request } from './http'

// ---------------- 类型 ----------------

export interface Course {
  id: number
  slug: string
  title: string
  subtitle: string
  description: string
  instructor: string
  version: string
  difficulty: string
  totalLessons: number
  createdAt?: string
}

export interface Lesson {
  id: number
  moduleId: number
  slug: string
  title: string
  summary: string
  content?: string
  durationMin?: number
  difficulty?: string
  viewCount?: number
}

export interface CourseModule {
  id: number
  courseId: number
  title: string
  summary: string
  icon: string
  sortOrder: number
  lessonCount: number
  lessons?: Lesson[]
}

export interface CodeSnippet {
  id: number
  lessonId: number
  title: string
  language: string
  code: string
  explanation?: string
}

export interface KnowledgePoint {
  id: number
  name: string
  category: string
  description?: string
}

export interface SearchHit {
  id: number
  targetType: string
  targetId: number
  title: string
  body: string
  refUrl: string
  score: number
  highlight: string
}

export interface AgentProfile {
  key: string
  name: string
  title: string
  greeting: string
  moods: string[]
  avatars: Record<string, string> | string[]
}

export interface Citation {
  title: string
  slug: string
  summary: string
}

export interface AskResult {
  answer: string
  citations: Citation[]
  sessionId: number
  latencyMs: number
  agent: AgentProfile
  /** 实际生效的模型通道：openai / ollama / local */
  provider?: string
  /** 是否走了降级（true = 首选通道未成功，用了兜底） */
  degraded?: boolean
}

/** AI 通道诊断信息 */
export interface AiHealth {
  provider: string
  baseUrl: string
  model: string
  fallbackOrder: string
  ollamaBaseUrl: string
  ollamaModel: string
  timeoutMs: number
  openaiConfigured: boolean
  effective: string
  degraded: boolean
  note: string
}

// ---------------- 接口 ----------------

export const authApi = {
  login: (username: string, password: string) =>
    request<{ token: string; expiresIn: number; user: any }>(
      http.post('/auth/login', { username, password }),
    ),
  register: (username: string, password: string, nickname: string) =>
    request<{ token: string; expiresIn: number; user: any }>(
      http.post('/auth/register', { username, password, nickname }),
    ),
  logout: () => request<void>(http.post('/auth/logout')),
  me: () => request<any>(http.get('/auth/me')),
}

export const courseApi = {
  list: () => request<Course[]>(http.get('/course/list')),
  detail: (slug: string) => request<any>(http.get(`/course/${slug}`)),
  modules: () => request<CourseModule[]>(http.get('/modules')),
  lesson: (slug: string) => request<any>(http.get(`/lesson/${slug}`)),
  qa: () => request<any[]>(http.get('/qa/list')),
}

export const searchApi = {
  search: (q: string) => request<SearchHit[]>(http.get('/search', { params: { q } })),
  suggest: (q: string) => request<string[]>(http.get('/search/suggest', { params: { q } })),
}

export const aiApi = {
  agent: () => request<AgentProfile>(http.get('/ai/agent')),
  ask: (question: string, sessionTitle?: string) =>
    request<AskResult>(http.post('/ai/ask', { question, sessionTitle })),
  health: () => request<AiHealth>(http.get('/ai/health')),
}