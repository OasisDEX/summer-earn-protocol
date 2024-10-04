// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

import {ArkConfig, ArkParams, IArk} from "../interfaces/IArk.sol";

import {IArkConfigProvider} from "../interfaces/IArkConfigProvider.sol";

import {ArkAccessManaged} from "./ArkAccessManaged.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ConfigurationManaged} from "./ConfigurationManaged.sol";
/**
 * @custom:see IArkConfigProvider
 */
abstract contract ArkConfigProvider is
    IArkConfigProvider,
    ArkAccessManaged,
    ConfigurationManaged
{
    ArkConfig public config;

    constructor(
        ArkParams memory _params
    )
        ArkAccessManaged(_params.accessManager)
        ConfigurationManaged(_params.configurationManager)
    {
        if (_params.configurationManager == address(0)) {
            revert CannotDeployArkWithoutConfigurationManager();
        }
        if (_params.token == address(0)) {
            revert CannotDeployArkWithoutToken();
        }
        if (bytes(_params.name).length == 0) {
            revert CannotDeployArkWithEmptyName();
        }
        if (configurationManager.raft() == address(0)) {
            revert CannotDeployArkWithoutRaft();
        }

        config = ArkConfig({
            token: IERC20(_params.token),
            commander: address(0), // Will be set later
            raft: configurationManager.raft(),
            depositCap: _params.depositCap,
            maxRebalanceOutflow: _params.maxRebalanceOutflow,
            maxRebalanceInflow: _params.maxRebalanceInflow,
            name: _params.name,
            requiresKeeperData: _params.requiresKeeperData
        });
    }

    /* EXTERNAL */
    function name() external view returns (string memory) {
        return config.name;
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
}
