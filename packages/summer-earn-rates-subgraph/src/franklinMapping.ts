import { BigDecimal } from '@graphprotocol/graph-ts'
import { DividendDistributed } from '../generated/BenjiTransferAgent/TransferAgentModule'
import { VaultState } from '../generated/schema'
import { BigDecimalConstants, BigIntConstants } from './constants/common'

/**
 * Franklin Templeton TransferAgentModule DividendDistributed handler (BENJI / iBENJI).
 *
 * FT settles dividends per shareholder as: dividendShares = balance * abs(rate) / price
 * (see TransferAgentModule.sol _processDividends), so the daily yield fraction is
 * rate/price — price is the 1e18-scaled NAV per share, pinned at ~$1.00 for these
 * money-market funds. The rate is not stored on-chain (cannot be polled), so this
 * handler persists it on VaultState (id = the transfer-agent module address); the
 * polling block handler reads it back via FranklinDividendProduct.
 *
 * Many DividendDistributed events fire per settlement (one per account) with identical
 * rate/date/price — overwriting with the same values keeps this handler idempotent.
 */
export function handleDividendDistributed(event: DividendDistributed): void {
  const id = event.address
  let vaultState = VaultState.load(id)
  if (!vaultState) {
    vaultState = new VaultState(id)
  }
  // Daily fraction = rate/price per FT's settlement math; rate is int256, sign preserved.
  // Guard against a zero price (division by zero) with the 1e18 par-NAV fallback divisor.
  let divisor: BigDecimal
  if (event.params.price.gt(BigIntConstants.ZERO)) {
    divisor = event.params.price.toBigDecimal()
  } else {
    divisor = BigDecimalConstants.WAD
  }
  vaultState.lastRate = event.params.rate.toBigDecimal().div(divisor)
  vaultState.lastSharePrice = event.params.price.toBigDecimal().div(BigDecimalConstants.WAD)
  vaultState.lastUpdateTimestamp = event.params.date
  vaultState.save()
}
