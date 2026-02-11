// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {VaultDeferredOperationMock} from "../mocks/VaultDeferredOperationMock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {IVaultWithReceiptsEvents} from "../../src/interfaces/rounds-vault/IVaultWithReceiptsEvents.sol";

// Functional MockERC4626 for testing interaction
// Inherits from ERC4626VaultMock as requested
contract MockERC4626 is ERC4626VaultMock {
    constructor(address asset_) ERC4626VaultMock(asset_) {}

    function convertToShares(
        uint256 assets
    ) external pure override returns (uint256) {
        return assets; // 1:1 exchange rate
    }

    function convertToAssets(
        uint256 shares
    ) external pure override returns (uint256) {
        return shares; // 1:1 exchange rate
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256) {
        // Transfer assets from caller
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        // Mint shares (for this mock, we don't track shares balance, just transfer assets)
        return assets;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override returns (uint256) {
        // Transfer assets to receiver
        IERC20(underlying).transfer(receiver, shares);
        return shares;
    }

    // Explicitly override other pure virtual functions from base to resolve inheritance if needed
    // But since they are implemented in base as virtual, strictly we only need to override what we change or what is abstract.
    // In ERC4626VaultMock all are implemented (returning 0).
    // So we don't need to re-implement stubs unless we want to change behavior.
}

contract VaultDeferredOperationTest is Test, IVaultWithReceiptsEvents {
    VaultDeferredOperationMock public vaultDeferredOperation;
    MockERC20 public assetToken;
    MockERC4626 public targetVault;

    address public unprivilegedAccount = address(0x1);
    address public unprivilegedAccount2 = address(0x2);

    function setUp() public {
        assetToken = new MockERC20();
        assetToken.initialize("AssetToken", "AST", 18);

        targetVault = new MockERC4626(address(assetToken));

        vaultDeferredOperation = new VaultDeferredOperationMock(
            address(targetVault),
            "SomeURI"
        );

        // Set up accounts
        vm.startPrank(unprivilegedAccount);
        assetToken.mint(unprivilegedAccount, 1 ether);
        assetToken.approve(address(vaultDeferredOperation), 1 ether);
        vm.stopPrank();

        vm.startPrank(unprivilegedAccount2);
        assetToken.mint(unprivilegedAccount2, 1 ether);
        assetToken.approve(address(vaultDeferredOperation), 1 ether);
        vm.stopPrank();

        // Seed target vault with some assets so redeem works
        assetToken.mint(address(targetVault), 10 ether);
    }

    function test_VDO0001_DefaultValue() public view {
        assertEq(vaultDeferredOperation.vault(), address(targetVault));
        assertEq(vaultDeferredOperation.asset(), address(assetToken));
    }

    function test_VDO0002_DepositOnTarget() public {
        uint256 shares = 0.2 ether;
        uint256 assets = shares; // 1:1 in mock

        vm.startPrank(unprivilegedAccount);

        // Deposit into deferred vault first
        vaultDeferredOperation.deposit(assets, unprivilegedAccount);

        // Verify assets in deferred vault
        assertEq(assetToken.balanceOf(address(vaultDeferredOperation)), assets);

        // Deposit on target
        vaultDeferredOperation.depositOnTarget(assets);

        vm.stopPrank();

        // Verify deferred vault has 0 assets
        assertEq(assetToken.balanceOf(address(vaultDeferredOperation)), 0);
        // Verify target vault received assets
        // target vault started with 10, added 0.2 -> 10.2
        assertEq(assetToken.balanceOf(address(targetVault)), 10.2 ether);
    }

    function test_VDO0003_RedeemFromTarget() public {
        uint256 shares = 0.2 ether;
        uint256 assets = shares; // 1:1 in mock

        vm.startPrank(unprivilegedAccount);
        // 1. Deposit into deferred vault (User -> VDO)
        vaultDeferredOperation.deposit(assets, unprivilegedAccount);

        // Verify assets in VDO
        assertEq(assetToken.balanceOf(address(vaultDeferredOperation)), assets);

        // 2. Deposit on target (VDO -> Target)
        vaultDeferredOperation.depositOnTarget(assets);

        // Verify assets moved to target
        assertEq(assetToken.balanceOf(address(vaultDeferredOperation)), 0);
        // Target initialized with 10, +0.2 = 10.2
        assertEq(assetToken.balanceOf(address(targetVault)), 10.2 ether);

        // 3. Redeem from target (Target -> VDO)
        vaultDeferredOperation.redeemFromTarget(shares);

        vm.stopPrank();

        // Verify assets returned to VDO
        assertEq(assetToken.balanceOf(address(vaultDeferredOperation)), assets);
        // Verify assets removed from target (back to 10)
        assertEq(assetToken.balanceOf(address(targetVault)), 10 ether);
    }

    function test_VDO0004_FullCycle() public {
        uint256 shares = 0.2 ether;
        uint256 assets = shares; // 1:1 in mock

        vm.startPrank(unprivilegedAccount);

        // 1. Deposit into deferred vault (User -> VDO)
        vm.expectEmit(true, true, true, true);
        // emit DepositWithReceipt(caller, receiver, id, amount);
        emit DepositWithReceipt(
            unprivilegedAccount,
            unprivilegedAccount,
            0,
            assets
        );
        vaultDeferredOperation.deposit(assets, unprivilegedAccount);

        // 2. Deposit on target (VDO -> Target)
        vaultDeferredOperation.depositOnTarget(assets);

        // 3. Redeem from target (Target -> VDO)
        vaultDeferredOperation.redeemFromTarget(shares);

        // 4. Redeem from deferred vault (VDO -> User)
        // Need to check maxRedeem
        assertEq(vaultDeferredOperation.maxRedeem(unprivilegedAccount), assets);

        vm.expectEmit(true, true, true, true);
        // emit RedeemReceipt(caller, receiver, owner, id, amount);
        emit RedeemReceipt(
            unprivilegedAccount,
            unprivilegedAccount,
            unprivilegedAccount,
            0,
            assets
        );
        vaultDeferredOperation.redeem(
            0,
            assets,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        // Verify final state
        // VDO empty
        assertEq(assetToken.balanceOf(address(vaultDeferredOperation)), 0);
        // User has funds back (started with 1, deposited 0.2, got 0.2 back -> 1.0)
        assertEq(assetToken.balanceOf(unprivilegedAccount), 1 ether);
        // Receipt burned
        assertFalse(vaultDeferredOperation.exists(0));
    }
}
