<script setup lang="ts">
import type { CodeRunResult } from '@/api'

defineProps<{ result: CodeRunResult }>()
</script>

<template>
  <div class="run-timing">
    <span>等待 {{ result.requestMs }} ms</span>
    <span>服务器处理 {{ result.durationMs }} ms</span>
    <span v-if="result.reusedCompilation">已复用编译结果</span>
    <span v-else-if="result.compileMs != null">编译 {{ result.compileMs }} ms</span>
    <span v-if="result.executionMs != null">执行 {{ result.executionMs }} ms</span>
  </div>
</template>

<style scoped>
.run-timing {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 14px;
  margin: 6px 0 0;
  font-size: .875rem;
  font-variant-numeric: tabular-nums;
}
</style>
