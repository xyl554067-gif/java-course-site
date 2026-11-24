<script setup lang="ts">
import { computed, ref } from 'vue'

const props = defineProps<{ labSlug: string; demo?: boolean }>()

const allQuestions = [
  {
    title: '同包的其他类',
    context: 'demo.bank.BankCheck 中，account 的类型是 Account。',
    code: 'System.out.println(account.balance);',
    allowed: false,
    hint: '先找 balance 的访问修饰符，再确认这行调用写在 Account 自己的类体里，还是写在同包的另一个类里。',
    reason: 'balance 是 private 字段。同包的其他顶层类也不能直接访问，可改用 account.getBalance()。',
  },
  {
    title: '异包子类中的 this',
    context: 'demo.app.SavingsAccount 继承 Account，在子类方法中调用。',
    code: 'System.out.println(this.auditCode());',
    allowed: true,
    hint: '先确认调用写在哪个类的方法里，再判断这个方法中的 this 是什么类型。',
    reason: 'auditCode() 是 protected 实例方法。访问发生在异包子类内部，通过 this 调用可以通过编译。',
  },
  {
    title: '父类类型的引用',
    context: '同一个子类方法中，parent 的声明是 Account parent = this。',
    code: 'System.out.println(parent.auditCode());',
    allowed: false,
    hint: '赋值后 parent 和 this 指向同一个对象。编译器检查 parent 时，用的是变量声明处写的什么类型？',
    reason: '跨包访问这个 protected 实例方法时，接收者的编译期类型必须是 SavingsAccount 或其子类。parent 声明为 Account，可改用 this.auditCode()。',
  },
  {
    title: '包内方法与子包',
    context: 'demo.bank.tools 包中的普通类，account 的类型是 Account。',
    code: 'System.out.println(account.branchCode());',
    allowed: false,
    hint: '把 Account 和调用代码所在的完整包名写出来，逐段比较。',
    reason: 'branchCode() 省略了访问修饰符，只能在 demo.bank 包内访问。demo.bank.tools 是另一个包，可把这次调用放回 demo.bank 中验证。',
  },
]

const questions = props.demo ? allQuestions.slice(1, 3) : allQuestions
const heading = ref<HTMLHeadingElement | null>(null)
const answers = ref<(boolean | null)[]>(questions.map(() => null))
const checked = ref(questions.map(() => false))
const restartCount = ref(0)
const checkedCount = computed(() => checked.value.filter(Boolean).length)
const correctCount = computed(() => questions.filter((question, index) =>
  checked.value[index] && answers.value[index] === question.allowed,
).length)

function choose(index: number, answer: boolean | null) {
  answers.value[index] = answer
  checked.value[index] = false
}

function retry(index: number, event: MouseEvent) {
  choose(index, null)
  const trigger = event.currentTarget as HTMLButtonElement
  trigger.form?.querySelector<HTMLInputElement>('input[type="radio"]')?.focus()
}

function restart() {
  answers.value = questions.map(() => null)
  checked.value = questions.map(() => false)
  restartCount.value++
  heading.value?.focus()
}
</script>

<template>
  <section id="access-check" class="access-check" :class="{ 'access-check--comparison': props.demo }" aria-labelledby="access-check-title">
    <h2 id="access-check-title" ref="heading" tabindex="-1">访问权限判断练习</h2>
    <p>以笔记中的 Account 类为例，先判断调用能否通过编译，再核对原因。</p>
    <pre class="access-check__reference"><code>// demo.bank.Account 中的成员
private int balance;
public int getBalance() { return balance; }
protected String auditCode() { return "AUDIT"; }
String branchCode() { return "BANK"; }</code></pre>
    <form v-for="(question, index) in questions" :key="question.title" class="access-check__question"
      :data-verdict="props.demo && checked[index] ? (question.allowed ? 'allowed' : 'denied') : undefined"
      @submit.prevent="checked[index] = true">
      <fieldset>
        <legend>{{ question.title }}</legend>
        <p>{{ question.context }}</p>
        <pre><code><template v-if="props.demo && index === 1">{{ 'Account parent = this;\n' }}</template>{{ question.code }}</code></pre>
        <p v-if="props.demo" class="access-check__receiver">接收者的编译期类型 <code>{{ index === 0 ? 'SavingsAccount' : 'Account' }}</code></p>
        <div class="access-check__actions">
          <label v-for="choice in [true, false]" :key="String(choice)">
            <input
              type="radio"
              :name="'access-question-' + index"
              :checked="answers[index] === choice"
              @change="choose(index, choice)"
            />
            {{ choice ? '可以编译' : '编译失败' }}
          </label>
          <button type="submit" class="btn btn--sm btn--ghost" :disabled="answers[index] === null">核对判断</button>
        </div>
      </fieldset>
      <details v-if="!checked[index]" :key="restartCount" class="access-check__hint">
        <summary>查看判断提示</summary>
        <p>{{ question.hint }}</p>
      </details>
      <p v-if="checked[index]" class="access-check__feedback" role="status">
        <strong>{{ answers[index] === question.allowed ? '判断正确。' : '再看一下访问条件。' }}</strong>
        <template v-if="answers[index] !== question.allowed">正确判断是{{ question.allowed ? '可以编译' : '编译失败' }}。</template>
        <template v-else-if="props.demo">{{ question.allowed ? '可以编译。' : '编译失败。' }}</template>
        {{ question.reason }}
      </p>
      <button
        v-if="checked[index] && answers[index] !== question.allowed"
        type="button"
        class="btn btn--sm btn--ghost access-check__retry"
        @click="retry(index, $event)"
      >再判断这一题</button>
    </form>
    <p v-if="props.demo && checkedCount === questions.length" class="access-check__takeaway">
      <strong>同一个对象，两种编译期类型。</strong>
      <code>this</code> 的类型是 <code>SavingsAccount</code>，<code>parent</code> 的声明类型是 <code>Account</code>。编译器按接收者的编译期类型判断这次跨包访问。
    </p>
    <div v-if="checkedCount" class="access-check__actions access-check__review">
      <p class="access-check__summary">已核对 {{ checkedCount }} 题，已答对 {{ correctCount }} / {{ questions.length }} 题</p>
      <button type="button" class="btn btn--sm btn--ghost access-check__restart" @click="restart">重新作答</button>
    </div>
    <div class="access-check__actions">
      <RouterLink v-if="!props.demo" class="btn btn--sm btn--mint" :to="{ name: 'lesson-lab', params: { slug: props.labSlug } }">去实验室改写账户示例 →</RouterLink>
      <a href="https://docs.oracle.com/javase/specs/jls/se21/html/jls-6.html#jls-6.6.2.1" target="_blank" rel="noopener noreferrer">核对 Java 访问规则 ↗</a>
    </div>
  </section>
</template>

<style scoped>
.access-check { margin-top: 28px; border-top: 2px solid var(--c-line); padding-top: 22px; scroll-margin-top: calc(var(--nav-h) + 16px); }
.access-check h2 { margin: 0 0 10px; font-size: 1.4rem; }
.access-check > p, .access-check fieldset p { color: var(--c-ink-soft); line-height: 1.65; }
.access-check pre { max-width: 100%; margin: 10px 0 14px; padding: 12px; overflow-x: auto; border-radius: 10px; background: var(--c-cream); color: var(--c-ink); font: .85rem/1.6 var(--font-mono); }
.access-check__question { margin: 14px 0; padding: 14px; border: 1px solid var(--c-ink-faint); border-radius: 12px; }
.access-check fieldset { min-width: 0; padding: 0; margin: 0; border: 0; }
.access-check legend { font-weight: 800; }
.access-check fieldset p { margin: 6px 0; font-size: .9rem; }
.access-check__actions { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 16px; }
.access-check__actions label { display: inline-flex; align-items: center; gap: 5px; }
.access-check__actions a:not(.btn) { color: var(--c-ink-soft); font-size: .85rem; }
.access-check__feedback { margin: 12px 0 0; padding: 10px; background: #edf6f2; border-radius: 8px; line-height: 1.65; }
.access-check__hint, .access-check__retry { margin-top: 10px; }
.access-check__hint summary { cursor: pointer; color: var(--c-ink); text-decoration: underline; text-underline-offset: 3px; }
.access-check__hint p { margin: 6px 0 0; color: var(--c-ink-soft); line-height: 1.65; }
.access-check__review { margin-bottom: 12px; }
.access-check__summary { margin: 0; color: var(--c-ink); font-weight: 700; }

.access-check--comparison {
  display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px;
  border-top-color: var(--topic-ink);
}
.access-check--comparison > :not(.access-check__question) { grid-column: 1 / -1; }
.access-check--comparison > h2,
.access-check--comparison > p,
.access-check--comparison > pre { margin: 0; }
.access-check--comparison .access-check__question { margin: 0; min-width: 0; border-color: var(--topic-ink); border-radius: 0; }
.access-check--comparison pre { border-radius: 0; }
.access-check--comparison fieldset pre { min-height: calc(3.2em + 24px); white-space: pre-wrap; overflow-wrap: anywhere; }
.access-check--comparison .access-check__receiver { margin-bottom: 12px; font-weight: 750; }
.access-check--comparison code { font-family: var(--font-mono); }
.access-check--comparison .access-check__feedback { border-radius: 0; color: var(--topic-ink); border-left: 5px solid var(--topic-blue); background: #edf0ff; }
.access-check--comparison [data-verdict="denied"] .access-check__feedback { background: #faeae4; border-left-color: var(--topic-red); }
.access-check--comparison .access-check__takeaway { padding: 12px 14px; border-left: 5px solid var(--topic-ink); background: #fff2c2; color: var(--topic-ink); }
@media (max-width: 700px) {
  .access-check--comparison { grid-template-columns: minmax(0, 1fr); }
  .access-check--comparison fieldset pre { min-height: 0; }
}
</style>
