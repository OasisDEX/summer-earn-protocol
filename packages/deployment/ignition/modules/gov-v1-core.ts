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
export const GovV1CoreModule = buildModule('GovV1CoreModule', (m) => {
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

  const summerTokenInitParams = {
    initialSupply: 0n,
    initialDecayFreeWindow: 60n * 24n * 60n * 60n, // 60 days
    initialYearlyDecayRate: BigInt(0.1e18), // ~10% per year
    initialDecayFunction: DecayType.Linear,
    vestingWalletFactory: '0x0000000000000000000000000000000000000000',
  }

  m.call(summerToken, 'initialize', [summerTokenInitParams])

  return {
    timelock,
    protocolAccessManager: accessManager,
    summerToken,
  }
})

export type GovV1CoreContracts = {
  timelock: { address: string }
  protocolAccessManager: { address: string }
  summerToken: { address: string }
}
