import { Address, ethereum } from '@graphprotocol/graph-ts'
import { Ark as ArkContract } from '../../../generated/templates/FleetCommanderTemplate/Ark'
import { BigDecimalConstants } from '../../common/constants'
import { getOrCreateArk } from '../../common/initializers'
import { ArkDetails } from '../../types'

export function updateArk(arkDetails: ArkDetails, block: ethereum.Block): void {
  const arkAddress = Address.fromString(arkDetails.arkId)
  const vaultAddress = Address.fromString(arkDetails.vaultId)
  const ark = getOrCreateArk(vaultAddress, arkAddress, block)

  const arkContract = ArkContract.bind(arkAddress)
  const totalAssets = arkContract.totalAssets()
  const rate = arkContract.rate()
  ark.inputTokenBalance = totalAssets
  ark.apr = rate.toBigDecimal().div(BigDecimalConstants.RAY).times(BigDecimalConstants.HUNDRED)
  ark.totalValueLockedUSD = arkDetails.totalValueLockedUSD
  ark.lastUpdateTimestamp = block.timestamp

  ark.save()
}
