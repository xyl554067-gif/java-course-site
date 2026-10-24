<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { generatedCourseApi, type GeneratedCourse, type GeneratedCourseRecord } from '@/api'
import { errMsg } from '@/api/http'

const route=useRoute(), router=useRouter()
const file=ref<File|null>(null), url=ref(''), busy=ref(false), saving=ref(false), error=ref(''), notice=ref('')
const record=ref<GeneratedCourseRecord|null>(null), draft=ref<GeneratedCourse|null>(null), shareUrl=ref('')
const lessonCount=computed(()=>draft.value?.modules.reduce((n,m)=>n+m.lessons.length,0)??0)
const canEdit=computed(()=>record.value?.status==='DRAFT')

function cloneCourse(c:GeneratedCourse){return JSON.parse(JSON.stringify(c)) as GeneratedCourse}
async function load(id:number){busy.value=true;try{record.value=await generatedCourseApi.get(id);draft.value=cloneCourse(record.value.course);if(record.value.shareToken&&!record.value.shareRevoked)shareUrl.value=`${location.origin}${location.pathname}#/shared/${record.value.shareToken}`}catch(e){error.value=errMsg(e)}finally{busy.value=false}}
async function fromFile(){if(!file.value)return;busy.value=true;error.value='';notice.value='正在提取资料并分析生成课程…';try{record.value=await generatedCourseApi.importFile(file.value);draft.value=cloneCourse(record.value.course);notice.value=record.value.degraded?'课程草稿已保存（当前使用本地资料模板，请核对并补充）':'课程草稿已生成并保存';await router.replace({query:{id:String(record.value.id)}})}catch(e){error.value=errMsg(e);notice.value=''}finally{busy.value=false}}
async function fromUrl(){if(!url.value.trim())return;busy.value=true;error.value='';notice.value='正在读取公开网页并分析…';try{record.value=await generatedCourseApi.importUrl(url.value.trim());draft.value=cloneCourse(record.value.course);notice.value=record.value.degraded?'课程草稿已保存（当前使用本地资料模板，请核对并补充）':'课程草稿已生成并保存';await router.replace({query:{id:String(record.value.id)}})}catch(e){error.value=errMsg(e);notice.value=''}finally{busy.value=false}}
async function save(){if(!record.value||!draft.value)return false;saving.value=true;error.value='';try{record.value=await generatedCourseApi.save(record.value.id,draft.value);draft.value=cloneCourse(record.value.course);notice.value='修改已保存到个人课程草稿';return true}catch(e){error.value=errMsg(e);return false}finally{saving.value=false}}
async function publish(){if(!await save()||!record.value)return;busy.value=true;try{record.value=await generatedCourseApi.publish(record.value.id);notice.value='课程已发布到你的个人课程库，默认仅自己可见'}catch(e){error.value=errMsg(e)}finally{busy.value=false}}
async function createShare(){if(!record.value)return;try{const r=await generatedCourseApi.share(record.value.id);record.value.shareToken=r.token;record.value.shareRevoked=false;shareUrl.value=`${location.origin}${location.pathname}#/shared/${r.token}`}catch(e){error.value=errMsg(e)}}
async function revokeShare(){if(!record.value)return;try{await generatedCourseApi.revoke(record.value.id);record.value.shareRevoked=true;record.value.shareToken='';shareUrl.value='';notice.value='分享链接已撤销'}catch(e){error.value=errMsg(e)}}
function addModule(){draft.value?.modules.push({title:'新单元',lessons:[{title:'新课时',summary:'',content:'## 学习目标\n\n## 重点笔记\n\n## 示例\n\n## 总结\n\n## 自测题\n',sourceRefs:[]}]})}
function removeModule(i:number){draft.value?.modules.splice(i,1)}
function addLesson(i:number){draft.value?.modules[i].lessons.push({title:'新课时',summary:'',content:'## 学习目标\n\n## 重点笔记\n\n## 示例\n\n## 总结\n\n## 自测题\n',sourceRefs:[]})}
function removeLesson(mi:number,li:number){draft.value?.modules[mi].lessons.splice(li,1)}
async function copyShare(){if(shareUrl.value)try{await navigator.clipboard.writeText(shareUrl.value);notice.value='分享链接已复制'}catch{error.value='复制失败，请选中链接手动复制'}}
onMounted(()=>{const id=Number(route.query.id);if(id)void load(id)})
</script>

<template>
  <div class="container gen-page">
    <section class="card gen-hero">
      <p class="eyebrow">AI 学习工作台</p><h1>把资料变成一门课</h1>
      <p>导入 PDF、Word、PPT 或公开网页，鲸鲸会整理成可编辑的课程草稿。课程先保存在你的个人课程库，发布后仍默认私有。</p>
      <div class="import-grid">
        <form class="import-card" @submit.prevent="fromFile"><h2>上传本地资料</h2><p>支持文本型 PDF、DOCX、PPTX，单文件最大 20 MB。</p>
          <input type="file" accept=".pdf,.docx,.pptx,application/pdf" @change="file=($event.target as HTMLInputElement).files?.[0]||null" />
          <button class="btn btn--primary" :disabled="busy||!file">{{busy?'处理中…':'分析并生成课程'}}</button></form>
        <form class="import-card" @submit.prevent="fromUrl"><h2>分析公开网页</h2><p>网页应无需登录即可访问；仅提取正文与来源段落。</p>
          <input v-model="url" type="url" placeholder="https://example.com/learning-material" />
          <button class="btn btn--primary" :disabled="busy||!url.trim()">{{busy?'处理中…':'分析链接并生成课程'}}</button></form>
      </div>
      <p v-if="notice" class="notice">{{notice}}</p><p v-if="error" class="error">{{error}}</p>
      <p v-if="record?.aiNote" class="muted">模型通道提示：{{record.aiNote}}</p>
    </section>

    <section v-if="draft&&record" class="card editor-card">
      <div class="editor-head"><div><p class="eyebrow">{{record.status==='DRAFT'?'课程草稿':'个人课程'}}</p><h2>预览与编辑</h2><p class="muted">{{record.sourceName}} · {{draft.modules.length}} 个单元 · {{lessonCount}} 个课时</p></div>
        <div class="actions"><button v-if="canEdit" class="btn btn--ghost" :disabled="saving" @click="save">{{saving?'保存中…':'保存草稿'}}</button><button v-if="canEdit" class="btn btn--primary" :disabled="busy||saving" @click="publish">确认并发布</button><button v-else class="btn btn--ghost" @click="createShare">创建只读分享</button></div></div>
      <div class="course-form"><label>课程名称<input v-model="draft.title" :disabled="!canEdit" maxlength="160" /></label><label>课程简介<textarea v-model="draft.description" :disabled="!canEdit" rows="3" /></label>
        <label>学习目标（每行一项）<textarea :value="(draft.learningObjectives||[]).join('\n')" :disabled="!canEdit" rows="3" @input="draft.learningObjectives=($event.target as HTMLTextAreaElement).value.split('\n').filter(Boolean)" /></label>
        <label>先修知识（每行一项）<textarea :value="(draft.prerequisites||[]).join('\n')" :disabled="!canEdit" rows="2" @input="draft.prerequisites=($event.target as HTMLTextAreaElement).value.split('\n').filter(Boolean)" /></label></div>
      <article v-for="(module,mi) in draft.modules" :key="mi" class="module-editor"><div class="module-head"><input v-model="module.title" :disabled="!canEdit" aria-label="单元名称" /><button v-if="canEdit" class="btn btn--sm btn--ghost" @click="removeModule(mi)">删除单元</button></div>
        <div v-for="(lesson,li) in module.lessons" :key="li" class="lesson-editor"><div class="lesson-fields"><input v-model="lesson.title" :disabled="!canEdit" placeholder="课时标题" /><input v-model="lesson.summary" :disabled="!canEdit" placeholder="课时摘要" /><button v-if="canEdit" class="btn btn--sm btn--ghost" @click="removeLesson(mi,li)">删除课时</button></div>
          <textarea v-model="lesson.content" :disabled="!canEdit" rows="12" aria-label="课程正文 Markdown" />
          <p class="source-ref">资料来源：<span v-if="lesson.sourceRefs?.length">{{lesson.sourceRefs.join('；')}}</span><span v-else>待补充来源</span></p>
        </div><button v-if="canEdit" class="btn btn--sm btn--ghost" @click="addLesson(mi)">＋ 添加课时</button>
      </article>
      <button v-if="canEdit" class="btn btn--ghost" @click="addModule">＋ 添加单元</button>
      <div v-if="shareUrl" class="share-box"><label>只读分享链接<input :value="shareUrl" readonly @focus="($event.target as HTMLInputElement).select()" /></label><button class="btn btn--sm btn--ghost" @click="copyShare">复制</button><button class="btn btn--sm btn--ghost" @click="revokeShare">撤销链接</button></div>
      <div v-else-if="record.shareToken&&!record.shareRevoked" class="share-box"><span>已创建分享链接</span><button class="btn btn--sm btn--ghost" @click="revokeShare">撤销链接</button></div>
    </section>
    <section class="card guidance"><h2>默认课程结构</h2><p>学习目标、先修知识、单元与课时、重点笔记、示例、总结、自测题。编程课程可包含代码单元，其他主题不会强加代码实验。</p><p class="muted">文件内容会发给你配置的 AI 模型进行分析；来源标签用于回查原文。扫描版 PDF OCR 和需要登录的网页暂不支持。</p></section>
  </div>
</template>

<style scoped>
.gen-page{padding:28px 0;max-width:1080px}.gen-hero,.editor-card,.guidance{padding:28px;margin-bottom:22px}.eyebrow{margin:0 0 6px;color:var(--c-mint);font-weight:800}.gen-hero h1,.editor-head h2{margin:0 0 8px}.gen-hero>p:not(.eyebrow){line-height:1.8;color:var(--c-ink-soft)}.import-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:20px}.import-card{display:flex;flex-direction:column;gap:12px;padding:18px;border:2px solid var(--c-line);border-radius:18px;background:var(--c-paper)}.import-card h2{margin:0}.import-card p{margin:0;color:var(--c-ink-soft)}input,textarea{width:100%;padding:11px 13px;border:2px solid var(--c-line);border-radius:12px;background:var(--c-paper);color:var(--c-ink);font:inherit}.editor-head,.module-head,.lesson-fields,.share-box{display:flex;align-items:center;justify-content:space-between;gap:12px}.editor-head{margin-bottom:20px}.editor-head p{margin:4px 0}.actions{display:flex;gap:10px;flex-wrap:wrap}.course-form{display:grid;grid-template-columns:1fr 1fr;gap:14px}.course-form label,.share-box label{display:flex;flex-direction:column;gap:6px;font-weight:700}.module-editor{margin-top:22px;padding:18px;border:2px solid var(--c-line);border-radius:18px;background:var(--c-cream)}.module-head input{max-width:70%;font-size:19px;font-weight:800}.lesson-editor{margin:14px 0;padding:16px;border:1px solid var(--c-line);border-radius:14px;background:var(--c-paper)}.lesson-fields{margin-bottom:10px}.lesson-fields input:first-child{max-width:30%;font-weight:700}.lesson-fields input:nth-child(2){flex:1}.lesson-editor textarea{font-family:var(--font-mono);line-height:1.65;white-space:pre-wrap}.source-ref,.muted{font-size:13px;color:var(--c-ink-faint)}.source-ref{margin-bottom:0}.share-box{margin-top:18px;padding:14px;border-radius:12px;background:var(--c-mint-soft,#e4f7f2)}.share-box label{flex:1}.notice{color:#21815d;font-weight:700}.error{color:var(--c-coral-deep);font-weight:700}.guidance h2{margin:0 0 8px}.guidance p{line-height:1.8}.guidance .muted{font-size:13px}@media(max-width:720px){.import-grid,.course-form{grid-template-columns:1fr}.editor-head{align-items:flex-start;flex-direction:column}.lesson-fields{flex-wrap:wrap}.lesson-fields input:first-child,.lesson-fields input:nth-child(2){max-width:none;flex-basis:100%}.share-box{flex-wrap:wrap}}
</style>
