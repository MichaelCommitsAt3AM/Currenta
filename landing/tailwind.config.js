/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './privacy.html', './terms.html', './delete-account.html', './src/**/*.{js,ts}'],
  theme: {
    extend: {
      colors: {
        moss: {
          DEFAULT: '#2E4036',
          deep: '#1E2B24',
          light: '#3C5647',
          faint: '#5A6E62',
        },
        clay: {
          DEFAULT: '#CC5833',
          light: '#E0794F',
          dark: '#A8431F',
        },
        cream: {
          DEFAULT: '#F2F0E9',
          dark: '#E6E2D5',
          deep: '#DAD5C4',
        },
        charcoal: {
          DEFAULT: '#1A1A1A',
          light: '#262625',
          soft: '#3A3A38',
        },
      },
      fontFamily: {
        sans: ['"Plus Jakarta Sans Variable"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        display: ['"Outfit Variable"', '"Plus Jakarta Sans Variable"', 'ui-sans-serif', 'sans-serif'],
        serif: ['"Cormorant Garamond"', 'Georgia', 'Cambria', '"Times New Roman"', 'serif'],
        mono: ['"JetBrains Mono Variable"', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
      },
      letterSpacing: {
        tightest: '-0.045em',
        tighter2: '-0.03em',
      },
      borderRadius: {
        '2xl': '2rem',
        '3xl': '3rem',
        '4xl': '4rem',
      },
      maxWidth: {
        shell: '78rem',
      },
      transitionTimingFunction: {
        spring: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
      },
      keyframes: {
        'pulse-dot': {
          '0%, 100%': { opacity: '1', transform: 'scale(1)' },
          '50%': { opacity: '0.4', transform: 'scale(0.82)' },
        },
        blink: {
          '0%, 49%': { opacity: '1' },
          '50%, 100%': { opacity: '0' },
        },
      },
      animation: {
        'pulse-dot': 'pulse-dot 1.8s ease-in-out infinite',
        blink: 'blink 1s step-end infinite',
      },
    },
  },
  plugins: [],
};
