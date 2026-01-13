import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a TimelockGuardFactoryModule for deploying the TimelockGuardFactory contract
 *
 * This function creates a module that deploys the TimelockGuardFactory contract, which allows
 * permissionless creation of TimelockGuard instances for governance timelock transactions.
 *
 * @param {string} moduleName - Name of the module (e.g., 'TimelockGuardFactoryModule' or 'staging_TimelockGuardFactoryModule')
 * @returns {Function} A function that builds the module
 */
export function createTimelockGuardFactoryModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    /**
     * @dev Deploy TimelockGuardFactory
     * This factory contract allows anyone to create TimelockGuard instances
     * for use in governance timelock transactions that require a "not earlier than" constraint.
     */
    const timelockGuardFactory = m.contract('TimelockGuardFactory', [])

    return {
      timelockGuardFactory,
    }
  })
}

/**
 * @title TimelockGuardFactory Module Deployment Script
 * @notice This module handles the deployment of the TimelockGuardFactory contract
 *
 * @dev Deployment sequence:
 * 1. Deploy TimelockGuardFactory (no constructor parameters required)
 *
 * @custom:usage This factory is deployed using CREATE2 strategy to ensure the same address
 *               across all chains. The salt for CREATE2 is configured in the deployment script.
 */
export type TimelockGuardFactoryContracts = {
  timelockGuardFactory: { address: string }
}
