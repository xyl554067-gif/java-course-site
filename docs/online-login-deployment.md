# 在线登录部署

GitHub Pages 只托管前端静态文件，不能执行登录 API。在线登录需要一个可访问的 Spring Boot 服务和数据库。本仓库提供 Render 后端配置，并保留 Kingbase 本地开发方式。

## 部署步骤

### 1. 创建 PostgreSQL 数据库

在 Supabase 创建项目，在 SQL Editor 中依次运行：

1. `backend/src/main/resources/db/schema-postgresql.sql`
2. `backend/src/main/resources/db/seed-postgresql.sql`

课程种子数据不创建默认账号。部署后从注册页面创建自己的账号。

### 2. 部署 API

在 Render 选择 **New → Blueprint** 并连接本仓库，按 `render.yaml` 创建 `java-course-api`。设置以下环境变量：

| 变量 | 值 |
| --- | --- |
| `DB_DRIVER` | `org.postgresql.Driver`（Blueprint 已设置） |
| `DB_URL` | `jdbc:postgresql://<Supabase-host>:5432/postgres?sslmode=require` |
| `DB_USER` | Supabase 数据库用户名，通常为 `postgres` |
| `DB_PASSWORD` | Supabase 数据库密码 |
| `APP_JWT_SECRET` | Render 自动生成，保持私密 |
| `AI_PROVIDER` | `local`（默认不需要 AI Key） |

若 Supabase 提供的直连地址无法从 Render 访问，请在 Supabase 的 Database → Connect 选择 Session pooler，并将主机、端口和用户名换成该页面提供的值。不要把数据库口令或 JWT 密钥提交到 Git。

部署健康检查通过后，API 地址形如 `https://java-course-api.onrender.com`，可访问 `/api/health` 检查数据库连接状态。

### 3. 连接 GitHub Pages 前端

在 `gh-pages` 分支根目录编辑 `config.js`，把 `apiBase` 改成 Render 提供的真实 API 地址，例如：

```js
window.__APP_CONFIG__ = {
  apiBase: 'https://java-course-api.onrender.com/api',
}
```

保存后等待 Pages 更新，再打开在线站点注册账号并登录。前端通过 HTTPS 请求 API；后端已允许跨域请求。

## 免费套餐的限制

- Render 免费 Web 服务连续 15 分钟无请求会休眠；下一次请求可能需要约一分钟唤醒。
- Supabase 免费项目在连续 7 天低活跃后可能暂停，需要到控制台恢复。
- 这适合演示和低频使用。若要稳定供多人使用，应配置数据库备份和付费常驻服务。

