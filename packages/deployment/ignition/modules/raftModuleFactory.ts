import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an RaftModule for deploying the Raft contract
 *
 * This function creates a module that deploys the Raft contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createRaftModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const protocolAccessManager = m.getParameter('protocolAccessManager')
    const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])
    const raft = m.contract('Raft', [protocolAccessManager], {
      libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
    })

    return { raft }
  })
}

// Legacy export for backward compatibility
export const RaftModule = createRaftModule('RaftModule')

/**
 * Type definition for the returned contract address
 */
export type RaftContract = {
  raft: { address: string }
}
