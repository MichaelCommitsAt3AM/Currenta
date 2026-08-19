import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // 5173 (Vite's default) isn't in the backend's ALLOWED_ORIGINS list
    // (backend/main.py) — 3000 already is, so CORS works without touching
    // backend config.
    port: 3000,
  },
})
