每次收班费，登记程序都要做两件事，记下账户还有多少钱，以及判断新收到的金额能不能记入账户。假如任何地方都能直接修改余额，一次输错就可能把余额变成负数。

我们从能记住余额的简单对象开始，逐步回答三个问题，余额由谁维护、不同位置的代码能访问什么、写在不同文件里的类如何找到彼此。最后用一次编译报错和几组输入检查设计结果。

## 先认识类、对象和成员 {#lesson-section-5}

**类是定义，对象是按这份定义创建的具体实例。** `Account` 是账户类，`new Account()` 会创建一个账户对象。类中用字段保存状态，用方法定义可执行的操作。两个账户对象各有一份 `balance`，一个账户收款时，另一个账户的余额不会跟着变化。

下面是最初的草稿。把它保存为 `FirstAccountDemo.java`，就可以看到两个对象的余额彼此独立。

```java
class Account {
    int balance;
}

public class FirstAccountDemo {
    public static void main(String[] args) {
        Account classFund = new Account();
        Account activityFund = new Account();
        classFund.balance = 100;
        System.out.println(classFund.balance);
        System.out.println(activityFund.balance);
    }
}
```

两个账户的 `int` 实例字段创建时都默认为 `0`。赋值后依次输出 `100` 和 `0`。创建对象时会调用构造器；这个草稿没有自己声明构造器，所以 Java 提供默认无参构造器。

> 同一个草稿也允许写 `classFund.balance = -20;`。对象虽然能记住余额，余额的规则还没有被它自己保护。下一步把规则放回账户类。

## 用封装把余额和规则放到一起 {#lesson-section-1}

封装把数据和处理这些数据的方法组织在同一个类里。这个账户的设计约定很简单：**余额只能通过合法存款增加，失败时保留原值。**

| 需要什么 | 由谁负责 |
| --- | --- |
| 保存余额 | `private int balance`，由账户内部维护 |
| 查看余额 | `public int getBalance()`，调用方可以读到当前数值 |
| 录入存款 | `public boolean deposit(int amount)`，账户先校验，再决定是否更新 |

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

`private` 是访问限制，`deposit` 里的检查是业务规则，两者一起保护余额。没有必要为每个字段都提供写入方法。这里允许查询，但若增加一个接受任意数字的 `setBalance`，调用者就能绕过存款校验。

运行前先预测输出。新建账户的余额为 `0`，存入 `100` 返回 `true`，再尝试存入 `-20` 返回 `false`，查询仍是 `100`。代码里的上限检查可以先记为「先确认加得下」；它写在加法之前，可以防止整数溢出。

> 同一个类守住了状态。当账户和登记入口分别写在不同文件里，我们还需要一种方式说明每个类放在哪里，以及另一个文件怎样引用它。

## 用包给类安排位置 {#lesson-section-3}

在小程序里，可以把所有类放在一起。项目变大时，把相关类型放到同一个**包**里，就能按职责组织代码，也能区分不同包里恰好同名的类。

| 源文件 | 包与职责 |
| --- | --- |
| `src/demo/bank/Account.java` | `package demo.bank;`，负责管理账户 |
| `src/demo/app/BankApp.java` | `package demo.app;`，负责启动程序和调用账户 |

`package` 声明本文件的类型归属，通常写在文件开头。`import` 写在包声明之后，下面的两种写法都能指向同一个类型。

```java
package demo.app;

import demo.bank.Account;

public class BankApp {
    public static void main(String[] args) {
        Account a = new Account();                    // 导入后使用简单类名
        demo.bank.Account b = new demo.bank.Account(); // 直接使用全限定类名
    }
}
```

同包里可见的类通常可以直接用简单类名。`String` 来自默认导入的 `java.lang`。如果两个包都有同名类，可以用全限定类名区分。`import demo.bank.*;` 不会自动导入 `demo.bank.tools` 的类型，子包在访问规则上也属于另一个包。

> 到这里，登记程序已经能找到 `Account`。能找到一个类，只解决了名字的问题；它能调用哪些字段和方法，还要看访问权限。下面就用这两个包来判断。

## 用访问权限决定谁能调用 {#lesson-section-2}

对比之前的代码，查询方法应该让登记程序调用，余额字段应留在账户内部，网点代码有时只需同包的工具类查看。Java 用访问修饰符表达这些边界。下表假定声明类在调用处可见，讨论的是**实例成员**。

| 成员修饰符 | 声明类内部 | 同包其他顶层类 | 异包子类内部 | 异包普通类 |
| --- | --- | --- | --- | --- |
| `private` | 可以 | 不可以 | 不可以 | 不可以 |
| 省略修饰符（包访问权限） | 可以 | 可以 | 不可以 | 不可以 |
| `protected` | 可以 | 可以 | 有条件 | 不可以 |
| `public` | 可以 | 可以 | 可以 | 可以 |

顶层类本身也有可见性。例子中的 `public class Account` 能被 `demo.app` 引用。如果省略顶层类的 `public`，它只在自己的包中可见，即便某个方法声明了 `public`，包外也不能通过不可见的类来直接使用它。对初学者来说，`private` 可以先记为留在类内部。同一顶层类型包含的嵌套类也可以访问其私有成员。

**判断顺序**可以固定下来。先问「类型可见吗」，再问「调用者与声明者是否同包」，最后问「跨包时是否通过子类使用继承来的 `protected` 成员」。

假设 `SavingsAccount extends Account` 写在另一个包。`extends` 表示它是 `Account` 的子类，`this` 表示子类方法当前所在的对象。在子类方法内部，`this.auditCode()` 可以访问父类声明的 `protected` 实例方法。若改用 `Account parent = this;` 再调用 `parent.auditCode()`，就会编译失败。两个写法指向同一个对象，但编译器检查的是引用的**声明类型**。跨包子类通过引用调用这类成员时，引用的声明类型必须是当前子类或它的子类型。

> 在下方判断这两种写法后，再把同样的思路用到一个真正的双包错误上。

## 复现错误，修复并验收 {#lesson-section-4}

双包实验提供了同一个账户案例的简化版本，预置余额为 `100`。`Account` 在 `demo.bank` 里，`getBalance()` 是公开方法，省略修饰符的 `branchCode()` 留给同包使用。`BankApp` 在 `demo.app`，已经通过 `import demo.bank.Account;` 找到了账户类。

```java
// 在 BankApp 的 main 中，account 的类型是 demo.bank.Account。
// 初始工程保留下面这一行，编译器会提示包外无法访问。
System.out.println(account.branchCode());

// 把上一行替换为下面这一行，重新编译后输出 100。
System.out.println(account.getBalance());
```

先判断错误是「找不到名字」还是「名字找到了，权限不够」。此处是第二种。再加 `import` 不会改变权限，直接使用业务上允许的公开查询即可。把包内方法改成 `public` 会扩大接口，也会暴露登记程序不需要的实现细节。

解压实验工程后，可以在 IDE 内观察报错，也可以在包含 `src` 的项目根目录执行下面的命令。先编译观察报错，修复后重跑编译，再执行运行命令。`out` 是编译输出和类路径的根；`demo.app.BankApp` 是入口类的全限定名。

```bash
javac -encoding UTF-8 -d out src/demo/bank/Account.java src/demo/app/BankApp.java
java -cp out demo.app.BankApp
```

**回到最初的问题**。重构后的账户把余额藏在类里，只开放必要的操作；包帮助调用者找到类型，访问修饰符决定调用范围。验收时先让编译器拒绝外部直接改余额，再用输入和结果核对业务行为。

| 初始余额 | 存款金额 | 期望结果 | 调用后余额 |
| --- | --- | --- | --- |
| `100` | `25` | 成功 | `125` |
| `100` | `0` 或 `-20` | 拒绝 | `100` |
| `2147483647` | `1` | 拒绝 | `2147483647` |

能解释「哪一行不允许、依据是什么、通过哪个公开操作修复」，就能把这节课的三项知识连起来。
