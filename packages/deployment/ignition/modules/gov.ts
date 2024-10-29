import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { keccak256, toBytes } from 'viem'
import { ADDRESS_ZERO } from '../../scripts/common/constants'

/**
 * @dev Enum representing different types of voting power decay functions
 */
enum DecayType {
  Linear,
  Exponential,
}

/**
 * @dev Constants for various roles used in access control
 * DEFAULT_ADMIN_ROLE - Has full administrative privileges
 * GOVERNOR_ROLE - Can execute governance actions
 * PROPOSER_ROLE - Can propose timelock operations
 * EXECUTOR_ROLE - Can execute timelock operations
 * CANCELLER_ROLE - Can cancel timelock operations
 */
const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000'
const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))
const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))

/**
 * @title Governance Module Deployment Script
 * @notice This module handles the deployment and initialization of the governance system
 *
 * @dev Deployment and initialization sequence:
 * 1. Deploy SummerToken (governance token)
 * 2. Deploy TimelockController (timelock for governance actions)
 * 3. Deploy SummerGovernor (governance logic)
 * 4. Configure contract relationships and permissions
 *
 * Post-deployment security considerations:
 * - The deployer initially has admin rights but transfers them to the TimelockController
 * - The TimelockController becomes the ultimate owner of the system
 * - The SummerGovernor can only execute actions through the TimelockController
 */
export const GovModule = buildModule('GovModule', (m) => {
  const deployer = m.getAccount(0)
  const lzEndpoint = m.getParameter('lzEndpoint')
  const rewardsManagerAddress = m.getParameter('rewardsManager')
  const protocolAccessManagerAddress = m.getParameter('protocolAccessManager')

  /**
   * @dev Step 1: Deploy SummerToken
   * Initially, the deployer is set as both governor and owner
   * - governor: Controls voting power calculations
   * - owner: Controls administrative functions (e.g., minting)
   * These roles will be transferred to appropriate contracts later
   */
  const summerTokenParams = {
    name: 'SummerToken',
    symbol: 'SUMMER',
    lzEndpoint: lzEndpoint,
    governor: deployer,
    owner: deployer,
    rewardsManager: rewardsManagerAddress,
    initialDecayFreeWindow: 30n * 24n * 60n * 60n, // 30 days
    initialDecayRate: 3.1709792e9, // ~10% per year
    initialDecayFunction: DecayType.Linear,
  }
  const summerToken = m.contract('SummerToken', [summerTokenParams])

  /**
   * @dev Step 2: Deploy TimelockController
   * This contract adds a time delay to governance actions
   * Initially configured with:
   * - deployer as proposer (temporary)
   * - ADDRESS_ZERO as executor (anyone can execute)
   * - deployer as admin (temporary)
   */
  const MIN_DELAY = 86400
  const TEMP_MIN_DELAY_DURING_TESTING = MIN_DELAY / 24
  const timelock = m.contract('TimelockController', [
    TEMP_MIN_DELAY_DURING_TESTING,
    [deployer],
    [ADDRESS_ZERO],
    deployer,
  ])

  /**
   * @dev Step 3: Deploy SummerGovernor
   * This contract manages the governance process
   * Links to both SummerToken (for voting power) and TimelockController (for execution)
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
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  /**
   * @dev Step 4: Post-deployment configuration
   *
   * Security considerations for the configuration sequence:
   * 1. Set SummerGovernor as the governor of SummerToken
   *    - This allows the governance contract to manage voting power
   *
   * 2. Transfer SummerToken ownership to TimelockController
   *    - This ensures administrative actions (like minting) must go through governance
   *
   * 3. Grant necessary roles to SummerGovernor in TimelockController
   *    - Allows the governor to propose, cancel, and execute actions
   *
   * 4. Configure ProtocolAccessManager permissions
   *    - Revoke deployer's admin rights
   *    - Grant admin and governor roles to TimelockController
   *
   * 5. Revoke temporary permissions
   *    - Remove deployer's proposer role from TimelockController
   *
   * 6. Initialize the rewards manager
   *    - Connect it with the governance token
   */
  m.call(summerToken, 'setGovernor', [summerGovernor.value])
  m.call(summerToken, 'transferOwnership', [timelock.value])

  m.call(timelock, 'grantRole', [PROPOSER_ROLE, summerGovernor.value])
  m.call(timelock, 'grantRole', [CANCELLER_ROLE, summerGovernor.value])
  m.call(timelock, 'grantRole', [EXECUTOR_ROLE, summerGovernor.value])

  const protocolAccessManager = m.contractAt('ProtocolAccessManager', protocolAccessManagerAddress)
  m.call(protocolAccessManager, 'revokeRole', [DEFAULT_ADMIN_ROLE, deployer])
  m.call(protocolAccessManager, 'grantRole', [DEFAULT_ADMIN_ROLE, timelock.value])
  m.call(protocolAccessManager, 'grantRole', [GOVERNOR_ROLE, timelock.value])

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
