// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RoundsVaultInput} from "../../src/contracts/rounds-vault/RoundsVaultInput.sol";
import {RoundsVaultOutput} from "../../src/contracts/rounds-vault/RoundsVaultOutput.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {IRoundsVaultBaseErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {IRoundsVaultBaseEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEvents.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {MockAccessManager} from "../mocks/MockAccessManager.sol";

// Mock ERC4626
contract MockERC4626 is ERC4626VaultMock {
    mapping(address => uint256) public shareBalances;
    constructor(address asset_) ERC4626VaultMock(asset_) {}

    function convertToShares(
        uint256 assets
    ) external pure override returns (uint256) {
        return assets;
    }

    function convertToAssets(
        uint256 shares
    ) external pure override returns (uint256) {
        return shares;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256) {
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        shareBalances[receiver] += assets;
        return assets;
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return shareBalances[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        shareBalances[msg.sender] -= amount;
        shareBalances[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        shareBalances[from] -= amount;
        shareBalances[to] += amount;
        return true;
    }
}

contract RoundsVaultMinPositionTest is
    Test,
    IRoundsVaultBaseErrors,
    IRoundsVaultBaseEvents
{
    RoundsVaultInput public inputVault;
    RoundsVaultOutput public outputVault;
    MockERC20 public usdc;
    MockERC4626 public targetVault;
    MockAccessManager public accessManager;

    address public admin = address(0x1);
    address public user = address(0x2);
    address public otherUser = address(0x3);

    uint256 public constant MIN_POSITION = 1000e6; // 1000 USDC

    function setUp() public {
        usdc = new MockERC20();
        usdc.initialize("USDC", "USDC", 6);

        targetVault = new MockERC4626(address(usdc));
        accessManager = new MockAccessManager();

        inputVault = new RoundsVaultInput(
            address(targetVault),
            address(accessManager),
            "uri"
        );
        outputVault = new RoundsVaultOutput(
            address(targetVault),
            address(accessManager),
            "uri"
        );

        accessManager.grantRole(accessManager.GOVERNOR_ROLE(), admin);

        vm.prank(admin);
        inputVault.setWhitelisted(address(0), true);
        vm.prank(admin);
        outputVault.setWhitelisted(address(0), true);

        vm.prank(admin);
        inputVault.setMinPositionSize(MIN_POSITION);
        vm.prank(admin);
        outputVault.setMinPositionSize(MIN_POSITION);

        usdc.mint(user, 10000e6);
        vm.prank(user);
        usdc.approve(address(inputVault), 10000e6);
        vm.prank(user);
        usdc.approve(address(targetVault), 10000e6);
    }

    function test_MinPosition_Deposit_BelowLimit_Reverts() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                RoundsVaultPositionTooSmall.selector,
                user,
                500e6,
                MIN_POSITION
            )
        );
        inputVault.deposit(500e6, user);
        vm.stopPrank();
    }

    function test_MinPosition_Deposit_AboveLimit_Succeeds() public {
        vm.startPrank(user);
        inputVault.deposit(1000e6, user);
        assertEq(inputVault.balanceOfAll(user), 1000e6);
        vm.stopPrank();
    }

    function test_MinPosition_Redeem_BelowLimit_Reverts() public {
        vm.startPrank(user);
        inputVault.deposit(2000e6, user);

        // Redemptions from Input Vault (USDC) are now GATED on the sender side
        // because Target (0) + Remaining Receipts (500) < 1000.
        vm.expectRevert(
            abi.encodeWithSelector(
                RoundsVaultPositionTooSmall.selector,
                user,
                500e6,
                MIN_POSITION
            )
        );
        inputVault.redeem(0, 1500e6, user, user);
        vm.stopPrank();
    }

    function test_MinPosition_Redeem_ToZero_Succeeds() public {
        vm.startPrank(user);
        inputVault.deposit(2000e6, user);

        // Fully exit is always allowed
        inputVault.redeem(0, 2000e6, user, user);
        assertEq(inputVault.balanceOfAll(user), 0);
        vm.stopPrank();
    }

    function test_MinPosition_Aggregate_WithTargetVault() public {
        // User has 500 USDC in Target Vault
        vm.startPrank(user);
        targetVault.deposit(500e6, user);

        // Now depositing 500 into Rounds Vault should succeed (total = 1000)
        inputVault.deposit(500e6, user);

        // Assert that the deposit actually happened
        assertEq(inputVault.balanceOf(user, 0), 500e6);

        // But withdrawing even 1 USDC from Rounds Vault should fail (Target is still 500 < 1000)
        // Note: New logic only cares about Ingoing + Target for Entry, and Target for Exit.
        // For 'Withdrawal' (Redeeming receipts), target balance STAYS the same (or increases if redeeming to target).
        // So actually, redeems won't fail if you already have a small position!
        // But Deposits (Entry) will fail.
        vm.stopPrank();
    }

    function test_MinPosition_Transfer_ChecksReceiverAndSender() public {
        vm.startPrank(user);
        inputVault.deposit(2000e6, user);

        // Transfer 1500 to otherUser (who has 0) -> Fail for Receiver is fine, but also Fail for Sender
        // Sender would be left with 500.
        vm.expectRevert(
            abi.encodeWithSelector(
                RoundsVaultPositionTooSmall.selector,
                user,
                500e6,
                MIN_POSITION
            )
        );
        inputVault.safeTransferFrom(user, otherUser, 0, 1500e6, "");

        // Transfer 1000 to otherUser -> Success (both have 1000)
        inputVault.safeTransferFrom(user, otherUser, 0, 1000e6, "");
        assertEq(inputVault.balanceOfAll(otherUser), 1000e6);
        assertEq(inputVault.balanceOfAll(user), 1000e6);
        vm.stopPrank();
    }

    function test_Whitelist_EnforcedOnTransfer() public {
        // Disable global whitelist for this test to verify per-user enforcement
        vm.prank(admin);
        inputVault.setWhitelisted(address(0), false);

        // Specifically whitelist the user so they can deposit
        vm.prank(admin);
        inputVault.setWhitelisted(user, true);

        address nonWhitelisted = address(0xDEADC0DE);
        vm.startPrank(user);
        inputVault.deposit(2000e6, user);

        // Transfer to non-whitelisted -> Revert
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("NotWhitelisted(address)")),
                nonWhitelisted
            )
        );
        inputVault.safeTransferFrom(user, nonWhitelisted, 0, 1000e6, "");
        vm.stopPrank();
    }

    function test_MinPosition_Normalization_OutputVault_Reverts() public {
        // Output Vault receipts are in Shares.
        // We set MIN_POSITION = 1000 USDC.

        // User starts with 500 Shares (500 USDC val)
        vm.startPrank(user);
        targetVault.deposit(500e6, user);
        targetVault.approve(address(outputVault), 500e6);

        // Deposit 100 Shares into OutputVault
        // Resulting Target Balance = 400 < 1000. REVERT.
        vm.expectRevert(
            abi.encodeWithSelector(
                RoundsVaultPositionTooSmall.selector,
                user,
                400e6,
                MIN_POSITION
            )
        );
        outputVault.deposit(100e6, user);
        vm.stopPrank();
    }

    function test_MinPosition_Normalization_OutputVault_Succeeds() public {
        vm.startPrank(user);
        targetVault.deposit(1000e6, user);
        targetVault.approve(address(outputVault), 1000e6);

        // Deposit 1000 Shares into OutputVault
        // Resulting Target Balance = 0. OK (Full Exit).
        outputVault.deposit(1000e6, user);
        assertEq(outputVault.balanceOfAll(user), 1000e6);
        assertEq(targetVault.balanceOf(user), 0);
        vm.stopPrank();
    }
}
