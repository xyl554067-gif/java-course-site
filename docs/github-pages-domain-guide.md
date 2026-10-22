# GitHub Pages 域名配置指南

> 仓库：https://github.com/xyl554067-gif/java-course-site
> 部署脚本：`scripts/deploy_pages.sh`

---

## 一、当前状态（已核查）

| 项目 | 状态 |
|---|---|
| 默认访问地址 | `https://xyl554067-gif.github.io/java-course-site/` → **HTTP 200，已生效** |
| Pages 发布源 | 分支 `gh-pages`，路径 `/`（build_type: legacy） |
| 自定义域名 (CNAME) | **未设置**（`cname: null`，`protected_domain_state: null`） |
| HTTPS | 已强制开启（`https_enforced: true`） |
| 仓库可见性 | **public** |
| Pages 状态 | `built` |

**结论：默认地址 `用户名.github.io/仓库名` 已经生效并可正常访问，不需要任何额外配置。**
自定义域名是「可选增强」，不是当前可用性的前提。

---

## 二、⚠️ 部署中发现并已修复的安全问题

核查过程中发现一个**必须优先处理**的问题：

### 现象

线上站点**公开暴露了整个仓库源码**，包括敏感配置。实测可匿名下载：

```
https://xyl554067-gif.github.io/java-course-site/scripts/kb_env.sh          → HTTP 200
https://xyl554067-gif.github.io/java-course-site/backend/src/main/resources/application.yml → HTTP 200
```

`kb_env.sh` 内含数据库口令 `KB_APP_PW="App@Course2026"`、`KB_SYS_PW="123456"`；
`application.yml` 内含 JWT 密钥 `javacourse-default-secret-key-...` 与数据库口令默认值。

### 根因

`scripts/deploy_pages.sh` 推送产物时**传了 `base_tree`**：

```python
base_tree = gh([f"repos/{repo}/git/commits/{base}"])["tree"]["sha"]
tree = gh([f"repos/{repo}/git/trees"], {"base_tree": base_tree, "tree": items})
```

Git 的 tree 是「以某棵树为基础 + 叠加若干条目」。传 `base_tree` 等于**以 master 分支的整棵树
为底**，再把 `dist/` 产物叠上去 —— 于是 `backend/`、`scripts/`、`docs/` 等**全部原样留在 gh-pages
分支上**，而 Pages 会把分支上的每个文件都当作静态资源提供下载。

### 修复

**不传 `base_tree`**，即新建一棵只含产物的树：

```python
# ⚠️ 关键：不能传 base_tree。
# 传了 base_tree 就等于以「基线分支的整棵树」为基础再叠加产物，
# 结果是把 master 上的 backend/、scripts/（含数据库密码与 JWT 密钥）
# 一并发布成公开可下载的静态文件。
# 不传 base_tree 即新建一棵只含产物的树，分支上的其他文件自然消失。
tree = gh([f"repos/{repo}/git/trees"], {"tree": items})
```

### 你还需要做的（这部分我无法代劳）

**代码已经在公开仓库的历史里，口令已经暴露过，修复构建流程不能消除历史记录。**
建议按顺序处理：

1. **立刻改数据库口令**（最高优先级）
   ```bash
   # 用管理员连接改应用账号口令
   bash scripts/kb_env.sh   # 编辑其中的 KB_APP_PW / KB_SYS_PW
   # 再执行对应的 ALTER USER
   ```
   KingbaseES 改口令后需同步更新 `backend/src/main/resources/application.yml` 的
   `KB_PASSWORD` 环境变量取值来源。

2. **改 JWT 密钥**：生产环境务必用环境变量 `APP_JWT_SECRET` 注入真实随机值，
   不要用仓库里的默认值。

3. **考虑把仓库转为 private**（如果你不需要公开协作）：
   Settings → General → Danger Zone → Change visibility → Private。
   注意：**private 仓库的 GitHub Pages 需 GitHub Pro/Team 套餐**才支持，
   免费账号会失去 Pages 功能。

4. 若已申请到自定义域名，配置完成后证书会自动签发，**HTTP 访问会自动跳转到 HTTPS**。

> 说明：`master` 分支本身是公开的（仓库 public），所以从 `master` 拉取源码是仓库的固有属性，
> 无法通过 Pages 层面消除。真正的防线是**不要把真实口令写进版本库**——
> 建议把 `kb_env.sh` 里的口令改为从环境变量读取，并把 `kb_env.sh` 加入 `.gitignore`。
> 本次未改动这部分，因为它涉及本地开发脚本的口令注入方式，属于你的环境约定，需要你确认后再动。

---

## 三、如果要使用自定义域名

### 3.1 需要的前置信息

在动手前，请确认这几项（**第 1、2 项是必须的**）：

| # | 信息 | 说明 | 你需要提供 |
|---|---|---|---|
| 1 | **是否已购买域名** | 若没有，第 3 节的 DNS 步骤无法执行 | 是 / 否 |
| 2 | **域名** | 完整的域名，如 `javacourse.com` 或 `www.javacourse.com` | 域名本体 |
| 3 | **域名服务商** | 决定在哪配 DNS 记录 | 阿里云 / 腾讯云 / Cloudflare / GoDaddy… |
| 4 | **主域名还是子域名** | `example.com` 还是 `www.example.com` | 二选一 |

**GitHub 用户名与仓库名我已经确认，无需你再提供**：
- 用户名：`xyl554067-gif`
- 仓库名：`java-course-site`
- 默认地址：`https://xyl554067-gif.github.io/java-course-site/`

### 3.2 关于「根域名 vs 子域名」的取舍（建议先决策）

| 方案 | DNS 记录 | 优点 | 缺点 |
|---|---|---|---|
| **子域名**（推荐，如 `www.example.com`） | CNAME → `xyl554067-gif.github.io` | 简单、证书自动续期、不会与邮箱等其它服务冲突 | 访问时需输入 `www.` |
| **根域名**（如 `example.com`） | A 记录 → 4 个 GitHub IP | 直接访问、无 `www.` | 需配 4 条 A 记录；HTTP 验证需另加 `www` 的 CNAME；与该域名的其它服务可能冲突 |

**我的建议：用 `www.` 子域名 + CNAME 记录。** 理由是 CNAME 一条就够、验证最省事、
证书续期全自动；根域名的 A 记录方案在需要同时使用域名做邮件时容易打架。

### 3.3 操作步骤

#### 步骤 1：在仓库中添加 CNAME 文件

CNAME 是分支根目录下的一个**纯文本文件**，内容就是域名，**不带 http://、不带路径、不带末尾斜杠**。

**方式 A（推荐，脚本已支持，一条命令搞定）**

```bash
# 构建 + 部署 + 写 CNAME + 在 Pages 登记域名
bash scripts/deploy_pages.sh --domain=www.example.com
```

脚本会做三件事：把 `CNAME` 写进 gh-pages 分支根目录、调 Pages API 登记 `cname`、
打印出你需要配的 DNS 记录。

**方式 B（手工）**

在 GitHub 上直接新建文件：

1. 切到 `gh-pages` 分支：`https://github.com/xyl554067-gif/java-course-site/tree/gh-pages`
2. 点 **Add file → Create new file**
3. 文件名输入 `CNAME`（**不要加扩展名**）
4. 内容填你的域名，例如 `www.example.com`
5. 底部 **Commit changes** 直接提交到 `gh-pages` 分支

> 提示：CNAME 必须放在**发布根目录**。本项目 Pages 的发布路径是 `/`，
> 所以 CNAME 就在 `gh-pages` 分支根目录，与 `index.html` 同级。

#### 步骤 2：在 Settings → Pages 填写自定义域名

1. 打开仓库：**Settings** → 左侧 **Pages**
2. 在 **Custom domain** 输入框填入同一个域名（如 `www.example.com`）
3. 点 **Save**
4. GitHub 会提示：

   > "DNS record not detected" / "Provisionally configured"

   这是**正常的**——因为你还没配 DNS 解析。保持这个提示即可，先去做第 3 步。

5. 勾选 **Enforce HTTPS**（建议开启，证书在 DNS 生效后自动签发）

命令行等价写法（脚本已内置）：

```bash
gh api repos/xyl554067-gif/java-course-site/pages -X PUT -f "cname=www.example.com"
```

> **顺序很重要**：CNAME 文件与 Settings 里的 Custom domain **两处都要填**。
> 只有 CNAME 文件 → GitHub 不认为你配置了自定义域名；
> 只有 Settings 没 CNAME 文件 → 重新发布时该设置会被清掉。

#### 步骤 3：在域名服务商处配置 DNS 解析记录

**方案 A：子域名 + CNAME（推荐）**

| 主机记录 | 记录类型 | 记录值 | TTL |
|---|---|---|---|
| `www` | CNAME | `xyl554067-gif.github.io` | 600 或自动 |

**方案 B：根域名 + A 记录**

| 主机记录 | 记录类型 | 记录值 | TTL |
|---|---|---|---|
| `@` | A | `185.199.108.153` | 600 |
| `@` | A | `185.199.109.153` | 600 |
| `@` | A | `185.199.110.153` | 600 |
| `@` | A | `185.199.111.153` | 600 |
| `www` | CNAME | `xyl554067-gif.github.io` | 600 |

> 根域名方案里 `www` 的 CNAME 是**必需的**：GitHub 的 DNS 校验会同时检查
> 根域名的 A 记录和 `www` 的 CNAME，缺一不可。

**常见服务商的具体位置**

| 服务商 | 路径 |
|---|---|
| 阿里云 | 域名控制台 → 解析设置 → 手动解析 → 添加记录 |
| 腾讯云 | 域名注册 → 解析记录 → 添加记录 |
| Cloudflare | Select domain → DNS → Add record |
| GoDaddy | My Domains → Manage → DNS → Add record |

**注意事项**
- **务必把 Name/主机记录填成 `www` 或 `@`**，不要填完整域名（各服务商行为不同，
  填完整域名会被拼成 `www.www.example.com`）
- Cloudflare 用户请把代理状态设为 **DNS only（灰云）**。橙色代理会拦截
  GitHub 的证书签发校验，导致 HTTPS 一直转圈
- 别忘了在服务商侧把 NS 指向 GitHub？不——**不需要**。GitHub Pages 用的是
  标准的 A/CNAME 校验，不要求把 NS 托管到 GitHub

#### 步骤 4：等待生效

| 阶段 | 典型耗时 | 判断依据 |
|---|---|---|
| DNS 解析生效 | **几分钟 ~ 2 小时**（多数情况 10 分钟内） | `nslookup www.example.com` 返回上面配置的 IP |
| GitHub 校验通过 | DNS 生效后 **几分钟 ~ 1 小时** | Settings → Pages 不再显示 DNS 错误，域名旁显示绿勾 |
| HTTPS 证书签发 | 校验通过后 **几分钟 ~ 1 小时** | 浏览器访问 `https://` 不再报警 |
| 全局收敛 | **最长 24 ~ 48 小时** | 部分用户的 DNS 缓存与 CDN 边缘节点刷新完成 |

**自查命令**

```bash
# 1. DNS 是否解析到 GitHub
nslookup www.example.com
# 期望：185.199.108.153 ~ 185.199.111.153 之一

# 2. GitHub 是否已识别（cname 应显示你的域名）
gh api repos/xyl554067-gif/java-course-site/pages --jq '.cname, .protected_domain_state'

# 3. 证书是否已签发
curl -sI https://www.example.com | head -5
```

### 步骤 5：后端 API 地址要改（重要）

绑定自定义域名后，页面从 `https://xyl554067-gif.github.io/java-course-site/`
变成 `https://www.example.com/`（**根路径，不再有子路径**）。

这会影响 `config.js` 里的 `apiBase`：

| 部署形态 | `apiBase` 该填什么 |
|---|---|
| 自定义域名 + 同域反代（推荐） | `'/api'` —— Nginx 把 `/api` 反代到后端，保持当前值即可 |
| 自定义域名 + 后端独立域名 | 改成 `'https://api.example.com/api'` |
| 仍是默认 `<user>.github.io/<repo>/` | `'/api'` 会解析到 `https://<user>.github.io/api` → **必定 404** |

改法（**不需要重新构建**）：

1. 打开 https://github.com/xyl554067-gif/java-course-site/blob/gh-pages/config.js
2. 点编辑图标，直接改 `apiBase` 的值
3. Commit to `gh-pages`，**约 1 分钟内生效**

> 当前线上 `config.js` 的 `apiBase` 就是 `'/api'`，在默认子路径部署下 API 请求会 404。
> 这是上一轮遗留的已知项，等你确定后端部署位置后再定。

---

## 四、常见问题

| 现象 | 原因与处理 |
|---|---|
| Settings → Pages 一直显示 "DNS record not detected" | DNS 没配好或还没生效。先 `nslookup` 确认解析，再等 1 小时 |
| 域名能访问但样式全乱、接口 404 | `apiBase` 没配。默认子路径下 `'/api'` 必然 404，改 `config.js` |
| 页面变成 404 | CNAME 文件没放在发布根目录，或不在 `gh-pages` 分支 |
| HTTPS 证书一直失败 | Cloudflare 橙色代理没关；或 DNS 未生效 |
| 改了 `config.js` 没生效 | 硬刷新（Ctrl+F5）清 CDN 缓存 |
| 重新部署后自定义域名丢了 | CNAME 文件被覆盖了。用 `deploy_pages.sh --domain=...` 部署，或确认 CNAME 在 gh-pages 根目录 |
| 部署后旧文件还在 | 旧版本脚本传了 `base_tree`。已修复，重新部署即可清理 |

---

## 五、附：当前默认地址能做什么、不能做什么

| 能力 | 默认 `<user>.github.io/<repo>/` | 自定义域名 |
|---|---|---|
| 页面静态渲染、浏览课程内容 | ✅ 可用 | ✅ 可用 |
| 登录 / 判题 / 进度等后端接口 | ❌ 需先配 `apiBase` 指向后端 | ✅ 同域反代后可用 |
| 独立品牌域名 | ❌ | ✅ |
| 自动 HTTPS 证书 | ✅（`*.github.io`） | ✅（签发更快） |
