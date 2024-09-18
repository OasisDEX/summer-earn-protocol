import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

enum DecayType {
  Linear,
  Exponential,
}

export const CoreModule = buildModule('CoreModule', (m) => {
  const deployer = m.getAccount(0)
  const treasury = m.getParameter('treasury')
  const swapProvider = m.getParameter('swapProvider')
  const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])
  const summerToken = m.contract('SummerToken', [])

  const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])

  const tipJar = m.contract('TipJar', [protocolAccessManager, treasury])
  const raftAuctionDefaultParams = {
    duration: 7n * 86400n,
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n,
    decayType: DecayType.Linear,
  }
  const raft = m.contract('Raft', [protocolAccessManager, raftAuctionDefaultParams], {
    libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
  })

  const configurationManager = m.contract('ConfigurationManager', [
    { accessManager: protocolAccessManager, raft, tipJar },
  ])

  const harborCommander = m.contract('HarborCommand', [protocolAccessManager])

  const admiralsQuarters = m.contract('AdmiralsQuarters', [swapProvider])

  const timelock = m.contract('TimelockController', [86400, [deployer], [deployer], deployer])
  const summerGovernorDeployParams = {
    token: summerToken,
    timelock: timelock,
    votingDelay: 1,
    votingPeriod: 50400,
    proposalThreshold: 10000n * 10n ** 18n,
    quorumFraction: 4,
    initialWhitelistGuardian: deployer,
  }
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  const auctionDefaultParams = {
    duration: 7n * 86400n,
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n,
    decayType: DecayType.Linear,
  }

  const buyAndBurn = m.contract(
    'BuyAndBurn',
    [summerToken, treasury, protocolAccessManager, auctionDefaultParams],
    {
      libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
    },
  )
  return {
    protocolAccessManager,
    tipJar,
    raft,
    configurationManager,
    harborCommander,
    admiralsQuarters,
    summerGovernor,
    buyAndBurn,
  }
})
