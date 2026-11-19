from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "backend/src/main/resources/db/courses/encapsulation/packages.md"
OUTPUT = ROOT / "frontend/public/downloads/java-package-boundaries.zip"
MAVEN_PROJECT = """\
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>demo</groupId>
  <artifactId>java-package-boundaries</artifactId>
  <version>1.0.0</version>
  <properties>
    <maven.compiler.release>17</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
  <build>
    <sourceDirectory>src</sourceDirectory>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.13.0</version>
      </plugin>
    </plugins>
  </build>
</project>
"""
README = """\
# 双包实验 · 复现并修复跨包访问错误

需要 JDK 17 或更新版本。

- IntelliJ IDEA：打开 pom.xml，并选择作为 Maven 项目打开。
- VS Code：装好 Java 扩展后，打开解压得到的 java-package-boundaries 目录。

先编译一次。BankApp.java 中的 branchCode() 只有包访问权限，demo.app 里的入口无法调用它。初始工程故意保留此处编译错误。

把 BankApp.java 里的 account.branchCode() 改成 account.getBalance()。再次编译并运行 BankApp.main，应该输出 100。

也可以在包含 pom.xml 的目录使用终端。先执行这一条观察报错，修复后用同一条命令重新编译。

```bash
javac -encoding UTF-8 -d out src/demo/bank/Account.java src/demo/app/BankApp.java
```

编译成功后运行。

```bash
java -cp out demo.app.BankApp
```
"""


def main():
    files = dict(re.findall(r"(?m)^\*\*(src/[a-z/]+/[A-Z]\w*\.java)\*\*\n\n\x60{3}java\n([\s\S]+?)^\x60{3}$",
                            LESSON.read_text(encoding="utf-8")))
    if set(files) != {"src/demo/bank/Account.java", "src/demo/app/BankApp.java"}:
        raise ValueError("The package lesson must provide Account.java and BankApp.java")
    files.update({"pom.xml": MAVEN_PROJECT, "README.md": README})
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(OUTPUT, "w") as archive:
        for name, content in sorted(files.items()):
            entry = ZipInfo("java-package-boundaries/" + name)
            archive.writestr(entry, content.encode("utf-8"), compress_type=ZIP_DEFLATED)


if __name__ == "__main__":
    main()
