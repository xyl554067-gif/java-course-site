<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { generatedCourseApi } from '@/api'
const route=useRoute(),data=ref<any>(null),error=ref(''),loading=ref(true)
onMounted(async()=>{try{data.value=await generatedCourseApi.shared(String(route.params.token))}catch(e:any){error.value=e?.message||'分享链接无效'}finally{loading.value=false}})
</script>
<template><div class="container shared"><div v-if="loading" class="card">正在加载课程…</div><div v-else-if="error" class="card error">{{error}}</div><template v-else-if="data"><header class="card"><span class="badge badge--mint">只读课程</span><h1>{{data.title}}</h1><p>{{data.course.description}}</p></header><section class="card objectives"><h2>学习目标</h2><ul><li v-for="(v,i) in data.course.learningObjectives||[]" :key="i">{{v}}</li></ul></section><article v-for="(m,mi) in data.course.modules" :key="mi" class="card module"><h2>{{m.title}}</h2><section v-for="(l,li) in m.lessons" :key="li" class="lesson"><h3>{{l.title}}</h3><p>{{l.summary}}</p><pre>{{l.content}}</pre><small>来源：{{(l.sourceRefs||[]).join('；')||data.sourceName}}</small></section></article></template></div></template>
<style scoped>.shared{max-width:900px;padding:32px 0}.shared>.card,.module{padding:24px;margin-bottom:18px}.shared h1{margin:12px 0}.shared p{line-height:1.8;color:var(--c-ink-soft)}.objectives ul{line-height:2}.lesson{padding:18px 0;border-top:1px solid var(--c-cream-deep)}.lesson pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit;line-height:1.85}.lesson small{color:var(--c-ink-faint)}.error{color:var(--c-coral-deep)}</style>
