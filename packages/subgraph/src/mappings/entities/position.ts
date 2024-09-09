import { ethereum } from '@graphprotocol/graph-ts'
import { getOrCreatePosition } from '../../common/initializers'
import { PositionDetails } from '../../types'

export function updatePosition(positionDetails: PositionDetails, block: ethereum.Block): void {
  const position = getOrCreatePosition(positionDetails.positionId, block)
  if (position) {
    position.inputTokenBalance = positionDetails.outputTokenBalance
    position.outputTokenBalance = positionDetails.inputTokenBalance
    position.outputTokenBalanceNormalized = positionDetails.inputTokenBalanceNormalized
    position.outputTokenBalanceNormalizedInUSD = positionDetails.inputTokenBalanceNormalizedUSD
    position.save()
  }
}
