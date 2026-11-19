## 先判断调用发生在哪里

用账户的四个成员比较权限。表格讨论普通顶层类以及异包子类中的实例成员访问，且假设声明类在调用处可见。

| 成员修饰符 | 声明类内部 | 同包其他类 | 异包子类内部 | 异包无继承关系 |
| --- | --- | --- | --- | --- |
| `private` | 可以 | 不可以 | 不可以 | 不可以 |
| 省略（包访问权限） | 可以 | 可以 | 不可以 | 不可以 |
| `protected` | 可以 | 可以 | 受限 | 不可以 |
| `public` | 可以 | 可以 | 可以 | 可以 |

`private` 的访问也可以发生在包围声明的同一个顶层类型的内部，例如它包含的嵌套类。本专题用独立顶层类来对比，避免把这个情况和同包访问混淆。

## 异包子类中的 protected

假设 `demo.app.SavingsAccount` 继承 `demo.bank.Account`，`auditCode()` 是父类声明的 `protected` 实例方法。在子类的方法体内，`this.auditCode()` 可以编译。通过引用访问时，引用的声明类型必须是当前子类或它的子类型。

```java
void check(SavingsAccount peer) {
    System.out.println(this.auditCode()); // 可以
    System.out.println(peer.auditCode()); // 可以
    Account parent = this;
    // System.out.println(parent.auditCode()); // 编译失败
}
```

`parent` 和 `this` 可以指向同一个对象。编译器使用引用的声明类型检查访问权限，因此两种写法结果不同。

## 权限判断练习

先写下调用方所在的包，再看有无继承关系和引用的声明类型。完成下方四个判断，核对每题的编译结果和原因。
