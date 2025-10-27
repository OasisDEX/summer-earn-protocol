import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a StargateV2PoolArkModule for deploying the StargateV2PoolArk contract
 *
 * This function creates a module that deploys the StargateV2PoolArk contract, which integrates with the Stargate V2 protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createStargateV2PoolArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const stargatePool = m.getParameter('stargatePool')
    const stargateStaking = m.getParameter('stargateStaking')
    const weth = m.getParameter('weth')
    const arkParams = m.getParameter('arkParams')

    const stargateV2PoolArk = m.contract('StargateV2PoolArk', [
      stargatePool,
      stargateStaking,
      weth,
      arkParams,
    ])

    return { stargateV2PoolArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type StargateV2PoolArkContracts = {
  stargateV2PoolArk: { address: string }
}
