import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig(({ mode }) => {
  // GitHub Pages 部署在子路径下时（如 <user>.github.io/<repo>/）需要相对基址；
  // 自定义域名指向根路径时用 '/'。
  const isPages = mode === 'pages'

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      }
    },
    base: isPages ? './' : '/',
    server: {
      port: 5173,
      proxy: {
        '/api': {
          target: 'http://127.0.0.1:8080',
          changeOrigin: true
        }
      }
    },
    build: {
      outDir: 'dist',
      chunkSizeWarningLimit: 1200
    }
  }
})
