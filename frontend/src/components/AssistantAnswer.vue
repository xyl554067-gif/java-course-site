<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { isLessonSlug } from '@/stores/assistantConversation'

const props = defineProps<{ content: string }>()
const emit = defineEmits<{ navigate: [] }>()
const router = useRouter()

function escapeHtml(text: string) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function inline(text: string, allowLinks = true): string {
  // Accept paired escaped emphasis from model replies while leaving code literal.
  const tokens = /`([^`\r\n]+)`|\*\*([^*\r\n]+)\*\*|\\\*\\\*([^*\r\n]+?)\\\*\\\*|\[([^\]\r\n]+)\]\(([^)\r\n]+)\)/g
  let html = ''
  let offset = 0
  for (const match of text.matchAll(tokens)) {
    html += escapeHtml(text.slice(offset, match.index))
    const [, code, strong, escapedStrong, label, url] = match
    if (code !== undefined) {
      html += '<code>' + escapeHtml(code) + '</code>'
    } else if (strong !== undefined || escapedStrong !== undefined) {
      html += '<strong>' + inline(strong ?? escapedStrong, allowLinks) + '</strong>'
    } else {
      const slug = url.startsWith('/lesson/') ? url.slice('/lesson/'.length) : ''
      const title = inline(label, false)
      html += allowLinks && isLessonSlug(slug) ? `<a href="#/lesson/${slug}" data-slug="${slug}">${title}</a>` : title
    }
    offset = match.index + match[0].length
  }
  return html + escapeHtml(text.slice(offset))
}

function blocks(text: string) {
  const html: string[] = []
  let items: string[] = []
  let listTag: 'ul' | 'ol' | undefined
  function flushList() {
    if (!listTag) return
    html.push(`<${listTag}>${items.join('')}</${listTag}>`)
    items = []
    listTag = undefined
  }
  for (const line of text.split('\n')) {
    const bullet = /^\s*(?:(\d+)\.|[-+*])\s+(.+)$/.exec(line)
    if (bullet) {
      const tag = bullet[1] ? 'ol' : 'ul'
      if (listTag !== tag) flushList()
      listTag = tag
      items.push('<li>' + inline(bullet[2]) + '</li>')
      continue
    }
    flushList()
    const quote = /^>\s?(.*)$/.exec(line)
    const heading = /^#{1,6}\s+(.+)$/.exec(line)
    if (quote) html.push('<blockquote>' + inline(quote[1]) + '</blockquote>')
    else if (heading) html.push('<p><strong>' + inline(heading[1]) + '</strong></p>')
    else if (line.trim()) html.push('<p>' + inline(line) + '</p>')
  }
  flushList()
  return html.join('')
}

const rendered = computed(() => {
  const source = props.content.replace(/\r\n?/g, '\n')
  const fences = /^[ \t]*```[^`\n]*\n([\s\S]*?)(?:^[ \t]*```[ \t]*$|(?![\s\S]))/gm
  let html = ''
  let offset = 0
  for (const match of source.matchAll(fences)) {
    html += blocks(source.slice(offset, match.index))
    html += '<pre><code>' + escapeHtml(match[1].replace(/\n$/, '')) + '</code></pre>'
    offset = match.index + match[0].length
  }
  return html + blocks(source.slice(offset))
})

function followLesson(event: MouseEvent) {
  const link = (event.target as Element).closest<HTMLAnchorElement>('a[data-slug]')
  const slug = link?.dataset.slug
  if (!slug || !isLessonSlug(slug) || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
  event.preventDefault()
  emit('navigate')
  void router.push({ name: 'lesson', params: { slug } })
}
</script>

<template>
  <div class="assistant-answer" v-html="rendered" @click="followLesson" />
</template>

<style scoped>
.assistant-answer :deep(p), .assistant-answer :deep(ol), .assistant-answer :deep(ul) { margin: 0 0 .55em; }
.assistant-answer :deep(:last-child) { margin-bottom: 0; }
.assistant-answer :deep(strong) { font-weight: 750; }
.assistant-answer :deep(ol), .assistant-answer :deep(ul) { padding-left: 1.5em; }
.assistant-answer :deep(code) { font-family: var(--font-mono); background: var(--c-cream-deep); border-radius: 4px; padding: .1em .25em; }
.assistant-answer :deep(pre) { margin: 0 0 .55em; padding: 9px; border: var(--bw-thin) solid var(--c-line); border-radius: 6px; background: var(--c-paper); white-space: pre; overflow-x: auto; }
.assistant-answer :deep(pre code) { padding: 0; background: none; }
.assistant-answer :deep(blockquote) { margin: 0 0 .55em; padding-left: .7em; border-left: 3px solid var(--c-mint); color: var(--c-ink-soft); }
.assistant-answer :deep(a) { color: var(--c-lilac-deep); font-weight: 700; }
</style>
