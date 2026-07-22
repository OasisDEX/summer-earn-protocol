'use client'

import { type ComponentPropsWithoutRef, type ReactNode } from 'react'

type Align = 'left' | 'right' | 'center'

const ALIGN: Record<Align, string> = {
  left: 'text-left',
  right: 'text-right',
  center: 'text-center',
}

/** The ONLY horizontal-scroll wrapper for tables. Never nest overflow containers. */
export function TableContainer({
  children,
  className = '',
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <div
      className={`overflow-x-auto rounded-xl border border-white/5 bg-white/[0.02] ${className}`}
    >
      {children}
    </div>
  )
}

export function Table({ className = '', ...rest }: ComponentPropsWithoutRef<'table'>) {
  return <table className={`w-full text-sm ${className}`} {...rest} />
}

export function THead({ className = '', ...rest }: ComponentPropsWithoutRef<'thead'>) {
  return <thead className={className} {...rest} />
}

export function TBody({ className = '', ...rest }: ComponentPropsWithoutRef<'tbody'>) {
  return <tbody className={className} {...rest} />
}

interface TrProps extends ComponentPropsWithoutRef<'tr'> {
  hover?: boolean
}

export function Tr({ hover = false, className = '', ...rest }: TrProps) {
  return (
    <tr
      className={`${hover ? 'hover:bg-white/[0.03] transition-colors' : ''} ${className}`}
      {...rest}
    />
  )
}

interface ThProps extends ComponentPropsWithoutRef<'th'> {
  align?: Align
  numeric?: boolean
}

export function Th({ align = 'left', numeric = false, className = '', ...rest }: ThProps) {
  return (
    <th
      className={`px-4 py-3 text-[11px] font-semibold uppercase tracking-wider text-on-surface-variant ${ALIGN[numeric ? 'right' : align]} ${className}`}
      {...rest}
    />
  )
}

interface TdProps extends ComponentPropsWithoutRef<'td'> {
  align?: Align
  /** right-aligned tabular figures — use for every numeric column */
  numeric?: boolean
}

export function Td({ align = 'left', numeric = false, className = '', ...rest }: TdProps) {
  return (
    <td
      className={`px-4 py-3 border-t border-white/5 ${numeric ? 'text-right tabular-nums' : ALIGN[align]} ${className}`}
      {...rest}
    />
  )
}
