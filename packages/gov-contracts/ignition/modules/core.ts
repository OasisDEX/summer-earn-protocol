import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { ADDRESS_ZERO } from '../../scripts/common/constants'

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

  // Deploy SummerToken contract
  const summerToken = m.contract('SummerToken', [])

  // Deploy ProtocolAccessManager contract
  const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])

  // Deploy ConfigurationManager contract
  const configurationManager = m.contract('ConfigurationManager', [protocolAccessManager])

  // Deploy TipJar contract
  const tipJar = m.contract('TipJar', [protocolAccessManager, configurationManager])

  const raftAuctionDefaultParams = {
    duration: 7n * 86400n,
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n,
    decayType: DecayType.Linear,
  }

  // Deploy Raft contract with DutchAuctionLibrary as a library
  const raft = m.contract('Raft', [protocolAccessManager, raftAuctionDefaultParams], {
    libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
  })

  // Initialize the ConfigurationManager contract after all contracts have been deployed
  m.call(configurationManager, 'initialize', [treasury, raft, tipJar])

  // Deploy HarborCommand contract
  const harborCommander = m.contract('HarborCommand', [protocolAccessManager])

  // Deploy AdmiralsQuarters contract
  const admiralsQuarters = m.contract('AdmiralsQuarters', [swapProvider])

  /*
   * Deploy TimelockController contract
   * - `minDelay`: initial minimum delay in seconds for operations
   * - `proposers`: accounts to be granted proposer and canceller roles
   * - `executors`: accounts to be granted executor role
   * - `admin`: optional account to be granted admin role; disable with zero address
   */
  const timelock = m.contract('TimelockController', [
    86400,
    [deployer],
    [ADDRESS_ZERO],
    ADDRESS_ZERO,
  ])

  const summerGovernorDeployParams = {
    token: summerToken,
    timelock: timelock,
    votingDelay: 1,
    votingPeriod: 50400,
    proposalThreshold: 10000n * 10n ** 18n,
    quorumFraction: 4,
    initialWhitelistGuardian: deployer,
  }

  // Deploy SummerGovernor contract
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  const auctionDefaultParams = {
    duration: 7n * 86400n,
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n,
    decayType: DecayType.Linear,
  }

  // Deploy BuyAndBurn contract with DutchAuctionLibrary as a library
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
