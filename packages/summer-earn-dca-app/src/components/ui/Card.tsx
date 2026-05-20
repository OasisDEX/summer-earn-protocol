import type { HTMLAttributes } from 'react'

export function Card({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...rest}
      className={[
        'rounded-lg border border-surface-700 bg-surface-800/60 p-5 shadow-sm',
        className ?? '',
      ].join(' ')}
    />
  )
}

export function CardHeader({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...rest}
      className={['mb-3 flex items-center justify-between gap-3', className ?? ''].join(' ')}
    />
  )
}

export function CardTitle({ className, ...rest }: HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      {...rest}
      className={['font-headline text-lg font-semibold text-surface-50', className ?? ''].join(
        ' ',
      )}
    />
  )
}
