module.exports = {
  content: [
    './src/**/*.{js,ts,jsx,tsx}',
    './pages/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        charcoal: {
          900: '#0f1115',
          800: '#141821',
          700: '#1b2130',
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
      },
      borderRadius: {
        xl: '14px',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
