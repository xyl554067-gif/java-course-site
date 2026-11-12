<script setup lang="ts">
defineProps<{ canIncludeLesson: boolean }>()
const localOnly = defineModel<boolean>('localOnly', { required: true })
const includeLesson = defineModel<boolean>('includeLesson', { required: true })
</script>

<template>
  <div class="assistant-options">
    <label><input v-model="localOnly" type="checkbox" /> 仅用课程资料</label>
    <label v-if="canIncludeLesson"><input v-model="includeLesson" type="checkbox" /> 带入当前课时</label>
  </div>
</template>

<style scoped>
.assistant-options {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 14px;
  margin-block: 4px 8px;
  font-size: 0.8rem;
  color: var(--c-ink);
}
.assistant-options label {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  min-height: 28px;
  cursor: pointer;
}
.assistant-options input {
  margin: 0;
  accent-color: var(--c-mint);
}
</style>
