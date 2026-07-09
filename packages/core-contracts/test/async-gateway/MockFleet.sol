// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Minimal configurable-rate ERC-4626 stand-in for the FleetCommander.
///      shares = assets * 1e18 / assetsPerShare; assets = shares * assetsPerShare / 1e18.
contract MockFleet is ERC20 {
    using Math for uint256;

    address public immutable ASSET;
    uint256 public assetsPerShare = 1e18; // 1:1 by default

    constructor(address asset_) ERC20("Mock Fleet Share", "mfSHARE") {
        ASSET = asset_;
    }

    function asset() external view returns (address) {
        return ASSET;
    }

    function setAssetsPerShare(uint256 newRate) external {
        assetsPerShare = newRate;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets.mulDiv(1e18, assetsPerShare);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares.mulDiv(assetsPerShare, 1e18);
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        SafeERC20.safeTransferFrom(
            IERC20(ASSET),
            msg.sender,
            address(this),
            assets
        );
        shares = convertToShares(assets);
        _mint(receiver, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets) {
        require(owner == msg.sender, "MockFleet: owner must be caller");
        _burn(owner, shares);
        assets = convertToAssets(shares);
        SafeERC20.safeTransfer(IERC20(ASSET), receiver, assets);
    }
}
