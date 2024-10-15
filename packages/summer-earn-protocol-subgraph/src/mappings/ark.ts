import { Ark as ArkContract } from '../../generated/HarborCommand/Ark'
import { Boarded, Disembarked } from '../../generated/templates/FleetCommanderTemplate/Ark'
import { getOrCreateArk } from '../common/initializers'
import { handleBoard, handleDisembark } from './entities/ark'

export function handleBoarded(event: Boarded): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)

  if (ark) {
    handleBoard(event.params.amount, ark)
  }
}

export function handleDisembarked(event: Disembarked): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)
  if (ark) {
    handleDisembark(event.params.amount, ark)
  }
}
