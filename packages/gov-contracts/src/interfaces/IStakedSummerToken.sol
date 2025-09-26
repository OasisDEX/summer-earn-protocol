// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IStakedSummerToken
 * @notice Interface for xSUMR, the non-transferable staked representation of SUMR used for governance and rewards.
 * @dev xSUMR is mint/burn controlled by approved staking modules. Direct transfers between users are disabled; only
 *      minting (from address(0)) and burning (to address(0)) are permitted movements. Implementations SHOULD enforce
 *      role-based access control for minting and restricted burning, and MAY expose pause controls via governance.
 *
 * Rationale and Invariants:
 * - Transfer path is intentionally restricted to mint/burn to avoid bypassing staking logic and snapshots.
 * - Multiple staking modules may be authorized concurrently; governance manages their lifecycle.
 * - `burnFrom` authorization requires either the owner or an address with BURNER role; allowance rules still apply.
 */
interface IStakedSummerToken is IERC20 {
    // =============================
    //            EVENTS
    // =============================

    /**
     * @notice Emitted when a staking module is granted mint/burn permissions on xSUMR.
     * @param stakingModule Address of the staking module added.
     */
    event StakingModuleAdded(address indexed stakingModule);

    /**
     * @notice Emitted when a staking module has its mint/burn permissions revoked on xSUMR.
     * @param stakingModule Address of the staking module removed.
     */
    event StakingModuleRemoved(address indexed stakingModule);

    // =============================
    //            ERRORS
    // =============================

    /**
     * @notice Thrown when a zero address or otherwise invalid staking module is supplied.
     * @param message Details about the invalid staking module input.
     */
    error xSumr_InvalidStakingModule(string message);

    /**
     * @notice Thrown when a caller attempts an operation without the required authorization.
     */
    error xSumr__NotAuthorized();

    /**
     * @notice Thrown when a forbidden token transfer is attempted (only mint/burn flows are allowed).
     */
    error xSumr_TransferNotAllowed();

    // =============================
    //          GOVERNANCE
    // =============================

    /**
     * @notice Adds a staking module with mint and burn permissions.
     * @dev Access restricted to governance in the implementing contract.
     * @param _stakingModule The staking module to authorize.
     *        Must be a non-zero address and expected to integrate with staking flows.
     * @custom:reverts xSumr_InvalidStakingModule If `_stakingModule` is the zero address.
     * @custom:emits StakingModuleAdded Emitted upon successful addition.
     */
    function addStakingModule(address _stakingModule) external;

    /**
     * @notice Removes a staking module with mint and burn permissions.
     * @dev Access restricted to governance in the implementing contract.
     * @param _stakingModule The staking module to remove.
     *        Must be a non-zero address and previously authorized.
     * @custom:reverts xSumr_InvalidStakingModule If `_stakingModule` is the zero address.
     * @custom:emits StakingModuleRemoved Emitted upon successful removal.
     */
    function removeStakingModule(address _stakingModule) external;

    /**
     * @notice Grants MINTER_ROLE to a specified address. Governor-only.
     * @dev Intended for emergency recovery scenarios (e.g., user burned xSUMR prematurely
     *      and needs redemption support). Normal mint authorization should be managed via
     *      `addStakingModule`.
     * @param _minter Address to grant MINTER_ROLE to.
     */
    function grantMinterRole(address _minter) external;

    /**
     * @notice Revokes MINTER_ROLE from a specified address. Governor-only.
     * @dev Intended for emergency recovery scenarios. Normal flow uses `removeStakingModule` for module revocation.
     * @param _minter Address to revoke MINTER_ROLE from.
     */
    function revokeMinterRole(address _minter) external;

    /**
     * @notice  Pauses token operations that honor pausability (e.g., burns).
     * @dev Callable by guardian or governor. While paused, `mint`, `burn` and `burnFrom` are blocked by ERC20Pausable.
     */
    function pause() external;

    /**
     * @notice Unpauses token operations.
     * @dev Callable by guardian or governor. Restores normal `mint`/`burn`/`burnFrom` behavior.
     */
    function unpause() external;

    // =============================
    //        MINT / BURN API
    // =============================

    /**
     * @notice Mints xSUMR to a recipient address.
     * @dev Access is expected to be restricted to authorized staking modules.
     * @param _to Recipient address for newly minted xSUMR.
     * @param _amount Amount of xSUMR to mint (1:1 to staked SUMR backing in typical flows).
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @notice Burns caller's xSUMR balance.
     * @dev Access: Token owner. Used for self-burn flows like unstaking where the owner directly initiates the burn.
     * @param _amount Amount of xSUMR to burn from the caller's balance.
     */
    function burn(uint256 _amount) external;

    /**
     * @notice Burns xSUMR from a specified address using module authorization and/or allowance
     * @dev Implementations SHOULD allow either the token owner or an authorized burner module to execute.
     * @param _from Address from which tokens will be burned.
     * @param _amount Amount of xSUMR to burn.
     * @dev Implementations SHOULD enforce either owner self-burn or burner-role authorization plus allowance.
     */
    function burnFrom(address _from, uint256 _amount) external;
}
