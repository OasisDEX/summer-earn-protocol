import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('CompoundV3ArkModule', (m) => {
    const compoundV3Pool = m.getParameter('compoundV3Pool')
    const compoundV3Rewards = m.getParameter('compoundV3Rewards')
    const arkParams = m.getParameter('arkParams')

    const compoundV3Ark = m.contract('CompoundV3Ark', [compoundV3Pool, compoundV3Rewards, arkParams])

    return { compoundV3Ark }
})

export type CompoundV3ArkContracts = {
    compoundV3Ark: { address: string }
}