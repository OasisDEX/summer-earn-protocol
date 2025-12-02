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
 * Factory function to create a GovV1CoreModule for deploying the governance core contracts
 *
 * This function creates a module that deploys the timelock, protocol access manager, and token contracts.
 *
 * @param {string} moduleName - Name of the module (e.g., 'GovV1CoreModule' or 'staging_GovV1CoreModule')
 * @returns {Function} A function that builds the module
 */
export function createGovV1CoreModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const deployer = m.getAccount(0)
    const minDelay = m.getParameter('minDelay', 0n)
    const tokenName = m.getParameter('tokenName', 'SUMMER')
    const tokenSymbol = m.getParameter('tokenSymbol', 'SUMMER')
    const transferEnableDate = m.getParameter('transferEnableDate', 0n)
    const lzEndpoint = m.getParameter('lzEndpoint')

    /**
     * @dev Deploy ProtocolAccessManager
     * Manages access control for protocol-wide permissions and role-based access.
     * Initially owned by deployer; ownership should be transferred to governance after setup.
     */
    const accessManager = m.contract('ProtocolAccessManager', [deployer])

    /**
     * @dev Deploy SummerTimelockController
     * Implements time-delayed execution for governance proposals, providing a security buffer
     * for critical protocol changes.
     *
     * Constructor parameters:
     * - minDelay: Minimum delay before proposals can be executed
     * - proposers: Initial proposer addresses (deployer, temporary)
     * - executors: Executor addresses (ADDRESS_ZERO = anyone can execute after delay)
     * - admin: Initial admin address (deployer, temporary)
     * - accessManager: ProtocolAccessManager contract for access control
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
      initialSupply: 0n,
      initialDecayFreeWindow: 60n * 24n * 60n * 60n, // 60 days
      initialYearlyDecayRate: BigInt(0.1e18), // ~10% per year
      initialDecayFunction: DecayType.Linear,
      vestingWalletFactory: vestingWalletFactory,
    }

    m.call(summerToken, 'initialize', [summerTokenInitParams])

    return {
      timelock,
      protocolAccessManager: accessManager,
      summerToken,
    }
  })
}

// Legacy export for backward compatibility
export const GovV1CoreModule = createGovV1CoreModule('GovV1CoreModule')

export type GovV1CoreContracts = {
  timelock: { address: string }
  protocolAccessManager: { address: string }
  summerToken: { address: string }
}
