// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RoundsVaultInput} from "../../src/contracts/rounds-vault/RoundsVaultInput.sol";
import {RoundsVaultOutput} from "../../src/contracts/rounds-vault/RoundsVaultOutput.sol";
import {IRoundsVaultBaseErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {IRoundsVaultBaseEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEvents.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {MockAccessManager} from "../mocks/MockAccessManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {Test} from "forge-std/Test.sol";

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
        IProtocolAccessManagerV2(address(accessManager)).setWhitelistOpen(
            address(targetVault),
            true
        );

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

        // Redemption fails because remaining state (Target 0 + Receipts 500) < Min
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
        vm.startPrank(user);
        targetVault.deposit(500e6, user);

        // Succeeds because total (Target 500 + New 500) == Min
        inputVault.deposit(500e6, user);
        assertEq(inputVault.balanceOf(user, 0), 500e6);

        vm.stopPrank();
    }

    function test_MinPosition_Transfer_ChecksReceiverAndSender() public {
        vm.startPrank(user);
        inputVault.deposit(2000e6, user);

        // Fails because sender would be left with sub-minimum balance (500)
        vm.expectRevert(
            abi.encodeWithSelector(
                RoundsVaultPositionTooSmall.selector,
                user,
                500e6,
                MIN_POSITION
            )
        );
        inputVault.safeTransferFrom(user, otherUser, 0, 1500e6, "");

        // Succeeds when both sender and receiver are at/above minimum
        inputVault.safeTransferFrom(user, otherUser, 0, 1000e6, "");
        assertEq(inputVault.balanceOfAll(otherUser), 1000e6);
        assertEq(inputVault.balanceOfAll(user), 1000e6);
        vm.stopPrank();
    }

    function test_Whitelist_EnforcedOnTransfer() public {
        vm.prank(admin);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelistOpen(
            address(targetVault),
            false
        );
        vm.prank(admin);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(targetVault),
            user,
            true
        );

        address nonWhitelisted = address(0xDEADC0DE);
        vm.startPrank(user);
        inputVault.deposit(2000e6, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(targetVault),
                nonWhitelisted
            )
        );
        inputVault.safeTransferFrom(user, nonWhitelisted, 0, 1000e6, "");
        vm.stopPrank();
    }

    function test_MinPosition_Normalization_OutputVault_Reverts() public {
        vm.startPrank(user);
        targetVault.deposit(500e6, user);
        targetVault.approve(address(outputVault), 500e6);

        // Fails because remaining Target balance would be below minimum (400)
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

        // Full exit is allowed (Target balance goes to 0)
        outputVault.deposit(1000e6, user);
        assertEq(outputVault.balanceOfAll(user), 1000e6);
        assertEq(targetVault.balanceOf(user), 0);
        vm.stopPrank();
    }
}
