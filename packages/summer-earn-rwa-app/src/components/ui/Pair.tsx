import { TokenChip } from './TokenChip'

interface PairProps {
  from?: string
  to?: string
  sub?: string
  size?: number
  className?: string
}

export function Pair({ from, to, sub, size = 28, className = '' }: PairProps) {
  return (
    <span className={['inline-flex items-center gap-2.5', className].join(' ')}>
      <span className="inline-flex">
        <TokenChip symbol={from} size={size} />
        <TokenChip symbol={to} size={size} className="-ml-2.5" />
      </span>
      <span className="text-sm font-medium text-[var(--text)]">
        {from ?? '?'}
        <span className="mx-1 text-[var(--text-3)] font-mono">→</span>
        {to ?? '?'}
      </span>
      {sub && <span className="font-mono text-xs text-[var(--text-3)]">{sub}</span>}
    </span>
  )
}
