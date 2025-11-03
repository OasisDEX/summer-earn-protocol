import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Institution-scoped whitelist deployment module.
 * Deploys a minimal governance access layer and core contracts for an institution:
 * - ProtocolAccessManagerWhitelist
 * - ConfigurationManager
 * - TipJar
 * - HarborCommand
 * - Raft (kept for ConfigurationManager wiring compatibility)
 * - AdmiralsQuarters
 */
export function createInstitutionWhitelistModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const deployer = m.getAccount(0)

    // External parameters from global chain config
    const swapProvider = m.getParameter('swapProvider')
    const weth = m.getParameter('weth')
    const treasury = m.getParameter('treasury')

    // Deploy institution-scoped access manager
    const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])

    // Core infra and components
    const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])

    const configurationManager = m.contract('ConfigurationManagerWhitelist', [
      protocolAccessManager,
    ])
    const tipJar = m.contract('TipJar', [protocolAccessManager, configurationManager])

    const harborCommand = m.contract('HarborCommand', [protocolAccessManager])

    const raft = m.contract('Raft', [protocolAccessManager], {
      libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
    })

    // Initialize ConfigurationManager relations
    const configurationManagerParams = {
      raft: raft,
      tipJar: tipJar,
      treasury: treasury,
      harborCommand: harborCommand,
      // No dedicated factory for whitelist flow - we keep it for compability with core contracts
      fleetCommanderRewardsManagerFactory: '0x0000000000000000000000000000000000000000',
    }
    m.call(configurationManager, 'initializeConfiguration', [configurationManagerParams])

    // AdmiralsQuarters depends on configuration being set
    const admiralsQuarters = m.contract('AdmiralsQuartersWhitelist', [
      swapProvider,
      configurationManager,
      protocolAccessManager,
      weth,
    ])

    return {
      protocolAccessManager,
      configurationManager,
      tipJar,
      harborCommand,
      raft,
      admiralsQuarters,
    }
  })
}

export type InstitutionWhitelistContracts = {
  protocolAccessManager: { address: string }
  configurationManager: { address: string }
  tipJar: { address: string }
  harborCommand: { address: string }
  raft: { address: string }
  admiralsQuarters: { address: string }
}
