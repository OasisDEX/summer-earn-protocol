import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

import { ADDRESS_ZERO } from '../../scripts/common/constants'

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
export const TimelockAndProtocolAccessManagerModule = buildModule(
  'TimelockAndProtocolAccessManagerModule',
  (m) => {
    const deployer = m.getAccount(0)
    const minDelay = m.getParameter('minDelay', 0n)

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

    return {
      timelock,
      protocolAccessManager: accessManager,
    }
  },
)

export type TimelockAndProtocolAccessManagerContracts = {
  timelock: { address: string }
  protocolAccessManager: { address: string }
}
