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
    symbol === 'WETH'
      ? normalizedAmount.toLocaleString('en-US', {
          minimumFractionDigits: 4,
          maximumFractionDigits: 4,
        })
      : normalizedAmount.toLocaleString('en-US', {
          minimumFractionDigits: 3,
          maximumFractionDigits: 3,
        })

  const copyToClipboard = () => {
    navigator.clipboard.writeText(amount.toString())
  }

  return (
    <div className="text-sm font-medium text-gray-600">
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
