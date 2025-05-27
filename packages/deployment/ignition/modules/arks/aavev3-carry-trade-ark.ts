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
    const rewardsController = m.getParameter('rewardsController')
    const poolAddressesProvider = m.getParameter('poolAddressesProvider')
    const arkParams = m.getParameter('arkParams')
    const maxLtv = m.getParameter('maxLtv')
    const slippage = m.getParameter('slippage')

    const aaveV3CarryTradeArk = m.contract('AaveV3CarryTradeArk', [
      lendingPool,
      rewardsController,
      poolAddressesProvider,
      borrowedAsset,
      yieldVault,
      maxLtv,
      slippage,
      arkParams,
    ])

    return {
      aaveV3CarryTradeArk,
    }
  })
}
