// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

import {ArkConfig, ArkParams, IArk} from "../interfaces/IArk.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

import {Constants} from "../utils/Constants.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @custom:see IArk
 */
abstract contract Ark is IArk, ArkAccessManaged, Constants {
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
            maxRebalanceOutflow: _params.maxRebalanceOutflow,
            maxRebalanceInflow: _params.maxRebalanceInflow,
            name: _params.name,
            requiresKeeperData: _params.requiresKeeperData
        });
    }

    /**
     * @notice Modifier to validate board data.
     * @dev This modifier calls `_validateCommonData` and `_validateBoardData` to ensure the data is valid.
     * In the base Ark contract, we use generic bytes for the data. It is the responsibility of the Ark
     * implementing contract to override the `_validateBoardData` function to provide specific validation logic.
     * @param data The data to be validated.
     */
    modifier validateBoardData(bytes calldata data) {
        _validateCommonData(data);
        _validateBoardData(data);
        _;
    }

    /**
     * @notice Modifier to validate disembark data.
     * @dev This modifier calls `_validateCommonData` and `_validateDisembarkData` to ensure the data is valid.
     * In the base Ark contract, we use generic bytes for the data. It is the responsibility of the Ark
     * implementing contract to override the `_validateDisembarkData` function to provide specific validation logic.
     * @param data The data to be validated.
     */
    modifier validateDisembarkData(bytes calldata data) {
        _validateCommonData(data);
        _validateDisembarkData(data);
        _;
    }

    /* EXTERNAL */
    function name() external view returns (string memory) {
        return config.name;
    }

    /* @inheritdoc IArk */
    function raft() external view returns (address) {
        return config.raft;
    }

    /* @inheritdoc IArk */
    function depositCap() external view returns (uint256) {
        return config.depositCap;
    }

    /* @inheritdoc IArk */
    function token() external view returns (IERC20) {
        return config.token;
    }

    /* @inheritdoc IArk */
    function commander() external view returns (address) {
        return config.commander;
    }

    /* @inheritdoc IArk */
    function maxRebalanceOutflow() external view returns (uint256) {
        return config.maxRebalanceOutflow;
    }

    /* @inheritdoc IArk */
    function maxRebalanceInflow() external view returns (uint256) {
        return config.maxRebalanceInflow;
    }

    /* @inheritdoc IArk */
    function requiresKeeperData() external view returns (bool) {
        return config.requiresKeeperData;
    }

    /* @inheritdoc IArk */
    function totalAssets() external view virtual returns (uint256) {}

    /* @inheritdoc IArk */
    function rate() external view virtual returns (uint256) {}

    /* EXTERNAL - RAFT */
    /* @inheritdoc IArk */
    function harvest(
        bytes calldata additionalData
    )
        external
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        _updateRaft(manager.raft());
        (rewardTokens, rewardAmounts) = _harvest(additionalData);
        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /* EXTERNAL - COMMANDER */
    /* @inheritdoc IArk */
    function board(
        uint256 amount,
        bytes calldata boardData
    )
        external
        onlyAuthorizedToBoard(config.commander)
        validateBoardData(boardData)
    {
        address msgSender = _msgSender();
        config.token.safeTransferFrom(msgSender, address(this), amount);
        _board(amount, boardData);

        emit Boarded(msgSender, address(config.token), amount);
    }

    /* @inheritdoc IArk */
    function disembark(
        uint256 amount,
        bytes calldata disembarkData
    ) external onlyCommander validateDisembarkData(disembarkData) {
        address msgSender = _msgSender();
        _disembark(amount, disembarkData);
        config.token.safeTransfer(msgSender, amount);

        emit Disembarked(msgSender, address(config.token), amount);
    }

    /* @inheritdoc IArk */
    function move(
        uint256 amount,
        address receiverArk,
        bytes calldata boardData,
        bytes calldata disembarkData
    ) external onlyCommander validateDisembarkData(disembarkData) {
        _disembark(amount, disembarkData);

        config.token.approve(receiverArk, amount);
        IArk(receiverArk).board(amount, boardData);

        emit Moved(address(this), receiverArk, address(config.token), amount);
    }

    /* @inheritdoc IArk */
    function setDepositCap(uint256 newDepositCap) external onlyCommander {
        config.depositCap = newDepositCap;
        emit DepositCapUpdated(newDepositCap);
    }

    /* @inheritdoc IArk */
    function setMaxRebalanceOutflow(
        uint256 newMaxRebalanceOutflow
    ) external onlyCommander {
        config.maxRebalanceOutflow = newMaxRebalanceOutflow;
        emit MaxRebalanceOutflowUpdated(newMaxRebalanceOutflow);
    }

    /* @inheritdoc IArk */
    function setMaxRebalanceInflow(
        uint256 newMaxRebalanceInflow
    ) external onlyCommander {
        config.maxRebalanceInflow = newMaxRebalanceInflow;
        emit MaxRebalanceInflowUpdated(newMaxRebalanceInflow);
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
        address newCommander
    ) internal virtual override(ArkAccessManaged) onlyGovernor {
        if (config.commander != address(0)) {
            revert CannotAddCommanderToArkWithCommander();
        }
        config.commander = newCommander;
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
    /**
     * @notice Internal function to handle the boarding (depositing) of assets
     * @dev This function should be implemented by derived contracts to define specific boarding logic
     * @param amount The amount of assets to board
     * @param data Additional data for boarding, interpreted by the specific Ark implementation
     */
    function _board(uint256 amount, bytes calldata data) internal virtual;

    /**
     * @notice Internal function to handle the disembarking (withdrawing) of assets
     * @dev This function should be implemented by derived contracts to define specific disembarking logic
     * @param amount The amount of assets to disembark
     * @param data Additional data for disembarking, interpreted by the specific Ark implementation
     */
    function _disembark(uint256 amount, bytes calldata data) internal virtual;

    /**
     * @notice Internal function to handle the harvesting of rewards
     * @dev This function should be implemented by derived contracts to define specific harvesting logic
     * @param additionalData Additional data for harvesting, interpreted by the specific Ark implementation
     * @return rewardTokens The addresses of the reward tokens harvested
     * @return rewardAmounts The amounts of the reward tokens harvested
     */
    function _harvest(
        bytes calldata additionalData
    )
        internal
        virtual
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);

    /**
     * @notice Internal function to validate boarding data
     * @dev This function should be implemented by derived contracts to define specific boarding data validation
     * @param data The boarding data to validate
     */
    function _validateBoardData(bytes calldata data) internal virtual;

    /**
     * @notice Internal function to validate disembarking data
     * @dev This function should be implemented by derived contracts to define specific disembarking data validation
     * @param data The disembarking data to validate
     */
    function _validateDisembarkData(bytes calldata data) internal virtual;

    /**
     * @notice Internal function to validate the presence or absence of additional data based on withdrawal restrictions
     * @dev This function checks if the data length is consistent with the Ark's withdrawal restrictions
     * @param data The data to validate
     */
    function _validateCommonData(bytes calldata data) internal view {
        if (data.length > 0 && config.requiresKeeperData) {
            revert CannotUseKeeperDataWhenNorRequired();
        }
        if (data.length == 0 && !config.requiresKeeperData) {
            revert KeeperDataRequired();
        }
    }

    /**
     * @notice Internal function to get the balance of the Ark's asset
     * @dev This function returns the balance of the Ark's token held by this contract
     * @return The balance of the Ark's asset
     */
    function _balanceOfAsset() internal view virtual returns (uint256) {
        return config.token.balanceOf(address(this));
    }
}
