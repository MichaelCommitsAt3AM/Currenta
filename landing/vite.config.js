import { defineConfig } from 'vite';
import { resolve } from 'node:path';

// Multi-page build: the marketing page plus the three legal pages, which share
// the same design system but ship almost no JS.
export default defineConfig({
  base: '/',
  build: {
    target: 'es2020',
    cssCodeSplit: true,
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        privacy: resolve(__dirname, 'privacy.html'),
        terms: resolve(__dirname, 'terms.html'),
        deleteAccount: resolve(__dirname, 'delete-account.html'),
      },
    },
  },
  server: {
    port: 5174,
    open: true,
  },
});
