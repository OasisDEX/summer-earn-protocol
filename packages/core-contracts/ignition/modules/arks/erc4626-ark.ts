import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * ERC4626ArkModule for deploying the ERC4626Ark contract
 *
 * This module deploys the ERC4626Ark contract, which integrates with any ERC4626-compliant vault.
 *
 * @param {string} vault - The address of the ERC4626-compliant vault
 * @param {object} arkParams - An object containing the parameters for the Ark contract
 *
 * @returns {ERC4626ArkContracts} An object containing the address of the deployed ERC4626Ark contract
 */
export default buildModule('ERC4626ArkModule', (m) => {
  const vault = m.getParameter('vault')
  const arkParams = m.getParameter('arkParams')

  const erc4626Ark = m.contract('ERC4626Ark', [vault, arkParams])

  return { erc4626Ark }
})

/**
 * Type definition for the returned contract address
 */
export type ERC4626ArkContracts = {
  erc4626Ark: { address: string }
}
