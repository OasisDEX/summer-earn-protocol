interface TokenAmountProps {
  amount: string
  symbol: string
  decimals?: number
}

export function TokenAmount({ amount, symbol, decimals }: TokenAmountProps) {
  const decimalsDefined = decimals !== undefined
  const normalizedAmount = decimalsDefined
    ? Number(amount) / Math.pow(10, decimals)
    : Number(amount)
  const formattedAmount =
    symbol === 'WETH' ? normalizedAmount.toFixed(4) : normalizedAmount.toFixed(3)

  const copyToClipboard = () => {
    navigator.clipboard.writeText(amount.toString())
  }

  return (
    <div className="text-sm font-medium">
      <button
        onClick={copyToClipboard}
        className="hover:text-blue-600 transition-colors cursor-pointer"
        title="Click to copy raw amount"
      >
        {formattedAmount}
      </button>{' '}
      {symbol}
    </div>
  )
}
