/**
 * Shared class strings for form elements. Deliberately NOT components:
 * swapping a className is provably behavior-free (no wrapped refs/props),
 * which matters for the 84 inputs / 20 selects migrated in the design pass.
 */

export const inputBase =
  'w-full px-3 py-2 bg-surface-container border border-white/10 rounded-lg text-on-surface placeholder:text-on-surface-variant/50 focus:outline-none focus:border-primary/60 focus:ring-1 focus:ring-primary/40 transition-colors disabled:opacity-40 disabled:cursor-not-allowed'

export const selectBase =
  'px-3 py-2 bg-surface-container border border-white/10 rounded-lg text-on-surface focus:outline-none focus:border-primary/60 focus:ring-1 focus:ring-primary/40 transition-colors disabled:opacity-40 disabled:cursor-not-allowed'

export const labelBase = 'block text-sm font-medium text-on-surface-variant mb-1.5'

export const helpTextBase = 'mt-1.5 text-xs text-on-surface-variant/80'

export const checkboxBase =
  'h-4 w-4 rounded border-white/20 bg-surface-container text-primary focus:ring-primary/40 focus:ring-offset-0'
