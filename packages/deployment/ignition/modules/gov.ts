import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { ADDRESS_ZERO } from '../../scripts/common/constants'

enum DecayType {
  Linear,
  Exponential,
}

export const GovModule = buildModule('GovModule', (m) => {
  const deployer = m.getAccount(0)
  const lzEndpoint = m.getParameter('lzEndpoint')

  const summerTokenParams = {
    name: 'SummerToken',
    symbol: 'SUMMER',
    lzEndpoint: lzEndpoint,
    governor: deployer,
  }
  // Deploy SummerToken contract
  const summerToken = m.contract('SummerToken', [summerTokenParams])

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

  /*
   * @dev Struct for the governor parameters
   * @param token The token contract address
   * @param timelock The timelock controller contract address
   * @param votingDelay The voting delay in seconds
   * @param votingPeriod The voting period in seconds
   * @param proposalThreshold The proposal threshold in tokens
   * @param quorumFraction The quorum fraction in tokens
   * @param initialWhitelistGuardian The initial whitelist guardian address
   * @param initialDecayFreeWindow The initial decay free window in seconds
   * @param initialDecayRate The initial decay rate
   * @param initialDecayFunction The initial decay function
   * @param endpoint The LayerZero endpoint address
   * @param proposalChainId The proposal chain ID
   */
  const summerGovernorDeployParams = {
    token: summerToken,
    timelock: timelock,
    votingDelay: 1,
    votingPeriod: 50400,
    proposalThreshold: 10000n * 10n ** 18n,
    quorumFraction: 4,
    initialWhitelistGuardian: deployer,
    initialDecayFreeWindow: 30n * 24n * 60n * 60n,
    initialDecayRate: 3.1709792e9,
    initialDecayFunction: DecayType.Linear,
    endpoint: lzEndpoint,
    proposalChainId: 8453,
  }

  // Deploy SummerGovernor contract
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  // Set the SummerGovernor as the governor of the SummerToken
  m.call(summerToken, 'setGovernor', [summerGovernor.value])
  m.call(summerToken, 'transferOwnership', [summerGovernor.value])

  return {
    summerGovernor,
    summerToken,
    timelock,
  }
})

export type GovContracts = {
  summerGovernor: { address: string }
  summerToken: { address: string }
  timelock: { address: string }
}
