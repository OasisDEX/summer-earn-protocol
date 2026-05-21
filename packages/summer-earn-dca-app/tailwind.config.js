/** @type {import('tailwindcss').Config} */
// summer.fi design tokens — kept in sync with src/app/globals.css :root.
// Components can address tokens via either CSS vars or Tailwind classes.
module.exports = {
  content: ['./src/**/*.{ts,tsx}'],
  darkMode: ['class', '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        bg: 'var(--bg)',
        'bg-elev': 'var(--bg-elev)',
        surface: 'var(--surface)',
        'surface-2': 'var(--surface-2)',
        'surface-hover': 'var(--surface-hover)',
        border: 'var(--border)',
        'border-strong': 'var(--border-strong)',
        'border-faint': 'var(--border-faint)',
        text: 'var(--text)',
        'text-2': 'var(--text-2)',
        'text-3': 'var(--text-3)',
        'text-4': 'var(--text-4)',
        pink: {
          DEFAULT: 'var(--pink)',
          2: 'var(--pink-2)',
          dim: 'var(--pink-dim)',
        },
        violet: 'var(--violet)',
        cyan: 'var(--cyan)',
        lime: 'var(--lime)',
        success: 'var(--success)',
        warning: 'var(--warning)',
        danger: 'var(--danger)',
        info: 'var(--info)',
        // Compatibility shim for older code (CreateStrategyForm,
        // FeedPriceDisplay, Permit2ApprovalSteps) that hadn't been migrated
        // off the numbered surface palette yet. Each step is mapped to the
        // nearest design-token equivalent so the wizard renders sensibly
        // until those files are fully converted.
        'surface-50': 'var(--text)',
        'surface-100': 'var(--text)',
        'surface-200': 'var(--text-2)',
        'surface-300': 'var(--text-2)',
        'surface-400': 'var(--text-3)',
        'surface-500': 'var(--text-3)',
        'surface-600': 'var(--border-strong)',
        'surface-700': 'var(--border)',
        'surface-800': 'var(--surface)',
        'surface-900': 'var(--bg-elev)',
        primary: 'var(--pink)',
      },
      fontFamily: {
        sans: ['var(--font-sans)'],
        mono: ['var(--font-mono)'],
      },
      borderRadius: {
        xs: 'var(--r-xs)',
        sm: 'var(--r-sm)',
        md: 'var(--r-md)',
        lg: 'var(--r-lg)',
        xl: 'var(--r-xl)',
        '2xl': 'var(--r-2xl)',
        pill: 'var(--r-pill)',
      },
      boxShadow: {
        pop: 'var(--shadow-pop)',
        glow: 'var(--shadow-glow)',
      },
    },
  },
  plugins: [],
}
