import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { ADDRESS_ZERO } from '../../scripts/common/constants'

/**
 * @dev Enum representing different types of voting power decay functions
 */
enum DecayType {
  Linear,
  Exponential,
}

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
  const initialSupply = m.getParameter('initialSupply')

  /**
   * @dev Step 1: Deploy TimelockController
   * This contract adds a time delay to governance actions
   * Initially configured with:
   * - deployer as proposer (temporary)
   * - ADDRESS_ZERO as executor (anyone can execute)
   * - deployer as admin (temporary)
   */
  const MIN_DELAY = 86400n
  const TEMP_MIN_DELAY_DURING_TESTING = MIN_DELAY / 48n // 30 minutes
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
    owner: deployer,
    accessManager: protocolAccessManagerAddress,
    initialDecayFreeWindow: 30n * 24n * 60n * 60n, // 30 days
    initialDecayRate: 3.1709792e9, // ~10% per year
    initialDecayFunction: DecayType.Linear,
    transferEnableDate: 1731667188n,
    maxSupply: 100_000_000n * 10n ** 18n, // 100M tokens
    initialSupply: initialSupply,
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
