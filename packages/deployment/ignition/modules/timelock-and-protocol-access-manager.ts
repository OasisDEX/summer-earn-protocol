import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

import { ADDRESS_ZERO } from '../../scripts/common/constants'

/**
 * @title Timelock and Protocol Access Manager Module
 * @notice This module handles the deployment of the TimelockController and ProtocolAccessManager
 *         contracts, which form the foundation of the governance system's access control and
 *         time-delayed execution mechanisms.
 *
 * @dev Deployment sequence:
 * 0. Deploy ProtocolAccessManager
 *    - Manages access control for the protocol
 *    - Initially owned by deployer (temporary)
 * 1. Deploy SummerTimelockController
 *    - Adds a time delay to governance actions for security
 *    - Initially configured with:
 *      - deployer as proposer (temporary, will be replaced by governance)
 *      - ADDRESS_ZERO as executor (anyone can execute after delay)
 *      - deployer as admin (temporary, will be transferred to governance)
 *      - ProtocolAccessManager for access control integration
 *
 * @dev Post-deployment considerations:
 * - Initial roles are temporary and should be transferred to the governance system
 * - The TimelockController will become the executor for governance proposals
 * - ProtocolAccessManager permissions should be configured after governance deployment
 * - This module is typically deployed before the governance token and governor contracts
 */
export const TimelockAndProtocolAccessManagerModule = buildModule(
  'TimelockAndProtocolAccessManagerModule',
  (m) => {
    const deployer = m.getAccount(0)
    const minDelay = m.getParameter('minDelay', 0n)

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
