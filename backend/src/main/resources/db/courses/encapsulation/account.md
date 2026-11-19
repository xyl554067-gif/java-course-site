## 余额为什么需要保护

如果余额是 `balance` 公有字段，取款、转账和测试代码都能直接把它改成负数。账户类应该负责维护两条规则：余额不得为负数，失败的操作不得改变余额。

| 对外提供 | 由类内部负责 |
| --- | --- |
| 查看余额：`getBalance()` | 保存余额：`private int balance` |
| 存款：`deposit(amount)` | 检查金额和整数上限，成功后才更新余额 |

## 用方法守住数据

```java
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
```

`balance` 初始值为 0。先比较 `amount > Integer.MAX_VALUE - balance`，就能在实际相加之前排除溢出。读取余额只需要 getter。提供一个能随意写入余额的 setter，会绕过存款规则。

## 边看边练

- 点开「边看边练」，预测存入 100 后再尝试存入 -20 的结果，运行对照。
- 取消示例末尾直接写 `account.balance` 的注释，观察编译器报错。恢复注释后再次运行。
- 再试存入 `Integer.MAX_VALUE`。解释为什么余额已有 100 时，这笔存款应该被拒绝。

**检查点**：能说明 `private` 怎么限制直接访问，以及 `deposit` 怎样保护余额。
