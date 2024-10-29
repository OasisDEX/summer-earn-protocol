import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { keccak256, toBytes } from 'viem'
import { ADDRESS_ZERO } from '../../scripts/common/constants'

enum DecayType {
  Linear,
  Exponential,
}

const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000'
const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))
const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))

export const GovModule = buildModule('GovModule', (m) => {
  const deployer = m.getAccount(0)
  const lzEndpoint = m.getParameter('lzEndpoint')
  const rewardsManagerAddress = m.getParameter('rewardsManager')
  const protocolAccessManagerAddress = m.getParameter('protocolAccessManager')

  const summerTokenParams = {
    name: 'SummerToken',
    symbol: 'SUMMER',
    lzEndpoint: lzEndpoint,
    governor: deployer,
    owner: deployer,
    rewardsManager: rewardsManagerAddress,
    // 30 days
    initialDecayFreeWindow: 30n * 24n * 60n * 60n,
    // ~10% per year
    initialDecayRate: 3.1709792e9,
    initialDecayFunction: DecayType.Linear,
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
  const MIN_DELAY = 86400
  const TEMP_MIN_DELAY_DURING_TESTING = MIN_DELAY / 24
  const timelock = m.contract('TimelockController', [
    TEMP_MIN_DELAY_DURING_TESTING,
    [deployer],
    [ADDRESS_ZERO],
    deployer,
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
    votingPeriod: 10000, // TODO: Change from block clock to timestamp
    proposalThreshold: 10000n * 10n ** 18n,
    quorumFraction: 4,
    initialWhitelistGuardian: deployer,
    endpoint: lzEndpoint,
    proposalChainId: 8453,
  }

  // Deploy SummerGovernor contract
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  // Set the SummerGovernor as the governor of the SummerToken
  m.call(summerToken, 'setGovernor', [summerGovernor.value])

  // Set the TimelockController as the owner of the SummerToken
  // For actions like minting
  m.call(summerToken, 'transferOwnership', [timelock.value])

  // Grant roles to the SummerGovernor
  m.call(timelock, 'grantRole', [PROPOSER_ROLE, summerGovernor.value])
  m.call(timelock, 'grantRole', [CANCELLER_ROLE, summerGovernor.value])
  m.call(timelock, 'grantRole', [EXECUTOR_ROLE, summerGovernor.value])

  // Grant ROLES back to the TimelockController itself
  const protocolAccessManager = m.contractAt('ProtocolAccessManager', protocolAccessManagerAddress)

  // The DEFAULT_ADMIN_ROLE is given to deployer on initial deployment
  m.call(protocolAccessManager, 'revokeRole', [DEFAULT_ADMIN_ROLE, deployer])

  // Need to grant GOVERNOR_ROLE & DEFAULT_ADMIN_ROLE roles to TimelockController
  m.call(protocolAccessManager, 'grantRole', [DEFAULT_ADMIN_ROLE, timelock.value])
  m.call(protocolAccessManager, 'grantRole', [GOVERNOR_ROLE, timelock.value])

  // Revoke PROPOSER_ROLE from deployer
  m.call(timelock, 'revokeRole', [PROPOSER_ROLE, deployer])

  const governanceRewardsManager = m.contractAt('GovernanceRewardsManager', rewardsManagerAddress)
  m.call(governanceRewardsManager, 'initialize', [summerToken.value])

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
