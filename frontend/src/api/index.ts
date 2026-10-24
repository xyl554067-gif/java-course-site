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

export interface QaItem {
  id: number
  lessonId: number | null
  lessonTitle?: string | null
  lessonSlug?: string | null
  question: string
  answer: string
  options: string | null
  answerKey: string | null
  qaType: 'CHOICE' | 'JUDGE' | 'SHORT_ANSWER' | string
  difficulty: 'EASY' | 'MEDIUM' | 'HARD' | string
  mine: boolean
}

export interface QaLessonOption {
  id: number
  title: string
  slug: string
  moduleTitle: string
  courseTitle: string
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

// ---------------- 代码实验室类型 ----------------

/** 代码执行环境自检结果 */
export interface CodeRuntime {
  ready: boolean
  javac: string | null
  java: string | null
  javaHome: string | null
  javacVersion: string | null
  javaVersion: string | null
  timeoutMs: number
  compileTimeoutMs: number
  memoryLimitMb: number
  maxOutputChars: number
  maxSourceChars: number
  note: string
}

/** 一次代码运行的结果 */
export interface CodeRunResult {
  /** COMPILE_ERROR / RUNTIME_ERROR / TIMEOUT / SUCCESS */
  status: 'COMPILE_ERROR' | 'RUNTIME_ERROR' | 'TIMEOUT' | 'SUCCESS'
  output: string
  stdout: string
  stderr: string
  exitCode: number
  durationMs: number
  message: string
  success: boolean
}

/** 判题结果中的单条用例 */
export interface JudgeCase {
  name: string
  passed: boolean
  expected: string
  actual: string
  note: string | null
}

/** 判题整体结果 */
export interface JudgeResult {
  status: 'PASSED' | 'FAILED' | 'COMPILE_ERROR' | 'RUNTIME_ERROR' | 'TIMEOUT' | 'NOT_FOUND'
  passedCount: number
  totalCount: number
  cases: JudgeCase[]
  stdout: string
  stderr: string
  errorOutput: string
  durationMs: number
  message: string
  exerciseTitle?: string
}

/** 课后习题 */
export interface CodeExercise {
  id: number
  lessonId: number | null
  slug: string
  title: string
  description: string
  difficulty: string
  language: string
  starterCode: string
  /** 测试用例（JSON 字符串，后端原样下发） */
  testCases: string
  hint: string
  sortOrder: number
  lessonTitle?: string
  lessonSlug?: string
}

/** 提交记录 */
export interface CodeSubmission {
  id: number
  exerciseId: number
  status: string
  passedCount: number
  totalCount: number
  durationMs: number
  createdAt: string
  exerciseTitle?: string
  exerciseSlug?: string
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
  qa: () => request<QaItem[]>(http.get('/qa/list')),
  qaLessons: () => request<QaLessonOption[]>(http.get('/qa/lessons')),
  createQa: (item: Record<string, unknown>) => request<QaItem>(http.post('/qa/items', item)),
  updateQa: (id: number, item: Record<string, unknown>) => request<QaItem>(http.put(`/qa/items/${id}`, item)),
  deleteQa: (id: number) => request<void>(http.delete(`/qa/items/${id}`)),
  importQa: (items: Record<string, unknown>[]) => request<{ imported: number; skipped: number; total: number }>(http.post('/qa/import', { items })),
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

export interface GeneratedLesson { title: string; summary?: string; content: string; sourceRefs?: string[]; }
export interface GeneratedModule { title: string; lessons: GeneratedLesson[]; }
export interface GeneratedCourse { title: string; description?: string; learningObjectives?: string[]; prerequisites?: string[]; modules: GeneratedModule[]; }
export interface GeneratedCourseRecord { id: number; title: string; status: 'DRAFT' | 'PUBLISHED'; course: GeneratedCourse; sourceName?: string; sourceUrl?: string; sourceText?: string; shareToken?: string; shareRevoked?: boolean; provider?: string; degraded?: boolean; aiNote?: string; }
export const generatedCourseApi = {
  importFile: (file: File) => { const form = new FormData(); form.append('file', file); return request<GeneratedCourseRecord>(http.post('/ai/courses/import/file', form, { timeout: 120000 })); },
  importUrl: (url: string) => request<GeneratedCourseRecord>(http.post('/ai/courses/import/url', { url }, { timeout: 120000 })),
  list: () => request<any[]>(http.get('/ai/courses')),
  get: (id: number) => request<GeneratedCourseRecord>(http.get(`/ai/courses/${id}`)),
  save: (id: number, course: GeneratedCourse) => request<GeneratedCourseRecord>(http.put(`/ai/courses/${id}`, { course: JSON.stringify(course) })),
  publish: (id: number) => request<GeneratedCourseRecord>(http.post(`/ai/courses/${id}/publish`)),
  share: (id: number) => request<{ token: string }>(http.post(`/ai/courses/${id}/share`)),
  revoke: (id: number) => request<void>(http.delete(`/ai/courses/${id}/share`)),
  shared: (token: string) => request<any>(http.get(`/ai/courses/shared/${token}`)),
}

export const profileApi = {
  get: () => request<any>(http.get('/profile')),
  update: (profile: { nickname: string; avatar: string; email: string }) => request<any>(http.put('/profile', profile)),
  calendar: (year: number, month: number) => request<Array<{ date: string; seconds: number; completed: number }>>(http.get('/profile/calendar', { params: { year, month } })),
  achievements: () => request<Array<{ id: string; title: string; description: string; unlocked: boolean }>>(http.get('/profile/achievements')),
  aiConfig: () => request<AiConfigStatus>(http.get('/profile/ai-config')),
  saveAiConfig: (config: { baseUrl: string; model: string; apiKey?: string }) => request<AiConfigStatus>(http.put('/profile/ai-config', config)),
  testAiConfig: (config: { baseUrl: string; model: string; apiKey?: string }) => request<{ ok: boolean; message: string; latencyMs: number }>(http.post('/profile/ai-config/test', config)),
  clearAiConfig: () => request<void>(http.delete('/profile/ai-config')),
}

export interface AiConfigStatus { configured: boolean; encryptionReady: boolean; baseUrl?: string; model?: string; apiKeyConfigured: boolean; apiKeyHint?: string; }

export const codeApi = {
  /** 代码执行环境自检：JDK 是否就绪 */
  runtime: () => request<CodeRuntime>(http.get('/code/runtime')),
  /**
   * 运行任意 Java 源码（不判题）。
   * 超时单独放宽到 60s：后端编译 15s + 运行 10s，判题还要跑多个用例，
   * 全局 30s 的默认超时不够用。
   */
  run: (code: string, stdin?: string) =>
    request<CodeRunResult>(
      http.post('/code/run', { code, stdin: stdin ?? '' }, { timeout: 60000 }),
    ),
  /** 提交习题并判题 */
  submit: (exerciseId: number, code: string) =>
    request<JudgeResult>(
      http.post('/code/submit', { exerciseId, code }, { timeout: 120000 }),
    ),
  /** 习题列表（不带 lessonId 则取全部） */
  exercises: (lessonId?: number) =>
    request<CodeExercise[]>(http.get('/code/exercises', { params: lessonId ? { lessonId } : {} })),
  /** 习题详情 */
  exercise: (slug: string) => request<CodeExercise>(http.get(`/code/exercises/${slug}`)),
  /** 我的提交记录 */
  submissions: (exerciseId?: number) =>
    request<CodeSubmission[]>(http.get('/code/submissions', { params: exerciseId ? { exerciseId } : {} })),
}
