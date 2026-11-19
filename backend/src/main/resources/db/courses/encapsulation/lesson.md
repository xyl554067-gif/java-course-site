## 数据封装：让账户自己保护余额

**0–4 分钟 · 先看问题，再看代码**

如果调用方能直接写 `account.balance = -20;`，充值、转账和测试代码都可能让余额变成负数。**封装就是把状态和修改状态的规则放在同一个类里**。账户保存私有余额，对外只开放查询和存款等操作。

```java
class Account {
    private int balance;

    public int getBalance() {
        return balance;
    }

    public boolean deposit(int amount) {
        if (amount <= 0 || amount > Integer.MAX_VALUE - balance) {
            return false;
        }
        balance += amount;
        return true;
    }
}
```

`getBalance()` 读取余额，`deposit()` 先校验再更新。上限检查放在加法前，避免 `int` 相加已经溢出。账户从 0 开始，先存 100，再存 -20，预期依次输出 `true`、`false` 和最终余额 `100`。

## 访问控制：谁能调用这个成员

**4–8 分钟 · 先查包，再查继承，最后看引用类型**

下表针对可见类型的实例成员。`private` 在声明它的顶层类型范围内可访问，包含该类型的嵌套类。表中「同包其他类」指其他独立顶层类。

| 修饰符 | 声明类内部 | 同包其他类 | 异包子类 | 异包普通类 |
| --- | --- | --- | --- | --- |
| `private` | 可以 | 不可以 | 不可以 | 不可以 |
| 省略（包访问权限） | 可以 | 可以 | 不可以 | 不可以 |
| `protected` | 可以 | 可以 | 有条件 | 不可以 |
| `public` | 可以 | 可以 | 可以 | 可以 |

假设 `demo.app.SavingsAccount` 继承 `demo.bank.Account`。在子类方法内，可以通过 `this` 调用父类声明的 `protected` 实例方法。通过引用调用时，引用的**声明类型**必须是当前子类或它的子类型。同一个对象换成 `Account` 类型的变量，编译结果就可能不同。

## 包管理：修复一次跨包调用

**8–12 分钟 · 对照两个源文件，先定位再修复**

`package` 声明类型属于哪个包。`import` 让调用方可以写简单类名，访问权限仍取决于声明。`demo.bank` 和 `demo.bank.tools` 是两个包，包名有共同前缀也不会共享包访问权限。

| 源文件 | 职责 |
| --- | --- |
| `src/demo/bank/Account.java` | 保存余额，公开 `getBalance()`，包内使用 `branchCode()` |
| `src/demo/app/BankApp.java` | 导入 `demo.bank.Account`，使用账户的公开接口 |

```java
// BankApp.java 位于 demo.app
Account account = new Account();
// System.out.println(account.branchCode()); // 报错：该方法只在 demo.bank 可访问
System.out.println(account.getBalance());    // 修复后输出 100
```

编译器已经找到了 `Account`，但 `branchCode()` 的访问条件不满足。修复是改用已开放的 `getBalance()`，保留网点代码的包内权限。用 `javac -d out` 生成类文件时，`out` 是编译输出根。执行 `java -cp out demo.app.BankApp` 时要给出主类的全限定名。

## 封装重构：怎样证明改对了

**12–15 分钟 · 看三组输入，回答最后一个问题**

把公开余额改成 `private`，外部查询改用 `getBalance()`，更新统一走带校验的 `deposit(int amount)`。用下表验收，既检查返回值，也检查失败后的余额。

| 初始余额和存款金额 | 期望返回 | 期望余额 |
| --- | --- | --- |
| `100`、`25` | `true` | `125` |
| `100`、`-20` | `false` | `100` |
| `2147483647`、`1` | `false` | `2147483647` |

**收尾问题**：判题只看输出时，怎样确认外部不能直接改余额？在另一个顶层类中临时访问 `account.balance`，用编译器验证私有访问被拒绝，再用公开方法确认业务行为。
