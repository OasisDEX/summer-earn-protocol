// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {CannotAddCommanderToArkWithCommander, CannotRemoveCommanderFromArkWithAssets} from "../errors/ArkErrors.sol";
import {IArk, ArkParams} from "../interfaces/IArk.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../errors/AccessControlErrors.sol";

/**
 * @custom:see IArk
 */
abstract contract Ark is IArk, ArkAccessManaged {
    using SafeERC20 for IERC20;

    address public raft;
    uint256 public maxAllocation;
    IERC20 public token;
    address public commander;
    IConfigurationManager public manager;

    constructor(
        ArkParams memory _params
    ) ArkAccessManaged(_params.accessManager) {
        manager = IConfigurationManager(
            _params.configurationManager
        );
        maxAllocation = _params.maxAllocation;
        raft = manager.raft();
        token = IERC20(_params.token);
    }

    /* PUBLIC */
    /* @inheritdoc IArk */
    function totalAssets() public view virtual returns (uint256) {}

    /* @inheritdoc IArk */
    function rate() public view virtual returns (uint256) {}

    /* EXTERNAL - RAFT */
    /* @inheritdoc IArk */
    function harvest(address rewardToken, bytes calldata additionalData) external returns (uint256) {
        _updateRaft(manager.raft());
        return _harvest(rewardToken, additionalData);
    }

    /* EXTERNAL - COMMANDER */
    /* @inheritdoc IArk */
    function board(uint256 amount) external onlyAuthorizedToBoard(commander) {
        address msgSender = _msgSender();
        token.safeTransferFrom(msgSender, address(this), amount);
        _board(amount);

        emit Boarded(msgSender, address(token), amount);
    }

    /* @inheritdoc IArk */
    function disembark(uint256 amount) external onlyCommander {
        address msgSender = _msgSender();
        _disembark(amount);
        token.safeTransfer(msgSender, amount);

        emit Disembarked(msgSender, address(token), amount);
    }

    /* @inheritdoc IArk */
    function move(uint256 amount, address receiverArk) external onlyCommander {
        _disembark(amount);

        token.approve(receiverArk, amount);
        IArk(receiverArk).board(amount);

        emit Moved(address(this), receiverArk, address(token), amount);
    }

    /* @inheritdoc IArk */
    function setMaxAllocation(uint256 newMaxAllocation) external onlyCommander {
        maxAllocation = newMaxAllocation;
        emit MaxAllocationUpdated(newMaxAllocation);
    }

    /* @inheritdoc IArk */
    function poke() public virtual {}

    /* EXTERNAL - GOVERNANCE */

    /* @inheritdoc IArk */
    function _updateRaft(address newRaft) internal {}

    /**
     * @notice Hook executed before the Commander role is revoked
     * @dev Overrides the base implementation to prevent removal when assets are present
     */
    function _beforeGrantRoleHook(
        address newComander
    ) internal virtual override(ArkAccessManaged) onlyGovernor {
        if (commander != address(0)) {
            revert CannotAddCommanderToArkWithCommander();
        }
        commander = newComander;
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
        commander = address(0);
    }

    /* INTERNAL */
    function _board(uint256 amount) internal virtual;

    function _disembark(uint256 amount) internal virtual;

    function _harvest(address rewardToken, bytes calldata additionalData) internal virtual returns (uint256);
}
