import { Address, ethereum } from '@graphprotocol/graph-ts'
import { BigDecimalConstants, BigIntConstants } from '../../common/constants'
import { getOrCreatePosition, getOrCreateVault } from '../../common/initializers'
import { PositionDetails } from '../../types'

export function updatePosition(positionDetails: PositionDetails, block: ethereum.Block): void {
  const position = getOrCreatePosition(positionDetails.positionId, block)
  if (position) {
    position.inputTokenBalance = positionDetails.inputTokenBalance
    position.stakedInputTokenBalance = positionDetails.stakedInputTokenBalance
    position.outputTokenBalance = positionDetails.outputTokenBalance
    position.stakedOutputTokenBalance = positionDetails.stakedOutputTokenBalance
    position.inputTokenBalanceNormalized = positionDetails.inputTokenBalanceNormalized
    position.stakedInputTokenBalanceNormalized = positionDetails.stakedInputTokenBalanceNormalized
    position.inputTokenBalanceNormalizedInUSD = positionDetails.inputTokenBalanceNormalizedUSD
    position.stakedInputTokenBalanceNormalizedInUSD =
      positionDetails.stakedInputTokenBalanceNormalizedUSD
    if (positionDetails.totalInputTokenDelta.gt(BigIntConstants.ZERO)) {
      position.inputTokenDeposits = position.inputTokenDeposits.plus(
        positionDetails.totalInputTokenDelta,
      )
      position.inputTokenDepositsNormalizedInUSD = position.inputTokenDepositsNormalizedInUSD.plus(
        positionDetails.totalInputTokenDeltaNormalizedUSD,
      )
      position.inputTokenWithdrawals = BigIntConstants.ZERO
      position.inputTokenWithdrawalsNormalizedInUSD = BigDecimalConstants.ZERO
    } else {
      position.inputTokenDeposits = BigIntConstants.ZERO
      position.inputTokenDepositsNormalizedInUSD = BigDecimalConstants.ZERO
      position.inputTokenWithdrawals = position.inputTokenWithdrawals.plus(
        positionDetails.totalInputTokenDelta,
      )
      position.inputTokenWithdrawalsNormalizedInUSD =
        position.inputTokenWithdrawalsNormalizedInUSD.plus(
          positionDetails.totalInputTokenDeltaNormalizedUSD,
        )
    }
    position.save()

    const vault = getOrCreateVault(Address.fromString(position.vault), block)
    const positions = vault.positions
    positions.push(position.id)
    vault.positions = positions
    vault.save()
  }
}
