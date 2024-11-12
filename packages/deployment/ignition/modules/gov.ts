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
const DECAY_CONTROLLER_ROLE = keccak256(toBytes('DECAY_CONTROLLER_ROLE'))
/**
 * @title Governance Module Deployment Script
 * @notice This module handles the deployment and initialization of the governance system
 *
 * @dev Deployment and initialization sequence:
 * 1. Deploy TimelockController (timelock for governance actions)
 * 2. Deploy SummerToken (governance token)
 * 3. Deploy SummerGovernor (governance logic)
 * 4. Configure contract relationships and permissions:
 *    - Transfer SummerToken ownership to TimelockController
 *    - Set SummerGovernor as decay manager for SummerToken
 *    - Grant PROPOSER, CANCELLER, and EXECUTOR roles to SummerGovernor in TimelockController
 *    - Configure ProtocolAccessManager permissions
 *    - Revoke deployer's temporary permissions
 *
 * Post-deployment security considerations:
 * - The TimelockController becomes the ultimate owner of the system
 * - The SummerGovernor can only execute actions through the TimelockController
 * - All administrative actions must go through the governance process
 */
export const GovModule = buildModule('GovModule', (m) => {
  const deployer = m.getAccount(0)
  const lzEndpoint = m.getParameter('lzEndpoint')
  const protocolAccessManagerAddress = m.getParameter('protocolAccessManager')

  /**
   * @dev Step 1: Deploy TimelockController
   * This contract adds a time delay to governance actions
   * Initially configured with:
   * - deployer as proposer (temporary)
   * - ADDRESS_ZERO as executor (anyone can execute)
   * - deployer as admin (temporary)
   */
  const MIN_DELAY = 86400n
  const TEMP_MIN_DELAY_DURING_TESTING = MIN_DELAY / 24n
  const timelock = m.contract('TimelockController', [
    TEMP_MIN_DELAY_DURING_TESTING,
    [deployer],
    [ADDRESS_ZERO],
    deployer,
  ])

  /**
   * @dev Step 2: Deploy SummerToken
   * Initially configured with:
   * - TimelockController as owner (controls administrative functions like minting)
   * - deployer as decay manager (temporary, will be transferred to governor)
   * - Configured with initial decay parameters for voting power
   */
  const summerTokenParams = {
    name: 'SummerToken',
    symbol: 'SUMMER',
    lzEndpoint: lzEndpoint,
    owner: timelock,
    accessManager: protocolAccessManagerAddress,
    initialDecayFreeWindow: 30n * 24n * 60n * 60n, // 30 days
    initialDecayRate: 1n, // ~10% per year
    initialDecayFunction: DecayType.Linear,
    transferEnableDate: 1731667188n,
  }
  const summerToken = m.contract('SummerToken', [summerTokenParams])

  /**
   * @dev Step 3: Deploy SummerGovernor
   * This contract manages the governance process
   * - Integrates with SummerToken for voting power calculations
   * - Uses TimelockController for action execution
   * - Configured with initial voting parameters and cross-chain settings
   */
  const summerGovernorDeployParams = {
    token: summerToken,
    timelock: timelock,
    // Note: Voting delay is set to 1 second to allow for testing
    votingDelay: 1n,
    // Note: Voting period is set to 1 hour to allow for testing
    votingPeriod: 60n * 60n,
    proposalThreshold: 10000n * 10n ** 18n,
    quorumFraction: 4n,
    initialWhitelistGuardian: deployer,
    endpoint: lzEndpoint,
    proposalChainId: 8453n,
  }
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  const governanceRewardsManager = m.contract('GovernanceRewardsManager', [
    summerToken,
    protocolAccessManagerAddress,
  ])

  /**
   * @dev Step 4: Post-deployment configuration
   *
   * Configuration sequence:
   * 1. Configure SummerToken
   *    - Confirm TimelockController ownership
   *    - Set SummerGovernor as decay manager
   *
   * 2. Configure TimelockController roles
   *    - Grant PROPOSER_ROLE to SummerGovernor
   *    - Grant CANCELLER_ROLE to SummerGovernor
   *    - Grant EXECUTOR_ROLE to SummerGovernor
   *
   * 3. Configure ProtocolAccessManager
   *    - Revoke deployer's admin rights
   *    - Grant admin and governor roles to TimelockController
   *
   * 4. Cleanup
   *    - Remove deployer's proposer role from TimelockController
   */
  m.call(summerToken, 'transferOwnership', [timelock])

  m.call(timelock, 'grantRole', [PROPOSER_ROLE, summerGovernor], { id: 'grantRole_3' })
  m.call(timelock, 'grantRole', [CANCELLER_ROLE, summerGovernor], { id: 'grantRole_4' })
  m.call(timelock, 'grantRole', [EXECUTOR_ROLE, summerGovernor], { id: 'grantRole_5' })

  const protocolAccessManager = m.contractAt('ProtocolAccessManager', protocolAccessManagerAddress)
  m.call(protocolAccessManager, 'grantRole', [DECAY_CONTROLLER_ROLE, governanceRewardsManager], {
    id: 'grantRole_1',
  })
  m.call(protocolAccessManager, 'grantRole', [DECAY_CONTROLLER_ROLE, summerGovernor], {
    id: 'grantRole_2',
  })
  m.call(protocolAccessManager, 'revokeRole', [DEFAULT_ADMIN_ROLE, deployer], {
    id: 'revokeRole_1',
  })
  m.call(protocolAccessManager, 'grantRole', [DEFAULT_ADMIN_ROLE, timelock], { id: 'grantRole_6' })
  m.call(protocolAccessManager, 'grantRole', [GOVERNOR_ROLE, timelock], { id: 'grantRole_7' })

  m.call(timelock, 'revokeRole', [PROPOSER_ROLE, deployer], { id: 'revokeRole_6' })

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
