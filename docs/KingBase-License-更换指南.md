# KingbaseES V8R6 授权过期 —— 更换操作指南

> 现状：`D:\Kingbase\KESRealPro\V008R006C009B0014\license.dat`（3676 字节，签发于 2026-03-17）已过期。
> 启动报错：`FATAL: XX000: License file expired.`（`KesMasterMain, master.c:961`）
> 服务：`kingbase8_R6_instance`（Windows 服务，端口 54321，数据目录 `D:\Kingbase\data`）

---

## 步骤 0：先拿到新 license.dat（必须你来做）

新 license 是**加密签名文件**，必须从金仓官方渠道获取，我无法生成。三条路：

| 途径 | 说明 |
|---|---|
| **A. 官网自助下载（推荐）** | 登录 https://www.kingbase.com.cn/ → 产品/授权中心 → 申请试用或正式授权 → 下载 `license.dat`（务必选**与你当前版本 V8R6C009B0014 匹配**的类型，否则同样报 license 错误） |
| **B. 找公司 DBA / 采购联系人** | 说明是「金仓 V8R6 授权续期/替换」，让对方提供与本机**机器码/主机标识匹配**的 license.dat |
| **C. 金仓技术支持** | 400 电话 / 官网工单，提供序列号与合同号 |

**拿到后先核对**（记事本打开 license.dat，是 `-----BEGIN KINGASE.LICENSE.3.0 PRIVATE KEY-----` 开头的一段 Base64 文本），确认：
- 文件名必须是 `license.dat`（**不能**改名成 `license_new.dat`，服务端只认这个名字）
- 头部是 `KINGASE.LICENSE.3.0`（V8 系列格式）
- 拿到的是 V8 版本，不是 V9（V9 license 装到 V8 上不生效）

---

## 步骤 1：停服务

用**管理员身份**打开 PowerShell（Win+X → 终端(管理员)）：

```powershell
# 方式一：停止 Windows 服务（推荐）
Stop-Service -Name kingbase8_R6_instance -Force
Get-Service kingbase8_R6_instance     # 确认 Status = Stopped

# 方式二：如果服务管理不便，用自带的 sys_ctl
cd "D:\Kingbase\KESRealPro\V008R006C009B0014\Server\bin"
.\sys_ctl.exe -D "D:\Kingbase\data" -m fast stop
```

---

## 步骤 2：备份旧 license

```powershell
$root = "D:\Kingbase\KESRealPro\V008R006C009B0014"
Copy-Item "$root\license.dat" "$root\license.dat.bak" -Force
Copy-Item "D:\Kingbase\data\kingbase.conf" "D:\Kingbase\data\kingbase.conf.bak" -Force
```

---

## 步骤 3：替换新 license 并重建软链接

> 官方文档明确要求：**替换 `KESRealPro/版本号/` 目录下的 license.dat 后，需重新建立软链接**。
> 你机器上 `D:\Kingbase\license.dat` 是一个 Windows 快捷方式（.lnk），指向安装目录的真实文件。

```powershell
$root = "D:\Kingbase\KESRealPro\V008R006C009B0014"
$new  = "C:\Users\lxy\Downloads\license.dat"   # ← 改成你新下载文件的实际路径

# 1) 校验新文件格式
Get-Content $new -TotalCount 1
# 期望输出: -----BEGIN KINGASE.LICENSE.3.0 PRIVATE KEY-----

# 2) 覆盖真实 license
Copy-Item $new "$root\license.dat" -Force

# 3) 重建根目录快捷方式指向新文件
$sh = New-Object -ComObject WScript.Shell
$lnk = $sh.CreateShortcut("D:\Kingbase\license.dat.lnk")
$lnk.TargetPath = "$root\license.dat"
$lnk.Save()

# 4) 如果数据目录里也有 license 引用，一并同步（部分部署存在）
if (Test-Path "D:\Kingbase\data\license.dat") {
    Copy-Item $new "D:\Kingbase\data\license.dat" -Force
}
```

---

## 步骤 4：加载授权（不重启也能生效）

```powershell
cd "D:\Kingbase\KESRealPro\V008R006C009B0014\Server\bin"
.\sys_license.exe -F "D:\Kingbase\data\license.dat"
# 期望输出类似: license updated successfully
```

- 若提示**机器码不匹配 / 文件格式错误** → license 与本机或版本不匹配，回步骤 0 重新申请
- 若提示命令不存在 → 跳过本步，直接启动服务让服务端自己加载

---

## 步骤 5：启动并验证

```powershell
Start-Service -Name kingbase8_R6_instance
Start-Sleep -Seconds 3
Get-Service kingbase8_R6_instance     # 期望 Running
```

或用 ksql 连一下验证授权状态：

```powershell
cd "D:\Kingbase\KESRealPro\V008R006C009B0014\ClientTools\bin"
.\ksql.exe -U system -d system -c "SELECT * FROM license_information;"
```

若 ksql 提示 `WARNING: License file will expire in N days` 说明已生效，N 天后需再次续期。

---

## 步骤 6：确认端口与 JDBC

```powershell
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -eq 54321 }
```

- JDBC URL：`jdbc:kingbase8://localhost:54321/你的库名`
- 驱动类：`com.kingbase8.Driver`
- 驱动 jar（本地已有，无需下载）：
  `D:\Kingbase\KESRealPro\V008R006C009B0014\ClientTools\guitools\KStudio\configuration\org.eclipse.osgi\13\0\.cp\lib\kingbase8-8.6.0.jar`

---

## 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 换成新 license 仍报过期 | 装成了 V9 的 license，或版本/授权类型不匹配 | 确认下载的是 V8 R6 对应授权 |
| 换后提示「机器码不匹配」 | license 绑定了别的机器 | 找金仓按本机机器码重签 |
| 服务启动报「无法打开服务」 | 当前终端非管理员 | 用管理员终端，或直接 `sys_ctl start` |
| 端口不是 54321 | 集群/多实例部署 | 以 `kingbase.conf` 的 `port=` 为准 |
| `sys_ctl` 报 `another server might be running` | 残留 `kingbase.pid` | 确认进程真已退出后删 `D:\Kingbase\data\kingbase.pid` 再启 |

---

## 备选方案（若 license 短期拿不到）

开发期可用 PostgreSQL 兼容实例跑通全链路，DDL 严格按 KingBase 兼容规范编写（避开 `tsvector`/`pg_trgm`/`vector` 扩展，规避保留字），待 license 到位后仅改连接串与驱动即可切换到真库，**业务代码零改动**。
