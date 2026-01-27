// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockGainVault is ERC20, IERC4626 {
    IERC20 private _asset;
    address public gainAdapter;

    constructor(
        address asset_,
        address _gainAdapter
    ) ERC20("Gain Vault", "gvETH") {
        _asset = IERC20(asset_);
        gainAdapter = _gainAdapter;
    }

    function asset() public view override returns (address) {
        return address(_asset);
    }

    function totalAssets() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToShares(
        uint256 assets
    ) public view override returns (uint256) {
        return assets; // 1:1 for simplicity
    }

    function convertToAssets(
        uint256 shares
    ) public view override returns (uint256) {
        return shares; // 1:1
    }

    function maxDeposit(address) public view override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(
        address owner_
    ) public view override returns (uint256) {
        return convertToAssets(balanceOf(owner_));
    }

    function maxRedeem(address owner_) public view override returns (uint256) {
        return balanceOf(owner_);
    }

    function previewDeposit(
        uint256 assets
    ) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(
        uint256 shares
    ) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(
        uint256 assets
    ) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(
        uint256 shares
    ) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256) {
        uint256 shares = previewDeposit(assets);
        _asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override returns (uint256) {
        uint256 assets = previewMint(shares);
        _asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        return assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner_
    ) public override returns (uint256) {
        uint256 shares = previewWithdraw(assets);
        if (msg.sender != owner_) {
            _spendAllowance(owner_, msg.sender, shares);
        }
        _burn(owner_, shares);
        _asset.transfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
        return shares;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner_
    ) public override returns (uint256) {
        uint256 assets = previewRedeem(shares);
        if (msg.sender != owner_) {
            _spendAllowance(owner_, msg.sender, shares);
        }
        _burn(owner_, shares);
        _asset.transfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
        return assets;
    }

    // IGainVault specific
    function reserveDeposit(address account, uint256 amountInETH) external {
        // Mint shares based on amountInETH
        // In real vault, this uses oracle. Here 1:1.
        _mint(account, amountInETH);
    }

    function processWithdrawal(address account, uint256 shares) external {
        // Just burn shares
        _burn(account, shares);
        // In real vault, it registers request.
    }

    function managementFeePercent() external view returns (uint256) {
        return 0;
    }
    function managementFeeLastKnownTimestamp() external view returns (uint256) {
        return 0;
    }
    function calculateManagementFee(
        uint256,
        uint256
    ) external view returns (uint256) {
        return 0;
    }
    function updateIssuanceLimits(uint256, uint256, uint256) external {}
    function owner() external view returns (address) {
        return msg.sender;
    }
    function loansDeployerAddress() external view returns (address) {
        return msg.sender;
    }
    function scheduledCallerAddress() external view returns (address) {
        return msg.sender;
    }
    function settlementAccount() external view returns (address) {
        return msg.sender;
    }
    function pauseDepositsAndWithdrawals(bool, bool) external {}
}
