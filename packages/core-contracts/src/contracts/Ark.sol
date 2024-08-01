// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {IArk, ArkParams} from "../interfaces/IArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../errors/AccessControlErrors.sol";
import {CannotAddCommanderToArkWithCommander, CannotRemoveCommanderFromArkWithAssets} from "../errors/ArkErrors.sol";
import {IArk, ArkParams} from "../interfaces/IArk.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @custom:see IArk
 */
abstract contract Ark is IArk, ArkAccessManaged {
    using SafeERC20 for IERC20;

    address public raft;
    uint256 public maxAllocation;
    IERC20 public token;
    bool private _hasCommander;

    constructor(
        ArkParams memory _params
    ) ArkAccessManaged(_params.accessManager) {
        IConfigurationManager manager = IConfigurationManager(
            _params.configurationManager
        );
        maxAllocation = _params.maxAllocation;
        raft = manager.raft();
        token = IERC20(_params.token);
    }

    /**
     * @dev Modifier to check that the caller is the Raft contract
     */
    modifier onlyRaft() {
        if (msg.sender != raft) {
            revert CallerIsNotRaft(msg.sender);
        }
        _;
    }

    /* PUBLIC */
    function totalAssets() public view virtual returns (uint256) {}

    function rate() public view virtual returns (uint256) {}

    /* EXTERNAL - RAFT */
    function harvest(address rewardToken) external virtual returns (uint256) {}

    function hasCommander() public view returns (bool) {
        return _hasCommander;
    }

    /* EXTERNAL - COMMANDER */
    function board(uint256 amount) external onlyRaftOrCommander {
        token.safeTransferFrom(msg.sender, address(this), amount);
        _board(amount);

        emit Boarded(msg.sender, address(token), amount);
    }

    function disembark(
        uint256 amount,
        address receiver
    ) external onlyCommander {
        _disembark(amount);
        token.safeTransfer(receiver, amount);

        emit Disembarked(receiver, address(token), amount);
    }

    function setMaxAllocation(uint256 newMaxAllocation) external onlyCommander {
        maxAllocation = newMaxAllocation;
        emit MaxAllocationUpdated(newMaxAllocation);
    }

    function poke() public virtual {
        // No-op
    }

    /* EXTERNAL - GOVERNANCE */
    function setRaft(address newRaft) external onlyGovernor {}

    /**
     * @notice Hook executed before the Commander role is revoked
     * @dev Overrides the base implementation to prevent removal when assets are present
     */
    function _beforeGrantRoleHook(
        address
    ) internal virtual override(ArkAccessManaged) onlyGovernor {
        if (_hasCommander) {
            revert CannotAddCommanderToArkWithCommander();
        }
        _hasCommander = true;
    }

    /**
     * @notice Hook executed before the Commander role is granted
     * @dev Overrides the base implementation to enforce single Commander constraint
     */
    function _beforeRevokeRoleHook(
        address
    ) internal virtual override(ArkAccessManaged) {
        if (this.totalAssets() > 0) {
            revert CannotRemoveCommanderFromArkWithAssets();
        }
        _hasCommander = false;
    }

    /* INTERNAL */
    function _board(uint256 amount) internal virtual;

    function _disembark(uint256 amount) internal virtual;
}
