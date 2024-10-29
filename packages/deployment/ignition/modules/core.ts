import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

enum DecayType {
  Linear,
  Exponential,
}

export const CoreModule = buildModule('CoreModule', (m) => {
  const deployer = m.getAccount(0)
  const treasury = m.getParameter('treasury')
  const swapProvider = m.getParameter('swapProvider')

  // Deploy DutchAuctionLibrary contract
  const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])

  // Deploy ProtocolAccessManager contract
  const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])

  // Deploy ConfigurationManager contract
  const configurationManager = m.contract('ConfigurationManager', [protocolAccessManager])

  // Deploy TipJar contract
  const tipJar = m.contract('TipJar', [protocolAccessManager, configurationManager])

  // Deploy GovernanceRewardsManager contract
  // In an uninitialized state
  // We initialize it in the GovModule with SummerToken
  const governanceRewardsManager = m.contract('GovernanceRewardsManager', [protocolAccessManager])

  const raftAuctionDefaultParams = {
    duration: 7n * 86400n,
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n,
    decayType: DecayType.Linear,
  }

  // Deploy HarborCommand contract
  const harborCommand = m.contract('HarborCommand', [protocolAccessManager])

  // Deploy Raft contract with DutchAuctionLibrary as a library
  const raft = m.contract('Raft', [protocolAccessManager, raftAuctionDefaultParams], {
    libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
  })

  const configurationManagerParams = {
    raft: raft,
    tipJar: tipJar,
    treasury: treasury,
    harborCommand: harborCommand,
  }

  // Initialize the ConfigurationManager contract after all contracts have been deployed
  m.call(configurationManager, 'initializeConfiguration', [configurationManagerParams])

  // Deploy AdmiralsQuarters contract
  const admiralsQuarters = m.contract('AdmiralsQuarters', [swapProvider])

  return {
    protocolAccessManager,
    tipJar,
    raft,
    configurationManager,
    harborCommand,
    admiralsQuarters,
    governanceRewardsManager,
  }
})

export type CoreContracts = {
  protocolAccessManager: { address: string }
  tipJar: { address: string }
  raft: { address: string }
  configurationManager: { address: string }
  harborCommand: { address: string }
  admiralsQuarters: { address: string }
}
