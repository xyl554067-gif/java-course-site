<script setup lang="ts">
import { computed, ref } from 'vue'
import { codeApi, type CodeRunResult } from '@/api'
import { errMsg } from '@/api/http'
import type { SelfCheckResult } from '@/stores/progress'

const props = defineProps<{ stage: number }>()
const emit = defineEmits<{ result: [result: SelfCheckResult] }>()
const stickerBase = (import.meta.env.BASE_URL || '/') + 'assets/lesson-stickers/'
const seats = [10, 20, 30, 40, 50]
const declaration = 'int[] nums = {' + seats.join(', ') + '};'
const prediction = ref(props.stage >= 1 ? 'boundary' : '')
const predictionPassed = ref(props.stage >= 1)
const showHint = ref(false)
const index = ref(4)
const running = ref(false)
const result = ref<CodeRunResult | null>(null)
const runError = ref('')
const transfer = ref(props.stage >= 2 ? 'two' : '')
const transferFeedback = ref<boolean | null>(props.stage >= 2 ? true : null)

const example = computed(() => [
  declaration,
  'System.out.println(nums[' + index.value + ']);',
].join('\n'))

function checkPrediction() {
  if (!prediction.value || predictionPassed.value) return
  predictionPassed.value = prediction.value === 'boundary'
  showHint.value = !predictionPassed.value
  emit('result', predictionPassed.value ? 'PREDICTION_PASSED' : 'WRONG')
}

function changeIndex() {
  result.value = null
  runError.value = ''
}

async function run() {
  if (running.value) return
  changeIndex()
  running.value = true
  try {
    result.value = await codeApi.run(example.value)
  } catch (error) {
    runError.value = errMsg(error)
  } finally {
    running.value = false
  }
}

function checkTransfer() {
  if (!transfer.value || transferFeedback.value === true) return
  transferFeedback.value = transfer.value === 'two'
  emit('result', transferFeedback.value ? 'PASSED' : 'WRONG')
}
</script>

<template>
  <section id="array-check" class="array-check" aria-labelledby="array-check-title">
    <div class="section-head"><span class="dot" /><h2 id="array-check-title">动手验证数组边界</h2><span class="line" /></div>

    <form @submit.prevent="checkPrediction">
      <fieldset :disabled="predictionPassed">
        <legend>1. 先预测结果</legend>
        <div v-if="!predictionPassed" class="array-ticket">
          <img :src="stickerBase + 'arrays.webp'" alt="" width="72" height="90" loading="lazy" />
          <div>
            <p class="array-ticket__caption">
              <span class="array-ticket__stub" aria-hidden="true">5 号票</span>
              <span>鲸鲸来检票：五个座位，5 号票该坐哪？</span>
            </p>
            <ol class="array-ticket__seats" aria-label="五个座位里存的数" role="list">
              <li v-for="(value, position) in seats" :key="value">
                <span class="array-ticket__seat" :class="{ 'array-ticket__seat--first': showHint && position === 0 }">{{ value }}</span>
                <small v-if="showHint && position === 0">下标 0</small>
              </li>
            </ol>
          </div>
        </div>
        <p><code>{{ declaration }}</code> 分别读取 <code>nums[4]</code> 和 <code>nums[5]</code>，会发生什么？</p>
        <label><input v-model="prediction" type="radio" value="one-based" name="array-prediction" /> 先得到 40，再得到 50</label>
        <label><input v-model="prediction" type="radio" value="boundary" name="array-prediction" /> 先得到 50，再抛出越界异常</label>
        <label><input v-model="prediction" type="radio" value="both-invalid" name="array-prediction" /> 两次都会抛出越界异常</label>
        <button v-if="!predictionPassed" class="btn btn--sm btn--primary" :disabled="!prediction">检查预测</button>
      </fieldset>
      <div aria-live="polite">
        <div v-if="showHint" class="array-check__feedback array-check__hint">
          <img :src="stickerBase + 'flow.webp'" alt="" width="56" height="68" />
          <p><strong>鲸鲸提示</strong><br />装着 10 的座位从 <code>0</code> 号开始。沿着上面的五个座位数一遍，再试一次。</p>
        </div>
        <p v-if="predictionPassed" class="array-check__feedback">答对了。下标从 0 数到 4，<code>nums[4]</code> 是 50。下标 5 已超出数组边界。</p>
      </div>
    </form>

    <template v-if="predictionPassed">
      <slot name="explanation" />

      <div class="array-check__step">
        <h3>2. 改一个下标，运行两次</h3>
        <p>先用下标 4 运行，再把它改成 5，看看输出有什么不同。</p>
        <pre><code>{{ example }}</code></pre>
        <div class="array-check__actions">
          <label for="array-check-index">读取下标</label>
          <select id="array-check-index" v-model.number="index" :disabled="running" @change="changeIndex">
            <option :value="4">4</option>
            <option :value="5">5</option>
          </select>
          <button type="button" class="btn btn--sm btn--mint" :disabled="running" @click="run">{{ running ? '运行中…' : '运行 Java' }}</button>
        </div>
        <div aria-live="polite">
          <p v-if="runError" class="array-check__feedback">{{ runError }}。可以重试，也可以继续做下一题。</p>
          <div v-if="result" class="array-check__feedback">
            <strong>{{ result.success ? '运行成功' : result.message }}</strong>
            <pre><code>{{ result.output || result.stdout || result.stderr }}</code></pre>
          </div>
        </div>
      </div>

      <form class="array-check__step" @submit.prevent="checkTransfer">
        <fieldset :disabled="transferFeedback === true">
          <legend>3. 换一个数组再试</legend>
          <p><code>int[] scores = {90, 75, 82};</code> 哪个下标是最后一个合法下标？为什么？</p>
          <label><input v-model="transfer" type="radio" value="three" name="array-transfer" @change="transferFeedback = null" /> 3，因为数组长度是 3</label>
          <label><input v-model="transfer" type="radio" value="one" name="array-transfer" @change="transferFeedback = null" /> 1，因为最后一个元素前面只有一个合法位置</label>
          <label><input v-model="transfer" type="radio" value="two" name="array-transfer" @change="transferFeedback = null" /> 2，因为三个元素的下标从 0 开始，依次是 0、1、2</label>
          <button v-if="transferFeedback !== true" class="btn btn--sm btn--primary" :disabled="!transfer">检查答案</button>
        </fieldset>
        <div aria-live="polite">
          <p v-if="transferFeedback === false" class="array-check__feedback">🐳 鲸鲸提示：第一个元素已经占了下标 0。沿着三个元素数一遍，再试一次。</p>
          <p v-if="transferFeedback === true" class="array-check__feedback">答对了。非空数组的最后一个合法下标是 <code>length - 1</code>，读取 <code>scores[3]</code> 就会越界。可以继续下一节了。</p>
        </div>
      </form>
    </template>
  </section>
</template>

<style scoped>
.array-check { margin-top: 30px; scroll-margin-top: calc(var(--nav-h) + 16px); }
.array-check fieldset { padding: 0; margin: 0; border: 0; min-width: 0; }
.array-check legend, .array-check h3 { font-size: 1.1rem; font-weight: 750; }
.array-check h3 { margin: 0; }
.array-check fieldset label { display: flex; align-items: baseline; gap: 8px; margin: 8px 0; }
.array-check fieldset button { margin-top: 6px; }
.array-check__step { margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--c-line); }
.array-check__actions { display: flex; align-items: center; flex-wrap: wrap; gap: 10px; }
.array-check select, .array-check pre { padding: 8px 12px; border-radius: 8px; color: var(--c-ink); background: var(--c-cream); }
.array-check pre { overflow: auto; }
.array-check__feedback { padding: 10px 12px; border-radius: 8px; background: var(--c-cream); color: var(--c-ink); }
div.array-check__feedback { margin-top: 12px; }

.array-ticket {
  display: grid;
  grid-template-columns: clamp(42px, 14%, 72px) minmax(0, 1fr);
  gap: clamp(8px, 2vw, 16px);
  align-items: center;
  margin-top: 10px;
  padding: 10px;
  border: 1px solid var(--c-line);
  border-radius: 12px;
  background: var(--c-cream);
}
.array-ticket img, .array-check__hint img {
  display: block;
  width: 100%;
  height: auto;
  object-fit: contain;
}
.array-ticket__caption {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px 8px;
  margin: 0 0 8px;
  font-weight: 700;
}
.array-ticket__stub {
  padding: 1px 6px;
  border: 1px dashed #66540c;
  border-radius: 4px;
  background: #ffe48b;
  color: #362d10;
  font-size: .8rem;
}
.array-ticket__seats {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: clamp(3px, 1vw, 8px);
  max-width: 290px;
  padding: 0;
  margin: 0;
  list-style: none;
  text-align: center;
}
.array-ticket__seat {
  display: grid;
  place-items: center;
  min-height: 32px;
  border: 1px solid var(--c-line);
  border-bottom-width: 3px;
  border-radius: 8px 8px 5px 5px;
  background: var(--c-paper);
  font-size: .9rem;
  font-weight: 700;
}
.array-ticket__seat--first {
  border-style: dashed;
  background: color-mix(in srgb, var(--c-mint) 22%, var(--c-paper));
}
.array-ticket__seats small { display: block; font-size: .7rem; line-height: 1.2; margin-top: 3px; }
.array-check__hint { display: grid; grid-template-columns: 56px minmax(0, 1fr); gap: 10px; align-items: center; }
.array-check__hint p { margin: 0; }
</style>

