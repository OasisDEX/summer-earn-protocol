import type { HTMLAttributes } from 'react'

export function Card({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...rest}
      className={[
        'rounded-lg border border-[var(--border-faint)] bg-[var(--surface)] p-6',
        className ?? '',
      ].join(' ')}
    />
  )
}

export function CardHeader({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...rest}
      className={['mb-4 flex items-center justify-between gap-3', className ?? ''].join(' ')}
    />
  )
}

export function CardTitle({ className, ...rest }: HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      {...rest}
      className={['text-[15px] font-semibold text-[var(--text)] m-0', className ?? ''].join(' ')}
    />
  )
}

export function CardSub({ className, ...rest }: HTMLAttributes<HTMLParagraphElement>) {
  return (
    <p
      {...rest}
      className={[
        'mt-0.5 text-xs text-[var(--text-3)] m-0 font-[var(--font-mono)]',
        className ?? '',
      ].join(' ')}
    />
  )
}
