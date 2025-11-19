// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ArkParams} from "../../types/ArkTypes.sol";
import {ValidatedCallerBase} from "../intent/ValidatedCallerBase.sol";

/**
 * @title CrossChainArkLite
 * @notice Ark that simply holds the underlying asset and can perform arbitrary validated calls.
 * @dev Boarding leaves the tokens in this contract (no external protocol interaction).
 *      An external validator/registry is responsible for validating arbitrary calls.
 */
contract CrossChainArkLite is Ark, ValidatedCallerBase {
    using SafeERC20 for IERC20;

    /// @notice Additional assets reported by the keeper (e.g. off-chain or synthetic exposure)
    uint256 public keeperReportedAssets;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _params Ark parameters
     * @param _validationRegistry Address of the call validation registry
     */
    constructor(
        ArkParams memory _params,
        address _validationRegistry
    ) Ark(_params) ValidatedCallerBase(_validationRegistry) {}

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IArk
    function totalAssets() public view override returns (uint256) {
        // Sum of on-chain balance and keeper-reported additional exposure
        return keeperReportedAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL ARK IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc Ark
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        // All held assets are withdrawable
        return _balanceOfAsset();
    }

    /// @inheritdoc Ark
    function _board(uint256 amount, bytes calldata) internal override {
        keeperReportedAssets += amount;
    }

    /// @inheritdoc Ark
    function _disembark(uint256 amount, bytes calldata) internal override {
        keeperReportedAssets -= amount;
    }

    /// @inheritdoc Ark
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // No-op: this Ark does not handle yield-bearing positions by default
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    /// @inheritdoc Ark
    function _validateBoardData(bytes calldata) internal pure override {}

    /// @inheritdoc Ark
    function _validateDisembarkData(bytes calldata) internal pure override {}

    /*//////////////////////////////////////////////////////////////
                        KEEPER-REPORTED ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the additional assets to count on top of this Ark's balance.
     * @dev Only callable by the keeper; used to reflect off-chain or external exposure.
     * @param assets Additional assets to account for in `totalAssets`
     */
    function setKeeperReportedAssets(uint256 assets) external onlyKeeper {
        keeperReportedAssets = assets;
        emit KeeperReportedAssetsUpdated(assets);
    }

    /*//////////////////////////////////////////////////////////////
                        ARBITRARY CALL EXECUTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute an arbitrary call from the Ark after registry validation.
     * @dev For now, the registry is a mock that always returns true; this MUST be
     *      replaced with real validation logic before production.
     * @param target The target address to call
     * @param data The calldata for the call
     * @return result The raw returned data from the call
     */
    function executeCall(
        address target,
        bytes calldata data
    ) external onlyKeeper nonReentrant returns (bytes memory result) {
        return _executeValidatedCall(target, data);
    }

    /// @notice Emitted when the keeper updates the reported additional assets
    event KeeperReportedAssetsUpdated(uint256 assets);
}
