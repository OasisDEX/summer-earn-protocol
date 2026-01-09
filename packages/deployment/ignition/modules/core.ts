import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a CoreModule for deploying the core protocol contracts
 *
 * This function creates a module that deploys the core protocol components.
 *
 * @param {string} moduleName - Name of the module (e.g., 'CoreModule' or 'staging_CoreModule')
 * @returns {Function} A function that builds the module
 */
export function createCoreModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const treasury = m.getParameter('treasury')
    const swapProvider = m.getParameter('swapProvider')
    const wrappedNative = m.getParameter('wrappedNative')
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

    const fleetCommanderRewardsManagerFactory = m.contract(
      'FleetCommanderRewardsManagerFactory',
      [],
    )

    /**
     * @dev Step 3: Deploy Main Protocol Contracts
     *
     * Order:
     * 1. HarborCommand: Central control contract
     * 2. Raft: Core auction contract with DutchAuctionLibrary dependency
     *
     * Note: Raft requires auction parameters and library linking
     */
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
      wrappedNative,
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
 * 2. Deploy Treasury Components
 *    - Treasury contract (asset management)
 *    - TreasuryConfiguredRoles (role-based access for treasury)
 *
 * 3. Deploy Main Protocol Contracts
 *    - HarborCommand (fleet operations hub)
 *    - Raft (auction mechanism)
 *    - TipJar (protocol fee management)
 *
 * 4. Initialize Configuration
 *    - Configures Treasury, HarbourCommand, Raft, and TipJar in ConfigurationManager
 */

// Legacy export for backward compatibility
export const CoreModule = createCoreModule('CoreModule')

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
