## 按职责组织两个包

把账户放进 `demo.bank`，把运行入口放进 `demo.app`。包名是类型全名的一部分，目录结构用于承载对应的源文件和编译输出。

```text
src/
  demo/
    bank/Account.java
    app/BankApp.java
```

`demo.bank` 与 `demo.bank.tools` 是两个包。包名有共同前缀也不会共享包访问权限。`import` 可以让你使用简单类名，但不会改变成员的访问权限。

## 复现跨包访问错误

在本地 IDE 中按上面的路径建立两个文件，或把代码保存到同样的目录结构中。先保持 `branchCode()` 那行，观察 javac 的错误；然后改用 `getBalance()`，重新编译和运行。

**src/demo/bank/Account.java**

```java
package demo.bank;

public class Account {
    private int balance = 100;

    public int getBalance() {
        return balance;
    }

    String branchCode() {
        return "BANK";
    }
}
```

**src/demo/app/BankApp.java**

```java
package demo.app;

import demo.bank.Account;

public class BankApp {
    public static void main(String[] args) {
        Account account = new Account();
        System.out.println(account.branchCode()); // 这里故意保留错误
    }
}
```

在 `src` 的上一级目录执行：

```bash
javac -d out src/demo/bank/Account.java src/demo/app/BankApp.java
java -cp out demo.app.BankApp
```

修复后输出 `100`。再把调用方移到 `demo.bank.tools` 并更新它的路径、`package` 声明和运行类名，验证调用 `branchCode()` 仍会报错。

## 在线验证同包可以访问

「代码实验室」把两个类放进同一个源文件。先运行，确认它能读到网点代码。然后把调用改成直接访问 `account.balance`，重跑对比错误。这两次运行分别验证包访问权限和 `private` 的区别。跨包步骤使用上面的两个源文件完成。

**检查点**：能区分「编译器找不到类」和「找到了类，但调用没有访问权限」。
