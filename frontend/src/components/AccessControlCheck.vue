<script setup lang="ts">
import { computed, ref } from 'vue'

const props = defineProps<{ labSlug: string }>()

const questions = [
  {
    title: '同包的其他类',
    context: 'demo.bank.BankCheck 中，account 的类型是 Account。',
    code: 'System.out.println(account.balance);',
    allowed: false,
    reason: 'balance 是 private 字段。同包的其他顶层类也不能直接访问，可改用 account.getBalance()。',
  },
  {
    title: '异包子类中的 this',
    context: 'demo.app.SavingsAccount 继承 Account，在子类方法中调用。',
    code: 'System.out.println(this.auditCode());',
    allowed: true,
    reason: 'auditCode() 是 protected 实例方法。访问发生在异包子类内部，通过 this 调用可以通过编译。',
  },
  {
    title: '父类类型的引用',
    context: '同一个子类方法中，parent 的声明是 Account parent = this。',
    code: 'System.out.println(parent.auditCode());',
    allowed: false,
    reason: '访问检查使用引用的编译期类型。这里 parent 是 Account 类型，不能这样访问 protected 实例方法，可改为 this.auditCode()。',
  },
  {
    title: '包内方法与子包',
    context: 'demo.bank.tools 包中的普通类，account 的类型是 Account。',
    code: 'System.out.println(account.branchCode());',
    allowed: false,
    reason: 'branchCode() 省略了访问修饰符，只能在 demo.bank 包内访问。demo.bank.tools 是另一个包，可把这次调用放回 demo.bank 中验证。',
  },
]

const answers = ref<(boolean | null)[]>(questions.map(() => null))
const checked = ref(questions.map(() => false))
const correctCount = computed(() => questions.filter((question, index) =>
  checked.value[index] && answers.value[index] === question.allowed,
).length)

function choose(index: number, answer: boolean) {
  answers.value[index] = answer
  checked.value[index] = false
}
</script>

<template>
  <section id="access-check" class="access-check" aria-labelledby="access-check-title">
    <h2 id="access-check-title" tabindex="-1">访问权限判断练习</h2>
    <p>以笔记中的 Account 类为例，先判断调用能否通过编译，再核对原因。</p>
    <pre class="access-check__reference"><code>// demo.bank.Account 中的成员
private int balance;
public int getBalance() { return balance; }
protected String auditCode() { return "AUDIT"; }
String branchCode() { return "BANK"; }</code></pre>
    <form v-for="(question, index) in questions" :key="question.title" class="access-check__question" @submit.prevent="checked[index] = true">
      <fieldset>
        <legend>{{ question.title }}</legend>
        <p>{{ question.context }}</p>
        <pre><code>{{ question.code }}</code></pre>
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
      <p v-if="checked[index]" class="access-check__feedback" role="status">
        <strong>{{ answers[index] === question.allowed ? '判断正确。' : '再看一下访问条件。' }}</strong>
        {{ question.reason }}
      </p>
    </form>
    <p v-if="checked.some(Boolean)" class="access-check__summary" role="status">已答对 {{ correctCount }} / {{ questions.length }} 题</p>
    <div class="access-check__actions">
      <RouterLink class="btn btn--sm btn--mint" :to="{ name: 'lesson-lab', params: { slug: props.labSlug } }">去实验室改写账户示例 →</RouterLink>
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
.access-check .access-check__summary { color: var(--c-ink); font-weight: 700; }
</style>
