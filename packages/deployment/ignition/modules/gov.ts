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
  const initialSupply = m.getParameter('initialSupply', 0n)
  const tokenName = m.getParameter('tokenName', 'SUMMER')
  const tokenSymbol = m.getParameter('tokenSymbol', 'SUMMER')
  const transferEnableDate = m.getParameter('transferEnableDate', 0n)
  const minDelay = m.getParameter('minDelay', 0n)
  const votingDelay = m.getParameter('votingDelay', 60n)
  const votingPeriod = m.getParameter('votingPeriod', 600n)
  const proposalThreshold = m.getParameter('proposalThreshold', 10000n * 10n ** 18n)
  const quorumFraction = m.getParameter('quorumFraction', 4n)

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
  const timelock = m.contract('SummerTimelockController', [
    minDelay,
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
  const summerTokenConstructorParams = {
    name: tokenName,
    symbol: tokenSymbol,
    lzEndpoint: lzEndpoint,
    initialOwner: deployer, // Swapped out for Timelock after Peering is complete
    accessManager: accessManager,
    maxSupply: 1_000_000_000n * 10n ** 18n, // 1B tokens
    transferEnableDate: transferEnableDate,
    hubChainId: HUB_CHAIN_ID,
  }

  const summerToken = m.contract('SummerToken', [summerTokenConstructorParams])
  const vestingWalletFactory = m.contract('SummerVestingWalletFactory', [
    summerToken,
    accessManager,
  ])

  const summerTokenInitParams = {
    initialSupply: initialSupply,
    initialDecayFreeWindow: 60n * 24n * 60n * 60n, // 60 days
    initialYearlyDecayRate: BigInt(0.1e18), // ~10% per year
    initialDecayFunction: DecayType.Linear,
    vestingWalletFactory: vestingWalletFactory,
  }

  m.call(summerToken, 'initialize', [summerTokenInitParams])

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
    votingDelay: votingDelay,
    votingPeriod: votingPeriod,
    proposalThreshold: proposalThreshold,
    quorumFraction: quorumFraction,
    endpoint: lzEndpoint,
    hubChainId: HUB_CHAIN_ID,
    initialOwner: deployer,
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
