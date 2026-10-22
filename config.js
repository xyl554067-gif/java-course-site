/**
 * 运行时配置（GitHub Pages 部署用）
 *
 * 作用：GitHub Pages 只托管静态文件，后端 API 部署在别处。这个文件让运维
 * 可以在不重新构建前端的前提下，改写后端地址 —— 直接在 GitHub 上编辑
 * gh-pages 分支的 config.js 即可生效（无需重新跑构建）。
 *
 * Pages 默认子路径部署需要使用完整后端地址。
 */
window.__APP_CONFIG__ = {
  apiBase: 'https://java-course-api-0sl8.onrender.com/api',
}
