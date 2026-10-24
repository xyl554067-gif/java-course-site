<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { profileApi, type AiConfigStatus } from '@/api'

const status = ref<AiConfigStatus | null>(null)
const form = reactive({ baseUrl: '', model: '', apiKey: '' })
const busy = ref(false)
const testing = ref(false)
const message = ref('')
const error = ref('')
const hasSavedKey = computed(() => status.value?.apiKeyConfigured === true)

async function load() {
  status.value = await profileApi.aiConfig()
  form.baseUrl = status.value.baseUrl || ''
  form.model = status.value.model || ''
}

async function testConnection() {
  testing.value = true; message.value = ''; error.value = ''
  try {
    const result = await profileApi.testAiConfig(form)
    message.value = `${result.message} · ${result.latencyMs} ms`
  } catch (e: any) { error.value = e?.message || '连接测试失败' }
  finally { testing.value = false }
}

async function save() {
  busy.value = true; message.value = ''; error.value = ''
  try {
    status.value = await profileApi.saveAiConfig(form)
    form.apiKey = ''
    message.value = '已保存。小助教和课程工坊会共用这套配置。'
  } catch (e: any) { error.value = e?.message || '保存失败' }
  finally { busy.value = false }
}

async function reset() {
  if (!window.confirm('删除账号保存的模型配置？小助教和课程工坊会改用后端默认配置。')) return
  busy.value = true; message.value = ''; error.value = ''
  try {
    await profileApi.clearAiConfig()
    form.apiKey = ''; form.baseUrl = ''; form.model = ''
    await load()
    message.value = '账号模型配置已删除。'
  } catch (e: any) { error.value = e?.message || '删除失败' }
  finally { busy.value = false }
}

onMounted(() => { void load().catch((e: any) => { error.value = e?.message || '读取配置失败' }) })
</script>

<template>
  <div class="container ai-settings-page">
    <header class="page-head">
      <div><p class="eyebrow">AI 接入</p><h1>连接你的模型</h1><p>配置一次后，鲸鲸小助教和 AI 课程工坊都会使用此模型。</p></div>
      <RouterLink class="btn btn--ghost" to="/me">返回学习中心</RouterLink>
    </header>

    <section class="card settings-card">
      <div class="status-line">
        <span class="status-dot" :class="{ 'is-ready': status?.configured }"></span>
        <b>{{ status?.configured ? '已配置账号专属模型' : '尚未配置账号专属模型' }}</b>
        <span v-if="status?.apiKeyConfigured" class="key-state">API Key 已加密保存</span>
      </div>

      <div v-if="status && !status.encryptionReady" class="notice notice--warn">
        后端还没有设置专用加密密钥，暂时不能保存账号 API Key。请先在服务端配置 AI_CONFIG_ENCRYPTION_KEY（至少 32 个字符）。
      </div>

      <form class="config-form" @submit.prevent="save">
        <label>接口地址（OpenAI 兼容 HTTPS 地址）
          <input v-model="form.baseUrl" type="url" required placeholder="https://api.deepseek.com" autocomplete="url" />
          <small>可填写服务商根地址或以 /v1 结尾的地址。为保护账号安全，不接受本机或内网地址。</small>
        </label>
        <label>模型名称
          <input v-model="form.model" required placeholder="填写服务商控制台提供的模型 ID" autocomplete="off" />
        </label>
        <label>API Key
          <input v-model="form.apiKey" type="password" :required="!hasSavedKey" autocomplete="new-password" :placeholder="hasSavedKey ? '留空表示继续使用已保存的 Key' : '粘贴服务商 API Key'" />
          <small>Key 只在提交时发送给后端；后端使用账号专属配置加密保存，不会返回给浏览器。</small>
        </label>
        <div class="actions">
          <button class="btn btn--primary" type="submit" :disabled="busy || !status?.encryptionReady">{{ busy ? '保存中…' : '保存配置' }}</button>
          <button class="btn btn--ghost" type="button" :disabled="testing" @click="testConnection">{{ testing ? '测试中…' : '测试连接' }}</button>
          <button v-if="status?.configured" class="btn btn--ghost" type="button" :disabled="busy" @click="reset">删除账号配置</button>
        </div>
      </form>
      <p v-if="message" class="notice notice--success" role="status">{{ message }}</p>
      <p v-if="error" class="notice notice--error" role="alert">{{ error }}</p>
    </section>

    <section class="card guidance">
      <h2>配置说明</h2>
      <ul>
        <li>仅支持 OpenAI 兼容的 HTTPS 接口。请从服务商控制台复制 API 地址、模型 ID 和 Key。</li>
        <li>Key 按当前登录账号分别保存；其他账号无法读取或使用。</li>
        <li>连接测试会发送一条简短测试消息给模型服务商，配置仅在点击“保存配置”后写入账号。</li>
        <li>删除此配置后会切回服务端默认模型；如服务端也未配置模型，功能会使用课程检索兜底。</li>
      </ul>
    </section>
  </div>
</template>

<style scoped>
.ai-settings-page{max-width:860px;padding:34px 0 64px}.page-head{display:flex;justify-content:space-between;align-items:flex-start;gap:18px;margin-bottom:22px}.eyebrow{margin:0 0 5px;color:var(--c-mint);font-weight:800}.page-head h1{margin:0 0 8px}.page-head p:not(.eyebrow){color:var(--c-ink-soft);margin:0;line-height:1.7}.settings-card,.guidance{padding:24px;margin-bottom:18px}.status-line{display:flex;align-items:center;gap:9px;margin-bottom:22px}.status-dot{width:10px;height:10px;border-radius:50%;background:#aaa}.status-dot.is-ready{background:#39aa83}.key-state{margin-left:auto;color:var(--c-ink-faint);font-size:13px}.config-form{display:grid;gap:17px}.config-form label{display:grid;gap:7px;font-weight:750}.config-form input{width:100%;padding:12px 14px;border:2px solid var(--c-line);border-radius:12px;background:var(--c-paper);color:var(--c-ink);font:inherit}.config-form input:focus{outline:3px solid color-mix(in srgb,var(--c-mint) 30%,transparent);border-color:var(--c-mint)}.config-form small{font-weight:400;color:var(--c-ink-faint);line-height:1.55}.actions{display:flex;gap:10px;flex-wrap:wrap}.notice{padding:12px 14px;border-radius:11px;line-height:1.6}.notice--warn{background:#fff5d8;color:#795c16}.notice--success{background:#e6f7ef;color:#247352}.notice--error{background:#fff0ed;color:#a33b36}.guidance h2{margin:0 0 10px}.guidance li{margin:8px 0;line-height:1.65;color:var(--c-ink-soft)}@media(max-width:650px){.page-head{flex-direction:column}.settings-card,.guidance{padding:18px}}
</style>

