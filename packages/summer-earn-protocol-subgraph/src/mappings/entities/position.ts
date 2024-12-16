import { Address, ethereum } from '@graphprotocol/graph-ts'
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
    position.save()

    const vault = getOrCreateVault(Address.fromString(position.vault), block)
    const positions = vault.positions
    positions.push(position.id)
    vault.positions = positions
    vault.save()
  }
}
