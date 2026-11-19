import type { QaLessonOption } from '@/api'

export const packageStarterZip = import.meta.env.BASE_URL + 'downloads/java-package-boundaries.zip'

export const practiceLevels = [
  { id: 'EASY', label: '入门' },
  { id: 'MEDIUM', label: '进阶' },
  { id: 'HARD', label: '挑战' },
]

export function practiceLevel(difficulty: string) {
  const legacy: Record<string, string> = { BEGINNER: 'EASY', INTERMEDIATE: 'MEDIUM', ADVANCED: 'HARD' }
  const key = difficulty.toUpperCase()
  return legacy[key] ?? key
}

export function practiceLevelLabel(difficulty: string) {
  return practiceLevels.find(level => level.id === practiceLevel(difficulty))?.label ?? difficulty
}

export interface PracticeTopic<T> {
  id: string
  title: string
  items: T[]
}

export function practiceTopics<T extends { lessonId: number | null }>(items: T[], lessons: QaLessonOption[]) {
  const groups = new Map<string, PracticeTopic<T>>()
  const byLesson = new Map<number, PracticeTopic<T>>()
  const lessonOrder = new Map<number | null, number>()
  for (const [index, lesson] of lessons.entries()) {
    const id = lesson.moduleId == null ? lesson.courseTitle + '/' + lesson.moduleTitle : 'module-' + lesson.moduleId
    let group = groups.get(id)
    if (!group) {
      group = {
        id,
        title: lesson.courseSlug === 'java-encapsulation' ? lesson.courseTitle : lesson.moduleTitle,
        items: [],
      }
      groups.set(id, group)
    }
    byLesson.set(lesson.id, group)
    lessonOrder.set(lesson.id, index)
  }

  const unassigned: PracticeTopic<T> = { id: 'general', title: '通用练习', items: [] }
  for (const item of items) {
    const group = (item.lessonId == null ? undefined : byLesson.get(item.lessonId)) ?? unassigned
    group.items.push(item)
  }
  for (const group of groups.values()) {
    group.items.sort((a, b) => (lessonOrder.get(a.lessonId) ?? 0) - (lessonOrder.get(b.lessonId) ?? 0))
  }
  return [...groups.values(), unassigned].filter(group => group.items.length > 0)
}

export function matchesPracticeQuery(query: string, ...fields: Array<string | null | undefined>) {
  const text = fields.join(' ').toLocaleLowerCase()
  return query.trim().toLocaleLowerCase().split(/\s+/).every(term => text.includes(term))
}
