import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

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
export const StakingModule = buildModule('StakingModule', (m) => {
  const deployer = m.getAccount(0)
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
  const stakedSummerToken = m.contract('StakedSummerToken', [protocolAccessManager])

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
    stakedSummerToken,
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
    stakedSummerToken,
    initialVestingFactories,
  ])

  /**
   * @dev Step 4: Configure StakedSummerToken
   *
   * Add the staking contracts as authorized staking modules:
   * - SummerStaking gets MINTER_ROLE and BURNER_ROLE
   * - SummerVestingWalletsEscrow gets MINTER_ROLE and BURNER_ROLE
   * - This allows them to mint/burn xSUMR tokens
   */
  m.call(stakedSummerToken, 'addStakingModule', [summerStaking], { id: 'v2_staking_module' })
  m.call(stakedSummerToken, 'addStakingModule', [summerVestingWalletsEscrow], {
    id: 'v2_escrow_module',
  })

  return {
    stakedSummerToken,
    summerStaking,
    summerVestingWalletsEscrow,
  }
})

export type StakingContracts = {
  stakedSummerToken: { address: string }
  summerStaking: { address: string }
  summerVestingWalletsEscrow: { address: string }
}
