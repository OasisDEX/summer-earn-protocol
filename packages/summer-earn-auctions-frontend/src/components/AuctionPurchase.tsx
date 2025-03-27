import { Card, CardContent } from '@/components/ui/card'
import { TokenAmount } from './TokenAmount'

interface AuctionPurchaseProps {
  purchase: {
    buyer: {
      id: string
    }
    tokensPurchasedNormalized: string
    pricePerTokenNormalized: string
    totalCostNormalized: string
    timestamp: string
    marketPriceInUSDNormalized: string
    buyPriceInUSDNormalized: string
  }
  rewardToken: {
    symbol: string
    decimals: number
  }
  buyToken: {
    symbol: string
    decimals: number
  }
}

export function AuctionPurchase({ purchase, rewardToken, buyToken }: AuctionPurchaseProps) {
  const purchaseDate = new Date(parseInt(purchase.timestamp) * 1000)
  const discount =
    ((parseFloat(purchase.marketPriceInUSDNormalized) -
      parseFloat(purchase.buyPriceInUSDNormalized)) /
      parseFloat(purchase.marketPriceInUSDNormalized)) *
    100
  const shortBuyer = purchase.buyer.id.slice(0, 6) + '...' + purchase.buyer.id.slice(-4)
  return (
    <Card className="bg-muted">
      <CardContent className="p-4">
        <div className="grid grid-cols-2 gap-4 md:grid-cols-6">
          <div>
            <div className="text-xs text-muted-foreground">Buyer</div>
            <div className="text-sm font-medium truncate">{shortBuyer}</div>
          </div>

          <div>
            <div className="text-xs text-muted-foreground">Amount</div>
            <TokenAmount
              amount={purchase.tokensPurchasedNormalized}
              symbol={rewardToken.symbol}
              decimals={rewardToken.decimals}
            />
          </div>

          <div>
            <div className="text-xs text-muted-foreground">Price per token</div>
            <div className="flex items-center gap-2">
              <TokenAmount
                amount={purchase.pricePerTokenNormalized}
                symbol={buyToken.symbol}
                decimals={buyToken.decimals}
              />

              <span className="text-xs text-green-500">({discount.toFixed(2)}% vs market)</span>
            </div>
          </div>
          <div>
            <div className="text-xs text-muted-foreground">Price per token (USD)</div>
            <div className="flex items-center gap-2">
              <TokenAmount amount={purchase.buyPriceInUSDNormalized} symbol="USD" decimals={18} />
            </div>
          </div>
          <div>
            <div className="text-xs text-muted-foreground">Market price (USD)</div>
            <div className="flex items-center gap-2">
              <TokenAmount
                amount={purchase.marketPriceInUSDNormalized}
                symbol="USD"
                decimals={18}
              />
            </div>
          </div>
          <div>
            <div className="text-xs text-muted-foreground">Total cost</div>
            <TokenAmount
              amount={purchase.totalCostNormalized}
              symbol={buyToken.symbol}
              decimals={buyToken.decimals}
            />
          </div>
        </div>
        <div className="mt-2 text-xs text-muted-foreground">{purchaseDate.toLocaleString()}</div>
      </CardContent>
    </Card>
  )
}
