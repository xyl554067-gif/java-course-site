<script setup lang="ts">
/**
 * 轻量 Java 代码编辑器
 *
 * 为什么不用 CodeMirror / Monaco：
 *   两者都好几 MB，会把这个教学站点的首屏体积拖垮，
 *   而教学场景需要的只是「能改代码 + 有行号 + 能跑起来」。
 *   这里用 textarea + 同步滚动的行号列实现，零依赖、零构建成本。
 *
 * 关键实现：
 *   · 行号列与代码区共享同一个字体度量，用 transform 同步滚动位置
 *   · Tab 键插入 4 空格（而不是跳走），Shift+Tab 反缩进
 *   · Ctrl/Cmd + Enter 触发「运行」
 *   · 代码区用等宽字体 + 保留空白，中文注释也能对齐
 */
import { ref, computed, nextTick, onMounted } from 'vue'

const props = withDefaults(defineProps<{
  modelValue: string
  readonly?: boolean
  placeholder?: string
  minRows?: number
  maxRows?: number
}>(), {
  readonly: false,
  placeholder: '在这里写 Java 代码…',
  minRows: 12,
  maxRows: 28,
})

const emit = defineEmits<{
  (e: 'update:modelValue', v: string): void
  (e: 'run'): void
}>()

const ta = ref<HTMLTextAreaElement | null>(null)
const gutter = ref<HTMLElement | null>(null)

/** 行号列表 */
const lineCount = computed(() => Math.max(props.modelValue.split('\n').length, props.minRows))
const lineNumbers = computed(() =>
  Array.from({ length: lineCount.value }, (_, i) => i + 1),
)

/** 缩进单位 */
const INDENT = '    '

function syncScroll() {
  if (gutter.value && ta.value) {
    gutter.value.scrollTop = ta.value.scrollTop
  }
}

function onInput(e: Event) {
  emit('update:modelValue', (e.target as HTMLTextAreaElement).value)
}

function onScroll() {
  syncScroll()
}

/** Tab：插入缩进；Shift+Tab：反缩进 */
function onKeydown(e: KeyboardEvent) {
  // Ctrl/Cmd + Enter → 运行
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    e.preventDefault()
    emit('run')
    return
  }
  if (e.key !== 'Tab' || props.readonly) {
    return
  }
  e.preventDefault()
  const el = ta.value
  if (!el) {
    return
  }
  const start = el.selectionStart
  const end = el.selectionEnd
  const value = props.modelValue

  if (e.shiftKey) {
    // 反缩进：删掉光标所在行行首的缩进
    const lineStart = value.lastIndexOf('\n', start - 1) + 1
    let remove = 0
    while (lineStart + remove < end && value[lineStart + remove] === ' ') {
      remove++
    }
    if (remove > 0) {
      const next = value.slice(0, lineStart) + value.slice(lineStart + remove)
      emit('update:modelValue', next)
      void nextTick(() => {
        el.selectionStart = el.selectionEnd = start - remove
      })
    }
    return
  }

  // 多行选区：每行都缩进
  if (start !== end && value.slice(start, end).includes('\n')) {
    const lineStart = value.lastIndexOf('\n', start - 1) + 1
    const seg = value.slice(lineStart, end)
    const next = seg
      .split('\n')
      .map((l) => INDENT + l)
      .join('\n')
    const newValue = value.slice(0, lineStart) + next + value.slice(end)
    emit('update:modelValue', newValue)
    void nextTick(() => {
      el.selectionStart = lineStart
      el.selectionEnd = lineStart + next.length
    })
    return
  }

  // 单点：插入 4 空格
  const next = value.slice(0, start) + INDENT + value.slice(end)
  emit('update:modelValue', next)
  void nextTick(() => {
    el.selectionStart = el.selectionEnd = start + INDENT.length
  })
}

/** 跳到指定行（编译错误定位用） */
function gotoLine(line: number) {
  const el = ta.value
  if (!el) {
    return
  }
  const lines = props.modelValue.split('\n')
  let pos = 0
  for (let i = 0; i < Math.min(line - 1, lines.length); i++) {
    pos += lines[i].length + 1
  }
  el.focus()
  el.setSelectionRange(pos, pos)
  // 让目标行大致居中
  const lineHeight = 22
  el.scrollTop = Math.max(0, (line - 4) * lineHeight)
  syncScroll()
}

defineExpose({ gotoLine })

onMounted(() => {
  syncScroll()
})
</script>

<template>
  <div class="editor" :class="{ 'editor--readonly': readonly }">
    <!-- 行号列 -->
    <div ref="gutter" class="editor__gutter" aria-hidden="true">
      <div v-for="n in lineNumbers" :key="n" class="editor__ln">{{ n }}</div>
    </div>

    <!-- 代码区 -->
    <textarea
      ref="ta"
      class="editor__code"
      :value="modelValue"
      :placeholder="placeholder"
      :readonly="readonly"
      spellcheck="false"
      autocomplete="off"
      autocapitalize="off"
      autocorrect="off"
      :rows="minRows"
      @input="onInput"
      @scroll="onScroll"
      @keydown="onKeydown"
    />
  </div>
</template>

<style scoped>
.editor {
  display: flex;
  align-items: stretch;
  background: #1e2544;
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-md);
  overflow: hidden;
  font-family: 'Cascadia Code', 'JetBrains Mono', Consolas, 'Courier New', monospace;
  font-size: 13.5px;
  line-height: 22px;
}

/* 行号列 */
.editor__gutter {
  flex: 0 0 auto;
  width: 46px;
  padding: 12px 0;
  background: #171c36;
  color: #6b74a8;
  text-align: right;
  overflow: hidden;
  user-select: none;
  border-right: 1px solid #2f3862;
}
.editor__ln {
  padding-right: 10px;
  height: 22px;
}

/* 代码区 */
.editor__code {
  flex: 1;
  min-width: 0;
  padding: 12px 14px;
  background: transparent;
  border: none;
  outline: none;
  resize: vertical;
  color: #e8ecff;
  font: inherit;
  tab-size: 4;
  white-space: pre;
  overflow-wrap: normal;
  overflow-x: auto;
  caret-color: var(--c-sun);
}
.editor__code::placeholder {
  color: #5a6296;
}
.editor--readonly .editor__code {
  color: #b9c0e8;
  cursor: default;
}

/* 滚动条在深色底上要调暗 */
.editor__code::-webkit-scrollbar {
  height: 10px;
  width: 10px;
}
.editor__code::-webkit-scrollbar-track {
  background: #171c36;
}
.editor__code::-webkit-scrollbar-thumb {
  background: #3b4577;
  border: 2px solid #171c36;
  border-radius: var(--radius-full);
}
.editor__code::-webkit-scrollbar-thumb:hover {
  background: #4d5a95;
}
</style>
