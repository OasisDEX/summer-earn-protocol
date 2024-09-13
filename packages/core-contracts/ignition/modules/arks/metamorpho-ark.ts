import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * MetaMorphoArkModule for deploying the MetaMorphoArk contract
 *
 * This module deploys the MetaMorphoArk contract, which integrates with the MetaMorpho protocol.
 *
 * @param {string} strategyVault - The address of the MetaMorpho Strategy contract
 * @param {object} arkParams - An object containing the parameters for the Ark contract
 *
 * @returns {MetaMorphoArkContracts} An object containing the address of the deployed MetaMorphoArk contract
 */
export default buildModule('MetaMorphoArkModule', (m) => {
  const strategyVault = m.getParameter('strategyVault')
  const arkParams = m.getParameter('arkParams')

  const metaMorphoArk = m.contract('MetaMorphoArk', [strategyVault, arkParams])

  return { metaMorphoArk }
})

/**
 * Type definition for the returned contract address
 */
export type MetaMorphoArkContracts = {
  metaMorphoArk: { address: string }
}
