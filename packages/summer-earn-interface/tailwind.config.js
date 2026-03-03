module.exports = {
  darkMode: 'class',
  content: [
    './src/**/*.{js,ts,jsx,tsx}',
    './pages/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#ff2e8f',
        'background-light': '#f8f5f7',
        'background-dark': '#0f070b',
        charcoal: {
          700: '#1b2130',
          800: '#1a1116',
          900: '#0f070b',
        },
        magenta: {
          500: '#ff2d8f',
          600: '#e02682',
          700: '#c01f71',
        },
        violet: {
          400: '#9b7bff',
          500: '#7c5cff',
        },
      },
      boxShadow: {
        glow: '0 0 0 2px rgba(255,45,143,0.35)',
        card: '0 0 0 1px rgba(255,255,255,0.06)',
        'neon-glow': '0 0 15px rgba(255, 46, 143, 0.3)',
      },
      borderRadius: {
        DEFAULT: '0.5rem',
        lg: '1rem',
        xl: '1rem',
        '2xl': '1.5rem',
        full: '9999px',
      },
      fontFamily: {
        display: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
