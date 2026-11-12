<script setup lang="ts">
import { ref } from 'vue'
import { codeApi } from '@/api'
import { errMsg } from '@/api/http'

const props = defineProps<{ code: string; stdin: string }>()
const busy = ref(false)
const error = ref('')
const notice = ref('')
const helperUrl = import.meta.env.BASE_URL + 'ide/JavaCourseIdeBridge.java'
const localBase = 'http://127.0.0.1:18763/v1'
type LocalRequest = RequestInit & { targetAddressSpace: 'loopback' }

function localRequest(path: string, init: RequestInit = {}) {
  const options: LocalRequest = {
    ...init,
    targetAddressSpace: 'loopback',
    credentials: 'omit',
    redirect: 'error',
    signal: AbortSignal.timeout(30000),
  }
  return fetch(localBase + path, options)
}

async function openIn(ide: 'idea' | 'vscode') {
  if (busy.value || !props.code.trim()) return
  const code = props.code
  const stdin = props.stdin
  busy.value = true
  error.value = ''
  notice.value = ''
  try {
    let status: Response
    try {
      status = await localRequest('/status')
    } catch {
      throw new Error('无法连接本机助手。请确认助手正在运行，并在浏览器提示时允许本机网络访问。')
    }
    if (!status.ok || (await status.text()) !== 'JavaCourseIdeBridge/v1') {
      throw new Error('本机助手版本不匹配，请下载并启动本页提供的版本。')
    }
    const archive = await codeApi.exportProject(code, stdin)
    const response = await localRequest('/open/' + ide, {
      method: 'POST',
      headers: { 'Content-Type': 'application/zip' },
      body: archive,
    })
    const message = await response.text()
    if (!response.ok) throw new Error(message)
    notice.value = message
  } catch (e) {
    error.value = errMsg(e)
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <details class="local-ide">
    <summary>在本机 IDE 打开</summary>
    <div class="local-ide__actions">
      <button type="button" class="btn btn--sm btn--ghost" :disabled="busy || !code.trim()" @click="openIn('idea')">IntelliJ IDEA</button>
      <button type="button" class="btn btn--sm btn--ghost" :disabled="busy || !code.trim()" @click="openIn('vscode')">VS Code</button>
      <span v-if="busy" role="status">正在打开…</span>
    </div>
    <p v-if="error" class="local-ide__error" role="alert">{{ error }}</p>
    <p v-if="notice" role="status">{{ notice }}</p>
    <p>首次使用需要 Windows 和 JDK 17+。<a :href="helperUrl" download>下载本机助手</a>，在下载目录的终端运行：</p>
    <pre><code>java "-Dfile.encoding=UTF-8" JavaCourseIdeBridge.java</code></pre>
    <details class="local-ide__setup">
      <summary>指定 IDE 安装位置</summary>
      <pre><code>java "-Dfile.encoding=UTF-8" JavaCourseIdeBridge.java --idea "D:\路径\idea64.exe" --vscode "D:\路径\Code.exe"</code></pre>
    </details>
  </details>
</template>

<style scoped>
.local-ide { margin: 12px 0; padding: 10px 12px; border: 1px solid var(--c-line); border-radius: 10px; }
.local-ide summary { color: var(--c-ink); font-weight: 700; cursor: pointer; }
.local-ide__actions { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-top: 10px; }
.local-ide p { margin: 8px 0; font-size: .875rem; }
.local-ide pre { padding: 8px; background: var(--c-paper); overflow-x: auto; margin: 6px 0; }
.local-ide__setup { font-size: .875rem; }
.local-ide__error { color: #8f3129; }
</style>
