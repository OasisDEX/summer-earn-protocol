import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { ERC4626 } from '../../generated/EntryPoint/ERC4626'
import { Token } from '../../generated/schema'
import { BaseVaultProduct } from './BaseVaultProduct'

export class ERC4626Product extends BaseVaultProduct {
  constructor(token: Token, poolAddress: Address, startBlock: BigInt, name: string) {
    super(token, poolAddress, startBlock, name)
  }
  getSharePrice(): BigDecimal {
    const vault = ERC4626.bind(this.poolAddress)
    const tryTotalAssets = vault.try_totalAssets()
    const tryTotalSupply = vault.try_totalSupply()

    if (tryTotalAssets.reverted || tryTotalSupply.reverted) {
      return BigDecimal.zero()
    }

    const totalAssets = tryTotalAssets.value
    const totalSupply = tryTotalSupply.value

    if (totalSupply.equals(BigInt.zero())) {
      return BigDecimal.zero()
    }

    return totalAssets.toBigDecimal().div(totalSupply.toBigDecimal())
  }
}
