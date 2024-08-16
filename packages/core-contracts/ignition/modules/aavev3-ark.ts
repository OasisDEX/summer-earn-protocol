import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('AaveV3ArkModule', (m) => {
  const aaveV3Pool = m.getParameter('aaveV3Pool')
  const rewardsController = m.getParameter('rewardsController')
  const arkParams = m.getParameter('arkParams')

  const aaveV3Ark = m.contract('AaveV3Ark', [aaveV3Pool, rewardsController, arkParams])

  return { aaveV3Ark }
})

export type AaveV3ArkContracts = {
  aaveV3Ark: { address: string }
}
