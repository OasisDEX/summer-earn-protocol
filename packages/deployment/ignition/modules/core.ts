import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * @dev Enum representing different types of auction price decay functions
 */
enum DecayType {
  Linear,
  Exponential,
}

/**
 * @title Core Protocol Module Deployment Script
 * @notice This module handles the deployment and initialization of the core protocol components
 *
 * @dev Deployment and initialization sequence:
 * 1. Deploy core infrastructure (Libraries, Access Control)
 * 2. Deploy protocol components (TipJar, RewardsManager, etc.)
 * 3. Deploy main protocol contracts (Raft, HarborCommand)
 * 4. Configure contract relationships
 *
 * Security considerations:
 * - ProtocolAccessManager is deployed first as it controls access across the system
 * - Contracts are deployed in a specific order to satisfy dependencies
 * - Configuration is initialized last after all contracts are deployed
 */
export const CoreModule = buildModule('CoreModule', (m) => {
  const deployer = m.getAccount(0)
  const treasury = m.getParameter('treasury')
  const swapProvider = m.getParameter('swapProvider')

  /**
   * @dev Step 1: Deploy Core Infrastructure
   *
   * DutchAuctionLibrary: Shared library for auction functionality
   * ProtocolAccessManager: Central access control for the entire protocol
   * ConfigurationManager: Manages protocol-wide configuration
   */
  const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])

  const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])

  const configurationManager = m.contract('ConfigurationManager', [protocolAccessManager])

  /**
   * @dev Step 2: Deploy Protocol Components
   *
   * TipJar: Handles protocol fee collection and distribution
   * GovernanceRewardsManager: Manages governance rewards (initialized later in GovModule)
   */
  const tipJar = m.contract('TipJar', [protocolAccessManager, configurationManager])

  const governanceRewardsManager = m.contract('GovernanceRewardsManager', [protocolAccessManager])

  /**
   * @dev Step 3: Deploy Main Protocol Contracts
   *
   * Configure default auction parameters for Raft
   * HarborCommand: Main protocol control center
   * Raft: Core protocol contract implementing auction mechanics
   */
  const raftAuctionDefaultParams = {
    duration: 7n * 86400n, // 7 days
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n, // 5%
    decayType: DecayType.Linear,
  }

  const harborCommand = m.contract('HarborCommand', [protocolAccessManager])

  const raft = m.contract('Raft', [protocolAccessManager, raftAuctionDefaultParams], {
    libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
  })

  /**
   * @dev Step 4: Configuration and Initialization
   *
   * Initialize ConfigurationManager with all deployed contract addresses
   * This step must happen after all contracts are deployed
   *
   * The configuration links:
   * - Raft for core protocol operations
   * - TipJar for fee management
   * - Treasury for protocol revenue
   * - HarborCommand for protocol control
   */
  const configurationManagerParams = {
    raft: raft,
    tipJar: tipJar,
    treasury: treasury,
    harborCommand: harborCommand,
  }

  m.call(configurationManager, 'initializeConfiguration', [configurationManagerParams])

  /**
   * @dev Step 5: Deploy Supporting Contracts
   *
   * AdmiralsQuarters: Handles generalised token entry and exit for fleets
   * Must be deployed after core configuration is complete
   */
  const admiralsQuarters = m.contract('AdmiralsQuarters', [swapProvider])

  return {
    protocolAccessManager,
    tipJar,
    raft,
    configurationManager,
    harborCommand,
    admiralsQuarters,
    governanceRewardsManager,
  }
})

/**
 * @dev Type definition for the deployed contract addresses
 * Used for contract interaction after deployment
 */
export type CoreContracts = {
  protocolAccessManager: { address: string }
  tipJar: { address: string }
  raft: { address: string }
  configurationManager: { address: string }
  harborCommand: { address: string }
  admiralsQuarters: { address: string }
}
