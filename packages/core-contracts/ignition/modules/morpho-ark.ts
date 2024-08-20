import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * MorphoArkModule for deploying the MorphoArk contract
 *
 * This module deploys the MorphoArk contract, which integrates with the Morpho protocol.
 *
 * @param {string} morphoBlue - The address of the Morpho Blue contract
 * @param {string} marketId - The ID of the Morpho market
 * @param {object} arkParams - An object containing the parameters for the Ark contract
 *
 * @returns {MorphoArkContracts} An object containing the address of the deployed MorphoArk contract
 */
export default buildModule('MorphoArkModule', (m) => {
    const morphoBlue = m.getParameter('morphoBlue')
    const marketId = m.getParameter('marketId')
    const arkParams = m.getParameter('arkParams')

    const morphoArk = m.contract('MorphoArk', [morphoBlue, marketId, arkParams])

    return { morphoArk }
})

/**
 * Type definition for the returned contract address
 */
export type MorphoArkContracts = {
    morphoArk: { address: string }
}