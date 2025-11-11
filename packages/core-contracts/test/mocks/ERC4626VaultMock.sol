// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC4626VaultMock is IERC4626 {
    address public immutable underlying;

    constructor(address asset_) {
        underlying = asset_;
    }

    function asset() external view override returns (address) {
        return underlying;
    }

    // Minimal stubs to satisfy interface; not used by tests
    function totalAssets() external pure override returns (uint256) {
        return 0;
    }
    function convertToShares(uint256) external pure override returns (uint256) {
        return 0;
    }
    function convertToAssets(uint256) external pure override returns (uint256) {
        return 0;
    }
    function maxDeposit(address) external pure override returns (uint256) {
        return 0;
    }
    function previewDeposit(uint256) external pure override returns (uint256) {
        return 0;
    }
    function deposit(
        uint256,
        address
    ) external pure override returns (uint256) {
        return 0;
    }
    function maxMint(address) external pure override returns (uint256) {
        return 0;
    }
    function previewMint(uint256) external pure override returns (uint256) {
        return 0;
    }
    function mint(uint256, address) external pure override returns (uint256) {
        return 0;
    }
    function maxWithdraw(address) external pure override returns (uint256) {
        return 0;
    }
    function previewWithdraw(uint256) external pure override returns (uint256) {
        return 0;
    }
    function withdraw(
        uint256,
        address,
        address
    ) external pure override returns (uint256) {
        return 0;
    }
    function maxRedeem(address) external pure override returns (uint256) {
        return 0;
    }
    function previewRedeem(uint256) external pure override returns (uint256) {
        return 0;
    }
    function redeem(
        uint256,
        address,
        address
    ) external pure override returns (uint256) {
        return 0;
    }

    // IERC20-like methods for shares token of the vault
    function name() external pure returns (string memory) {
        return "VaultMock";
    }
    function symbol() external pure returns (string memory) {
        return "vMOCK";
    }
    function decimals() external pure returns (uint8) {
        return 18;
    }
    function totalSupply() external pure returns (uint256) {
        return 0;
    }
    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
    function transferFrom(
        address,
        address,
        uint256
    ) external pure returns (bool) {
        return true;
    }
}
