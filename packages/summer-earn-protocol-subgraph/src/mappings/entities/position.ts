import { Address, ethereum } from '@graphprotocol/graph-ts'
import { BigIntConstants } from '../../common/constants'
import { getOrCreatePosition, getOrCreateVault } from '../../common/initializers'
import { PositionDetails } from '../../types'

export function updatePosition(positionDetails: PositionDetails, block: ethereum.Block): void {
  const position = getOrCreatePosition(positionDetails.positionId, block)
  if (position) {
    position.inputTokenBalance = positionDetails.inputTokenBalance
    position.stakedInputTokenBalance = positionDetails.stakedInputTokenBalance
    position.unstakedInputTokenBalance = positionDetails.unstakedInputTokenBalance
    position.outputTokenBalance = positionDetails.outputTokenBalance
    position.stakedOutputTokenBalance = positionDetails.stakedOutputTokenBalance
    position.unstakedOutputTokenBalance = positionDetails.unstakedOutputTokenBalance
    position.inputTokenBalanceNormalized = positionDetails.inputTokenBalanceNormalized
    position.stakedInputTokenBalanceNormalized = positionDetails.stakedInputTokenBalanceNormalized
    position.unstakedInputTokenBalanceNormalized =
      positionDetails.unstakedInputTokenBalanceNormalized
    position.inputTokenBalanceNormalizedInUSD = positionDetails.inputTokenBalanceNormalizedUSD
    position.stakedInputTokenBalanceNormalizedInUSD =
      positionDetails.stakedInputTokenBalanceNormalizedUSD
    position.unstakedInputTokenBalanceNormalizedInUSD =
      positionDetails.unstakedInputTokenBalanceNormalizedUSD
    if (positionDetails.inputTokenDelta.gt(BigIntConstants.ZERO)) {
      position.inputTokenDeposits = position.inputTokenDeposits.plus(
        positionDetails.inputTokenDelta,
      )
      position.inputTokenDepositsNormalizedInUSD = position.inputTokenDepositsNormalizedInUSD.plus(
        positionDetails.inputTokenDeltaNormalizedUSD,
      )
      position.inputTokenWithdrawals = position.inputTokenWithdrawals
      position.inputTokenWithdrawalsNormalizedInUSD = position.inputTokenWithdrawalsNormalizedInUSD
    } else {
      position.inputTokenDeposits = position.inputTokenDeposits
      position.inputTokenDepositsNormalizedInUSD = position.inputTokenDepositsNormalizedInUSD
      position.inputTokenWithdrawals = position.inputTokenWithdrawals.plus(
        positionDetails.inputTokenDelta,
      )
      position.inputTokenWithdrawalsNormalizedInUSD =
        position.inputTokenWithdrawalsNormalizedInUSD.plus(
          positionDetails.inputTokenDeltaNormalizedUSD,
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
