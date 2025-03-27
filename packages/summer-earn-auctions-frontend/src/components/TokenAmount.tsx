interface TokenAmountProps {
  amount: string
  symbol: string
  decimals: number
}

export function TokenAmount({ amount, symbol }: TokenAmountProps) {
  const formattedAmount = symbol == 'WETH' ? Number(amount).toFixed(4) : Number(amount).toFixed(2)
  return (
    <div className="text-sm font-medium">
      {formattedAmount} {symbol}
    </div>
  )
}
