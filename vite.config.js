import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  base: '/proyecto_casablanca/',
  server: {
    proxy: {
      '/proyecto_casablanca/api': {
        target: 'http://127.0.0.1:3001',
        changeOrigin: true,
        rewrite: (ruta) => ruta.replace(/^\/proyecto_casablanca/, ''),
      },
    },
  },
})
