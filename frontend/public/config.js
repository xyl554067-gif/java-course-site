/**
 * 运行时配置（GitHub Pages 部署用）
 *
 * 作用：GitHub Pages 只托管静态文件，后端 API 部署在别处。这个文件让运维
 * 可以在不重新构建前端的前提下，改写后端地址 —— 直接在 GitHub 上编辑
 * gh-pages 分支的 config.js 即可生效（无需重新跑构建）。
 *
 * apiBase 取值：
 *   '/api'        → 与页面同源，走 /api（自定义域名 + 同域反代时用）
 *   'https://...' → 独立后端地址（Pages 默认子路径部署时用）
 *
 * ⚠️ Pages 默认子路径（https://<user>.github.io/<repo>/）下，'/api' 会解析到
 *    域名根（https://<user>.github.io/api），必定 404。请把这里改成后端的
 *    完整地址，例如 'https://your-api.example.com/api'。
 *
 * 未配置/不可用时，页面仍能正常渲染（静态外壳 + 登录页），只是数据接口不可用。
 */
window.__APP_CONFIG__ = {
  apiBase: '/api',
}
