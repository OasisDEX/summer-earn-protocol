import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export interface AaveV3CarryTradeArkContracts {
  aaveV3CarryTradeArk: {
    address: Address
  }
}

export function createAaveV3CarryTradeArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const lendingPool = m.getParameter('lendingPool')
    const borrowedAsset = m.getParameter('borrowedAsset')
    const yieldVault = m.getParameter('yieldVault')
    const arkParams = m.getParameter('arkParams')

    const aaveV3CarryTradeArk = m.contract('AaveV3CarryTradeArk', [
      lendingPool,
      borrowedAsset,
      yieldVault,
      arkParams,
    ])

    return {
      aaveV3CarryTradeArk,
    }
  })
}
