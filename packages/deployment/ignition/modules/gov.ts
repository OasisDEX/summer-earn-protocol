import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { ADDRESS_ZERO } from '../../scripts/common/constants'

/**
 * @dev Enum representing different types of voting power decay functions
 */
enum DecayType {
  Linear,
  Exponential,
}

const HUB_CHAIN_ID = 8453n // BASE

/**
 * @title Governance Module Deployment Script
 * @notice This module handles the deployment and initialization of the governance system
 *
 * @dev Deployment and initialization sequence:
 * 0. Deploy ProtocolAccessManager
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
  const initialSupply = m.getParameter('initialSupply', '0')
  const peerEndpointIds = m.getParameter<number[]>('peerEndpointIds', [])
  const peerAddresses = m.getParameter<string[]>('peerAddresses', [])

  /**
   * @dev Step 0: Deploy ProtocolAccessManager
   * This contract manages access control for the protocol
   */
  const accessManager = m.contract('ProtocolAccessManager', [deployer])

  /**
   * @dev Step 1: Deploy SummerTimelockController
   * This contract adds a time delay to governance actions
   * Initially configured with:
   * - deployer as proposer (temporary)
   * - ADDRESS_ZERO as executor (anyone can execute)
   * - deployer as admin (temporary)
   */
  const MIN_DELAY = 86400n
  const TEMP_MIN_DELAY_DURING_TESTING = 300n // 5 minutes for testing
  const timelock = m.contract('SummerTimelockController', [
    TEMP_MIN_DELAY_DURING_TESTING,
    [deployer],
    [ADDRESS_ZERO],
    deployer,
    accessManager,
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
    owner: deployer,
    accessManager: accessManager,
    initialDecayFreeWindow: 30n * 24n * 60n * 60n, // 30 days
    initialDecayRate: 3.1709792e9, // ~10% per year
    initialDecayFunction: DecayType.Linear,
    transferEnableDate: 1731667188n,
    maxSupply: 1_000_000_000n * 10n ** 18n, // 1B tokens
    initialSupply: initialSupply,
    hubChainId: HUB_CHAIN_ID,
    peerEndpointIds: peerEndpointIds,
    peerAddresses: peerAddresses,
  }
  const summerToken = m.contract('SummerToken', [summerTokenParams])

  /**
   * @dev Step 3: Deploy SummerGovernor
   * This contract manages the governance process
   * - Integrates with SummerToken for voting power calculations
   * - On BASE chain (hubChainId == chainId):
   *   - Uses TimelockController for action execution
   *   - TimelockController owns the governor
   * - On satellite chains:
   *   - Governor executes actions directly
   *   - Governor owns itself
   */
  const summerGovernorDeployParams = {
    token: summerToken,
    timelock: timelock,
    accessManager: accessManager,
    // Note: Voting delay is set to 60 second to allow for testing
    votingDelay: 60n,
    // Note: Voting period is set to 10 minutes to allow for testing
    votingPeriod: 600n, // 10 minutes
    proposalThreshold: 10000n * 10n ** 18n,
    quorumFraction: 4n,
    endpoint: lzEndpoint,
    hubChainId: HUB_CHAIN_ID,
    peerEndpointIds: peerEndpointIds,
    peerAddresses: peerAddresses,
  }
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  const rewardsRedeemer = m.contract('SummerRewardsRedeemer', [summerToken, accessManager])

  return {
    summerGovernor,
    summerToken,
    timelock,
    protocolAccessManager: accessManager,
    rewardsRedeemer,
  }
})

export type GovContracts = {
  summerGovernor: { address: string }
  summerToken: { address: string }
  timelock: { address: string }
  protocolAccessManager: { address: string }
  rewardsRedeemer: { address: string }
}
