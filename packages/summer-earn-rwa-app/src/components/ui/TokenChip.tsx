interface TokenChipProps {
  symbol?: string
  size?: number
  className?: string
}

function gradientClass(symbol: string | undefined): string {
  const key = (symbol ?? '').toLowerCase()
  if (key === 'usdc') return 't-usdc'
  if (key === 'weth' || key === 'eth') return 't-weth'
  if (key === 'wbtc' || key === 'btc' || key === 'cbbtc') return 't-wbtc'
  if (key === 'dai') return 't-dai'
  if (key === 'link') return 't-link'
  if (key === 'arb') return 't-arb'
  return 't-unknown'
}

export function TokenChip({ symbol, size = 28, className = '' }: TokenChipProps) {
  const label = (symbol ?? '?').slice(0, 4).toUpperCase()
  return (
    <span
      className={[
        'grid place-items-center rounded-full border-2 border-[var(--surface)] font-mono text-[11px] font-bold text-[#08080C]',
        gradientClass(symbol),
        className,
      ].join(' ')}
      style={{ width: size, height: size }}
      title={symbol}
    >
      {label}
    </span>
  )
}
