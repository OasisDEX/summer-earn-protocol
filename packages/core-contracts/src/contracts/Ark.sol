// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {CannotAddCommanderToArkWithCommander, CannotRemoveCommanderFromArkWithAssets} from "../errors/ArkErrors.sol";
import {IArk, ArkParams, ArkConfig} from "../interfaces/IArk.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../errors/AccessControlErrors.sol";
import "../errors/ArkErrors.sol";

/**
 * @custom:see IArk
 */
abstract contract Ark is IArk, ArkAccessManaged {
    using SafeERC20 for IERC20;

    ArkConfig public config;
    IConfigurationManager public manager;

    constructor(
        ArkParams memory _params
    ) ArkAccessManaged(_params.accessManager) {
        if (_params.configurationManager == address(0)) {
            revert CannotDeployArkWithoutConfigurationManager();
        }
        if (_params.token == address(0)) {
            revert CannotDeployArkWithoutToken();
        }
        if (bytes(_params.name).length == 0) {
            revert CannotDeployArkWithEmptyName();
        }
        manager = IConfigurationManager(_params.configurationManager);
        if (manager.raft() == address(0)) {
            revert CannotDeployArkWithoutRaft();
        }

        config = ArkConfig({
            token: IERC20(_params.token),
            commander: address(0), // Will be set later
            raft: manager.raft(),
            depositCap: _params.depositCap,
            moveFromMax: _params.moveFromMax,
            moveToMax: _params.moveToMax,
            name: _params.name
        });
    }

    /* PUBLIC */
    function name() public view returns (string memory) {
        return config.name;
    }

    function raft() public view returns (address) {
        return config.raft;
    }

    function depositCap() public view returns (uint256) {
        return config.depositCap;
    }

    function token() public view returns (IERC20) {
        return config.token;
    }

    function commander() public view returns (address) {
        return config.commander;
    }

    function moveFromMax() public view returns (uint256) {
        return config.moveFromMax;
    }

    function moveToMax() public view returns (uint256) {
        return config.moveToMax;
    }

    /* @inheritdoc IArk */
    function totalAssets() public view virtual returns (uint256) {}

    /* @inheritdoc IArk */
    function rate() public view virtual returns (uint256) {}

    /* EXTERNAL - RAFT */
    /* @inheritdoc IArk */
    function harvest(
        address rewardToken,
        bytes calldata additionalData
    ) external returns (uint256) {
        _updateRaft(manager.raft());
        return _harvest(rewardToken, additionalData);
    }

    /* EXTERNAL - COMMANDER */
    /* @inheritdoc IArk */
    function board(
        uint256 amount
    ) external onlyAuthorizedToBoard(config.commander) {
        address msgSender = _msgSender();
        config.token.safeTransferFrom(msgSender, address(this), amount);
        _board(amount);

        emit Boarded(msgSender, address(config.token), amount);
    }

    /* @inheritdoc IArk */
    function disembark(uint256 amount) external onlyCommander {
        address msgSender = _msgSender();
        _disembark(amount);
        config.token.safeTransfer(msgSender, amount);

        emit Disembarked(msgSender, address(config.token), amount);
    }

    /* @inheritdoc IArk */
    function move(uint256 amount, address receiverArk) external onlyCommander {
        _disembark(amount);

        config.token.approve(receiverArk, amount);
        IArk(receiverArk).board(amount);

        emit Moved(address(this), receiverArk, address(config.token), amount);
    }

    /* @inheritdoc IArk */
    function setDepositCap(uint256 newDepositCap) external onlyCommander {
        config.depositCap = newDepositCap;
        emit MaxAllocationUpdated(newDepositCap);
    }

    function setMoveFromMax(uint256 newMoveFromMax) external onlyCommander {
        config.moveFromMax = newMoveFromMax;
        emit MoveFromMaxUpdated(newMoveFromMax);
    }

    function setMoveToMax(uint256 newMoveToMax) external onlyCommander {
        config.moveToMax = newMoveToMax;
        emit MoveToMaxUpdated(newMoveToMax);
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
        if (config.commander != address(0)) {
            revert CannotAddCommanderToArkWithCommander();
        }
        config.commander = newComander;
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
        config.commander = address(0);
    }

    /* INTERNAL */
    function _board(uint256 amount) internal virtual;

    function _disembark(uint256 amount) internal virtual;

    function _harvest(
        address rewardToken,
        bytes calldata additionalData
    ) internal virtual returns (uint256);
}
