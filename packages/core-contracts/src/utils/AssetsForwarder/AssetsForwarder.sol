// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {Whitelist} from "../Whitelist/Whitelist.sol";
import {IWhitelist} from "../Whitelist/IWhitelist.sol";
import {IAssetsForwarder} from "./IAssetsForwarder.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/**
 * @title AssetsForwarder
 * @notice Contract that forwards assets from whitelisted senders or its own balance to target addresses
 */
contract AssetsForwarder is
    IAssetsForwarder,
    Context,
    ProtocolAccessManaged,
    Whitelist,
    ERC721Holder
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the AssetsForwarder contract
     * @param accessManager Address of the ProtocolAccessManager contract
     */
    constructor(address accessManager) ProtocolAccessManaged(accessManager) {
        // Empty on purpose
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///@inheritdoc IAssetsForwarder
    function forwardAsset(
        address targetAddress,
        address asset,
        uint256 amount
    ) external onlyWhitelisted(_msgSender()) onlyWhitelisted(targetAddress) {
        _validateInputs(targetAddress, asset, amount);

        _transferAsset(_msgSender(), targetAddress, asset, amount);

        emit AssetForwarded(_msgSender(), targetAddress, asset, amount);
    }

    ///@inheritdoc IAssetsForwarder
    function sendAsset(
        address targetAddress,
        address asset,
        uint256 amount
    ) external onlyWhitelisted(_msgSender()) onlyWhitelisted(targetAddress) {
        _validateInputs(targetAddress, asset, amount);

        _transferAsset(address(this), targetAddress, asset, amount);

        emit AssetSent(targetAddress, asset, amount);
    }

    ///@inheritdoc IAssetsForwarder
    function sweepAsset(address asset, uint256 amount) external onlyKeeper {
        if (asset == address(0)) revert InvalidAssetAddress();
        if (amount == 0) revert ZeroAmount();

        _transferAsset(address(this), _msgSender(), asset, amount);

        emit AssetSwept(_msgSender(), asset, amount);
    }

    ///@inheritdoc Whitelist
    function setWhitelisted(
        address account,
        bool allowed
    ) external override(IWhitelist, Whitelist) onlyGovernor {
        _setWhitelisted(account, allowed);
    }

    ///@inheritdoc Whitelist
    function setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) external override(IWhitelist, Whitelist) onlyGovernor {
        _setWhitelistedBatch(accounts, allowed);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to handle the transfer of assets
     * @param from The address to pull assets from
     * @param to The address to send assets to
     * @param asset The address of the asset to transfer
     * @param amount The amount of assets to transfer
     */
    function _transferAsset(
        address from,
        address to,
        address asset,
        uint256 amount
    ) internal {
        if (from == address(this)) {
            IERC20(asset).safeTransfer(to, amount);
        } else {
            IERC20(asset).safeTransferFrom(from, to, amount);
        }
    }

    /**
     * @notice Internal function to validate common inputs
     * @param targetAddress The target address
     * @param asset The asset address
     * @param amount The amount
     */
    function _validateInputs(
        address targetAddress,
        address asset,
        uint256 amount
    ) internal pure {
        if (targetAddress == address(0)) revert InvalidTargetAddress();
        if (asset == address(0)) revert InvalidAssetAddress();
        if (amount == 0) revert ZeroAmount();
    }
}
