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
 * 1. Deploy Core Infrastructure
 *    - DutchAuctionLibrary (shared auction functionality)
 *    - ProtocolAccessManager (central access control)
 *    - ConfigurationManager (protocol-wide settings)
 *
 * 2. Deploy Protocol Components
 *    - TipJar (fee collection and distribution)
 *    - GovernanceRewardsManager (governance incentives)
 *
 * 3. Deploy Main Protocol Contracts
 *    - HarborCommand (protocol control center)
 *    - Raft (auction mechanics implementation)
 *
 * 4. Initialize Configuration
 *    - Link all core contracts in ConfigurationManager
 *    - Set up contract relationships
 *
 * 5. Deploy Supporting Contracts
 *    - AdmiralsQuarters (fleet token management)
 *
 * Security considerations:
 * - ProtocolAccessManager deployment first ensures proper access control
 * - Contracts are deployed in dependency order
 * - Configuration happens after all core contracts are deployed
 * - Supporting contracts deployed last to ensure core system is ready
 */
export const CoreModule = buildModule('CoreModule', (m) => {
  const treasury = m.getParameter('treasury')
  const swapProvider = m.getParameter('swapProvider')
  const weth = m.getParameter('weth')
  const protocolAccessManager = m.getParameter('protocolAccessManager')

  /**
   * @dev Step 1: Deploy Core Infrastructure
   *
   * Order:
   * 1. DutchAuctionLibrary: Required by Raft for auction calculations
   * 2. ConfigurationManager: Required for protocol-wide settings
   */
  const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])
  const configurationManager = m.contract('ConfigurationManager', [protocolAccessManager])

  /**
   * @dev Step 2: Deploy Protocol Components
   *
   * These contracts handle specific protocol functionalities:
   * - TipJar: Protocol fee management with access control and configuration
   */
  const tipJar = m.contract('TipJar', [protocolAccessManager, configurationManager])

  const fleetCommanderRewardsManagerFactory = m.contract('FleetCommanderRewardsManagerFactory', [])

  /**
   * @dev Step 3: Deploy Main Protocol Contracts
   *
   * Order:
   * 1. HarborCommand: Central control contract
   * 2. Raft: Core auction contract with DutchAuctionLibrary dependency
   *
   * Note: Raft requires auction parameters and library linking
   */
  const raftAuctionDefaultParams = {
    duration: 7n * 86400n, // 7 days
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n, // 5%
    decayType: DecayType.Linear,
  }

  const harborCommand = m.contract('HarborCommand', [protocolAccessManager])

  const raft = m.contract('Raft', [protocolAccessManager], {
    libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
  })

  /**
   * @dev Step 4: Configuration Initialization
   *
   * Links all core components together via ConfigurationManager:
   * - Raft for auction operations
   * - TipJar for fee handling
   * - Treasury for revenue management
   * - HarborCommand for protocol control
   */
  const configurationManagerParams = {
    raft: raft,
    tipJar: tipJar,
    treasury: treasury,
    harborCommand: harborCommand,
    fleetCommanderRewardsManagerFactory: fleetCommanderRewardsManagerFactory,
  }

  m.call(configurationManager, 'initializeConfiguration', [configurationManagerParams])

  /**
   * @dev Step 5: Supporting Contract Deployment
   *
   * AdmiralsQuarters requires:
   * - Completed core configuration
   * - Swap provider for token operations
   */
  const admiralsQuarters = m.contract('AdmiralsQuarters', [
    swapProvider,
    configurationManager,
    weth,
  ])

  return {
    tipJar,
    raft,
    configurationManager,
    harborCommand,
    admiralsQuarters,
    fleetCommanderRewardsManagerFactory,
  }
})

/**
 * @dev Type definition for the deployed contract addresses
 * Used for contract interaction after deployment
 */
export type CoreContracts = {
  tipJar: { address: string }
  raft: { address: string }
  configurationManager: { address: string }
  harborCommand: { address: string }
  admiralsQuarters: { address: string }
  fleetCommanderRewardsManagerFactory: { address: string }
}
