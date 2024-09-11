import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const LibrariesModule = buildModule('LibrariesModule', (m) => {
  const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])
  return { dutchAuctionLibrary }
})

export const TokenModule = buildModule('TokenModule', (m) => {
  const summerToken = m.contract('SummerToken', [])
  return { summerToken }
})

export const AccessModule = buildModule('AccessModule', (m) => {
  const deployer = m.getAccount(0)
  const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])
  return { protocolAccessManager }
})

export const TreasuryModule = buildModule('TreasuryModule', (m) => {
  const { protocolAccessManager } = m.useModule(AccessModule)
  const treasury = m.getParameter('treasury')
  const tipJar = m.contract('TipJar', [protocolAccessManager, treasury])
  return { tipJar }
})

export const RaftModule = buildModule('RaftModule', (m) => {
  const { protocolAccessManager } = m.useModule(AccessModule)
  const { dutchAuctionLibrary } = m.useModule(LibrariesModule)
  const raftAuctionDefaultParams = {
    duration: 7 * 86400,
    startPrice: 100e18,
    endPrice: 10e18,
    kickerRewardPercentage: 0,
    decayType: 'Exponential',
  }
  const raft = m.contract('Raft', [protocolAccessManager, raftAuctionDefaultParams], {
    libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
  })
  return { raft }
})

export const ConfigModule = buildModule('ConfigModule', (m) => {
  const { protocolAccessManager } = m.useModule(AccessModule)
  const { raft } = m.useModule(RaftModule)
  const { tipJar } = m.useModule(TreasuryModule)
  const configurationManager = m.contract('ConfigurationManager', [
    { accessManager: protocolAccessManager, raft, tipJar },
  ])
  return { configurationManager }
})

export const CommandModule = buildModule('CommandModule', (m) => {
  const { protocolAccessManager } = m.useModule(AccessModule)
  const harborCommander = m.contract('HarborCommand', [protocolAccessManager])
  return { harborCommander }
})

export const AdmiralsModule = buildModule('AdmiralsModule', (m) => {
  const swapProvider = m.getParameter('swapProvider')
  const admiralsQuarters = m.contract('AdmiralsQuarters', [swapProvider])
  return { admiralsQuarters }
})

export const GovernanceModule = buildModule('GovernanceModule', (m) => {
  const deployer = m.getAccount(0)
  const { summerToken } = m.useModule(TokenModule)
  const timelock = m.contract('TimelockController', [86400, [deployer], [deployer], deployer])
  const summerGovernorDeployParams = {
    token: summerToken,
    timelock: timelock,
    votingDelay: 1,
    votingPeriod: 50400,
    proposalThreshold: 10000e18,
    quorumFraction: 4,
    initialWhitelistGuardian: deployer,
  }
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])
  return { summerGovernor }
})

export const BuyAndBurnModule = buildModule('BuyAndBurnModule', (m) => {
  const { summerToken } = m.useModule(TokenModule)
  const { protocolAccessManager } = m.useModule(AccessModule)
  const { dutchAuctionLibrary } = m.useModule(LibrariesModule)
  const treasury = m.getParameter('treasury')
  const auctionDefaultParams = {
    duration: 7 * 86400,
    startPrice: 100e18,
    endPrice: 10e18,
    kickerRewardPercentage: 0,
    decayType: 'Linear',
  }
  const buyAndBurn = m.contract(
    'BuyAndBurn',
    [summerToken, treasury, protocolAccessManager, auctionDefaultParams],
    {
      libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
    },
  )
  return { buyAndBurn }
})
