/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#89acff',
          50: '#eaf1ff',
          100: '#d5e3ff',
          200: '#aac6ff',
          300: '#89acff',
          400: '#5e8bff',
          500: '#3b6dff',
          600: '#2451d6',
          700: '#1a3ea4',
          800: '#132d78',
          900: '#0d2057',
        },
        surface: {
          50: '#f7f8fb',
          100: '#eef0f7',
          200: '#d9deeb',
          300: '#b9c1d4',
          400: '#8590a8',
          500: '#5b6479',
          600: '#3e4659',
          700: '#2a3041',
          800: '#1a1f2c',
          900: '#0e121b',
        },
        success: '#1fb47a',
        warning: '#f5a623',
        danger: '#e5484d',
      },
      fontFamily: {
        display: ['Inter', 'system-ui', 'sans-serif'],
        headline: ['Manrope', 'Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
