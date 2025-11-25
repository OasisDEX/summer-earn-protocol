import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a StakingModule for deploying the staking contracts
 *
 * This function creates a module that deploys the staking system contracts.
 *
 * @param {string} moduleName - Name of the module (e.g., 'StakingModule' or 'staging_StakingModule')
 * @returns {Function} A function that builds the module
 */
export function createStakingModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const protocolAccessManager = m.getParameter('protocolAccessManager')
    const configurationManager = m.getParameter('configurationManager')
    const summerToken = m.getParameter('summerToken')
    const initialVestingFactories = m.getParameter('initialVestingFactories', [])

    /**
     * @dev Step 1: Deploy StakedSummerToken (xSUMR)
     *
     * This is the non-transferable governance token that represents staked SUMR.
     * Key features:
     * - Non-transferable (only mint/burn allowed)
     * - Integrates ERC20Votes for governance snapshots
     * - Access control via ProtocolAccessManager
     * - Only authorized staking modules can mint/burn
     */
    const summerGovernanceToken = m.contract('StakedSummerToken', [protocolAccessManager])

    /**
     * @dev Step 2: Deploy SummerStaking
     *
     * Main staking contract that handles:
     * - Lockup periods (0-3 years)
     * - Weighted rewards based on lockup duration
     * - Bucket caps for different lockup periods
     * - Early unstake penalties
     * - Integration with rewards system
     */
    const summerStaking = m.contract('SummerStaking', [
      protocolAccessManager,
      configurationManager,
      summerToken,
      summerGovernanceToken,
    ])

    /**
     * @dev Step 3: Deploy SummerVestingWalletsEscrow
     *
     * Escrow contract for staking against vesting wallets:
     * - Allows staking xSUMR against SUMR in vesting wallets
     * - Forwards released tokens to users on unstake
     * - Manages vesting wallet ownership
     * - Supports multiple vesting factory implementations
     */
    const summerVestingWalletsEscrow = m.contract('SummerVestingWalletsEscrow', [
      protocolAccessManager,
      summerToken,
      summerGovernanceToken,
      initialVestingFactories,
    ])

    /**
     * @dev Step 4: Configure StakedSummerToken
     *
     * Note: The staking modules must be added to StakedSummerToken.
     * This requires GOVERNOR_ROLE or similar permissions which the deployer
     * typically does not have. These must be added via a governance/multisig proposal.
     *
     * - SummerStaking gets MINTER_ROLE and BURNER_ROLE
     * - SummerVestingWalletsEscrow gets MINTER_ROLE and BURNER_ROLE
     * m.call(summerGovernanceToken, 'addStakingModule', [summerStaking], { id: 'v2_staking_module' })
     * m.call(summerGovernanceToken, 'addStakingModule', [summerVestingWalletsEscrow], { id: 'v2_escrow_module' })
     */

    return {
      summerGovernanceToken,
      summerStaking,
      summerVestingWalletsEscrow,
    }
  })
}

/**
 * @title Staking Module Deployment Script
 * @notice This module handles the deployment and initialization of the staking system
 *
 * @dev Deployment and initialization sequence:
 * 1. Deploy StakedSummerToken (xSUMR) - Non-transferable governance token
 * 2. Deploy SummerStaking - Main staking contract with lockup periods and rewards
 * 3. Deploy SummerVestingWalletsEscrow - Escrow for vesting wallet staking
 * 4. Configure contract relationships:
 *    - Add SummerStaking as staking module to StakedSummerToken
 *    - Add SummerVestingWalletsEscrow as staking module to StakedSummerToken
 *    - Initialize SummerStaking with proper configuration
 *
 * Security considerations:
 * - StakedSummerToken is non-transferable (only mint/burn allowed)
 * - Only authorized staking modules can mint/burn xSUMR
 * - Vesting factories must be allowlisted by governance
 * - All administrative actions require proper access control
 */

// Legacy export for backward compatibility
export const StakingModule = createStakingModule('StakingModule')

/**
 * Type definition for the returned contract addresses
 */
export type StakingContracts = {
  summerGovernanceToken: { address: string }
  summerStaking: { address: string }
  summerVestingWalletsEscrow: { address: string }
}
