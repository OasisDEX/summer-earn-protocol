import { ethereum } from '@graphprotocol/graph-ts'
import { getOrCreatePosition } from '../../common/initializers'
import { PositionDetails } from '../../types'

export function updatePosition(positionDetails: PositionDetails, block: ethereum.Block): void {
  const position = getOrCreatePosition(positionDetails.positionId, block)
  if (position) {
    position.inputTokenBalance = positionDetails.inputTokenBalance
    position.outputTokenBalance = positionDetails.outputTokenBalance
    position.inputTokenBalanceNormalized = positionDetails.inputTokenBalanceNormalized
    position.inputTokenBalanceNormalizedInUSD = positionDetails.inputTokenBalanceNormalizedUSD
    position.save()
  }
}
