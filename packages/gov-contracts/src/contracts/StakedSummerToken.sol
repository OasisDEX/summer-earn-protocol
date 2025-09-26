// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";

/**
 * @title StakedSummerToken (xSUMR)
 * @notice Non-transferable staked representation of SUMR used for governance and rewards accounting.
 * @dev Key properties:
 *      - Minting/Burning controlled by governance-authorized staking modules
 *      - Direct transfers disabled; only mint (from address(0)) and burn (to address(0)) allowed
 *      - Pausable by guardian/governor for emergency response
 *      - Integrates ERC20Permit and ERC20Votes for signatures and governance snapshots
 *
 * Access control model:
 *      - Governor can add/remove staking modules, which grants MINTER and BURNER roles
 *      - Only modules with MINTER_ROLE can mint
 *      - burnFrom requires either the token owner or an address with BURNER_ROLE plus standard allowance
 */
contract StakedSummerToken is
    IStakedSummerToken,
    ERC20Burnable,
    ERC20Pausable,
    ProtocolAccessManaged,
    AccessControl,
    ERC20Permit,
    ERC20Votes
{
    // ============ ROLES ============
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // ============ CONSTRUCTOR ============
    constructor(
        address _protocolAccessManager
    )
        ERC20("StakedSummerToken", "xSUMR")
        ERC20Permit("StakedSummerToken")
        ProtocolAccessManaged(_protocolAccessManager)
    {}

    // ============ GOVERNANCE ============

    /// @inheritdoc IStakedSummerToken
    function addStakingModule(address _stakingModule) external onlyGovernor {
        if (_stakingModule == address(0)) {
            revert xSumr_InvalidStakingModule(
                "Staking module address cannot be zero"
            );
        }
        // Authorize staking module to participate in mint/burn flows
        _grantRole(MINTER_ROLE, _stakingModule);
        _grantRole(BURNER_ROLE, _stakingModule);

        emit StakingModuleAdded(_stakingModule);
    }

    /// @inheritdoc IStakedSummerToken
    function removeStakingModule(address _stakingModule) external onlyGovernor {
        // Fully deauthorize staking module by revoking both roles
        _revokeRole(MINTER_ROLE, _stakingModule);
        _revokeRole(BURNER_ROLE, _stakingModule);
        emit StakingModuleRemoved(_stakingModule);
    }

    /// @inheritdoc IStakedSummerToken
    function pause() external onlyGuardianOrGovernor {
        _pause();
    }

    /// @inheritdoc IStakedSummerToken
    function unpause() external onlyGuardianOrGovernor {
        _unpause();
    }

    // ============ MINT / BURN API ============

    /// @inheritdoc IStakedSummerToken
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        // Only authorized staking modules are permitted to mint xSUMR
        _mint(to, amount);
    }

    /// @inheritdoc IStakedSummerToken
    function burn(
        uint256 amount
    ) public override(ERC20Burnable, IStakedSummerToken) {
        super.burn(amount);
    }

    /// @inheritdoc IStakedSummerToken
    function burnFrom(
        address from,
        uint256 amount
    ) public override(ERC20Burnable, IStakedSummerToken) {
        if (!_canBurnFrom(from, msg.sender)) {
            revert xSumr__NotAuthorized();
        }
        // Honor allowance semantics when `msg.sender != from` via ERC20Burnable
        super.burnFrom(from, amount);
    }

    // ============ ERC6372 / ERC20Votes ============
    /// @notice Returns the current clock in seconds, used by ERC20Votes for timestamp-based checkpoints.
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    /// @notice Returns the clock mode string as required by ERC-6372.
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        if (!_canTransfer(from, to)) {
            revert xSumr_TransferNotAllowed();
        }
        // Run pausable and votes hooks (checkpoints, etc.)
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    // ============ ROLE MANAGEMENT (GOVERNOR) ============

    /// @inheritdoc IStakedSummerToken
    function grantMinterRole(address _minter) external onlyGovernor {
        _grantRole(MINTER_ROLE, _minter);
    }

    /// @inheritdoc IStakedSummerToken
    function revokeMinterRole(address _minter) external onlyGovernor {
        _revokeRole(MINTER_ROLE, _minter);
    }

    /**
     * @dev Overrides the grantRole function from AccessControl to disable direct role granting.
     * @notice This function always reverts with a DirectGrantIsDisabled error.
     */
    function grantRole(bytes32, address) public view override {
        revert DirectGrantIsDisabled(msg.sender);
    }

    /**
     * @dev Overrides the revokeRole function from AccessControl to disable direct role revoking.
     * @notice This function always reverts with a DirectRevokeIsDisabled error.
     */
    function revokeRole(bytes32, address) public view override {
        revert DirectRevokeIsDisabled(msg.sender);
    }

    // ============ INTERNAL HELPERS ============

    /**
     * @dev Only allow mint (from == address(0)) and burn (to == address(0)) movements. Block user-to-user transfers.
     * @notice All staking module interactions are based on `mint()` and `burnFrom()`;
     * transfers between users are disallowed.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @return bool True if the transfer is allowed, false otherwise.
     */
    function _canTransfer(
        address from,
        address to
    ) internal pure returns (bool) {
        return from == address(0) || to == address(0);
    }

    /**
     * @notice Allows `burnFrom` only if `spender` burns its own tokens or holds `BURNER_ROLE`.
     * @dev Even with `BURNER_ROLE`, standard ERC20 allowance rules apply.
     * @param from The address to burn tokens from.
     * @param spender The address to check for `BURNER_ROLE`.
     * @return bool True if the burn is allowed, false otherwise.
     */
    function _canBurnFrom(
        address from,
        address spender
    ) internal view returns (bool) {
        return spender == from || hasRole(BURNER_ROLE, spender);
    }
}
