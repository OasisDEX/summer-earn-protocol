// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RoundsOutputVault} from "../../src/contracts/rounds-vault/RoundsOutputVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {IRoundsOutputVaultEvents} from "../../src/interfaces/rounds-vault/IRoundsOutputVaultEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IProtocolAccessManager, ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {IBaseRoundsVaultEvents} from "../../src/interfaces/rounds-vault/IBaseRoundsVaultEvents.sol";
import {IBaseRoundsVaultErrors} from "../../src/interfaces/rounds-vault/IBaseRoundsVaultErrors.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

// Mock Access Manager to handle role checks (Reused from RoundInputVault.t.sol pattern)
contract MockAccessManager {
    mapping(bytes32 => mapping(address => bool)) public roles;

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool) {
        return roles[role][account];
    }

    function grantRole(bytes32 role, address account) external {
        roles[role][account] = true;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return interfaceId == type(IProtocolAccessManager).interfaceId;
    }
}

// Functional MockERC4626 for testing interaction (Reused from RoundInputVault.t.sol pattern)
contract MockERC4626 is ERC4626VaultMock {
    mapping(address => uint256) public shareBalances;

    constructor(address asset_) ERC4626VaultMock(asset_) {}

    function convertToShares(
        uint256 assets
    ) external pure override returns (uint256) {
        return assets; // 1:1 for simplicity
    }

    function convertToAssets(
        uint256 shares
    ) external pure override returns (uint256) {
        return shares; // 1:1 for simplicity
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256) {
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        shareBalances[receiver] += assets;
        return assets;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override returns (uint256) {
        require(shareBalances[owner] >= shares, "Insufficient shares");
        // Burn shares
        shareBalances[owner] -= shares;

        // Transfer assets to receiver
        // Note: The vault must hold assets. In tests we'll mint assets to it.
        IERC20(underlying).transfer(receiver, shares); // 1:1 assets per share

        return shares;
    }

    function previewRedeem(
        uint256 shares
    ) external pure override returns (uint256) {
        return shares; // 1:1 exchange rate
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return shareBalances[account];
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        require(shareBalances[from] >= amount, "Insufficient balance");
        shareBalances[from] -= amount;
        shareBalances[to] += amount;
        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        require(shareBalances[msg.sender] >= amount, "Insufficient balance");
        shareBalances[msg.sender] -= amount;
        shareBalances[to] += amount;
        return true;
    }
}

contract RoundsOutputVaultTest is
    Test,
    IRoundsOutputVaultEvents,
    IBaseRoundsVaultEvents,
    IBaseRoundsVaultErrors
{
    RoundsOutputVault public vault;
    MockERC20 public assetToken;
    MockERC4626 public targetVault;
    MockAccessManager public accessManager;

    address public admin = address(0x1);
    address public operator = address(0x2);
    address public unprivilegedAccount = address(0x3);

    function setUp() public {
        assetToken = new MockERC20();
        assetToken.initialize("AssetToken", "AST", 18);

        targetVault = new MockERC4626(address(assetToken));

        accessManager = new MockAccessManager();

        // Deploy RoundsOutputVault
        vault = new RoundsOutputVault(
            address(targetVault),
            address(accessManager),
            "SomeURI"
        );

        // Grant KEEPER_ROLE to operator
        bytes32 specificKeeperRole = keccak256(
            abi.encodePacked(ContractSpecificRoles.KEEPER_ROLE, address(vault))
        );
        accessManager.grantRole(specificKeeperRole, operator);

        // Setup accounts
        // We need shares ("Asset" of this vault is targetVault shares) to deposit into RoundsOutputVault.
        // So User deposits underlying (assetToken) into targetVault to get shares.
        // Then User deposits shares into RoundsOutputVault.

        vm.startPrank(unprivilegedAccount);
        assetToken.mint(unprivilegedAccount, 10 ether);
        assetToken.approve(address(targetVault), 10 ether);
        // Deposit 10 ether into targetVault to get 10 ether shares
        targetVault.deposit(10 ether, unprivilegedAccount);

        // Approve RoundsOutputVault to spend shares (targetVault is the token here)
        // Since MockERC4626 is the token for shares.
        // Wait, ERC4626VaultMock inherits IERC4626 but MockERC4626 doesn't implement approve explicitly?
        // ERC4626VaultMock stubs approve/allowance. We need to implement them in MockERC4626 properly if we use transferFrom.
        // Actually, let's verify MockERC4626 in RoundInputVault.t.sol.
        // It stubs transferFrom but not approve/allowance in the MockERC4626 body, but ERC4626VaultMock has them returning true/0.
        // For transferFrom to work in standard ERC20, allowance must be checked.
        // But in our MockERC4626.transferFrom, we verify balances but NOT allowance for simplicity (user approves via standard flow but mock ignores allowance check or we override it).
        // Let's implement approve/allowance in MockERC4626 to be safe or just assume infinite approval for tests.
        // The ERC4626VaultMock has `approve` returning true and `allowance` returning 0.
        // Simplest is to override transferFrom to NOT check allowance or just implement allowance.
        // Let's assume implicity approval for test simplicity or rely on `approve` returning true.
        vm.stopPrank();
    }

    function test_ROV0001_DefaultValue() public view {
        assertEq(vault.getCurrentRound(), 0);
        assertEq(vault.exchangeAsset(), address(assetToken));
        // Wait: exchangeAsset of OutputVault is the underlying of the target vault?
        // RoundsOutputVault.sol imports BaseRoundsVault. BaseRoundsVault has immutable `exchangeAsset`.
        // RoundsOutputVault constructor passes `targetVault` to BaseRoundsVault constructor.
        // BaseRoundsVault: `asset = IERC4626(targetVault).asset(); exchangeAsset = asset;`
        // So yes, exchangeAsset is the Underlying Asset (assetToken).

        Price memory price = vault.getExchangeRate(0);
        assertEq(UD60x18.unwrap(price.baseAmount), 0);
        assertEq(UD60x18.unwrap(price.quoteAmount), 0);
    }

    function test_ROV0002_DepositRound0() public {
        uint256 sharesToDeposit = 1 ether;

        // User has shares of targetVault.
        vm.startPrank(unprivilegedAccount);

        // Approve vault to pull shares
        // targetVault.approve(address(vault), sharesToDeposit);
        // (MockERC4626's approve returns true, but doesn't store allowance. transferFrom doesn't check allowance. So it works.)

        vault.deposit(sharesToDeposit, unprivilegedAccount);

        vm.stopPrank();

        // Check balances
        assertEq(targetVault.balanceOf(unprivilegedAccount), 9 ether); // 10 - 1
        assertEq(targetVault.balanceOf(address(vault)), sharesToDeposit); // Vault holds shares

        assertEq(vault.balanceOfAll(unprivilegedAccount), sharesToDeposit);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), sharesToDeposit);
    }

    function test_ROV0003_NextRound() public {
        uint256 sharesToDeposit = 1 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(sharesToDeposit, unprivilegedAccount);
        vm.stopPrank();

        // Prepare targetVault with assets to fulfill redemption
        // Vault will redeem shares `sharesToDeposit` for assets. 1:1.
        // TargetVault needs `sharesToDeposit` worth of assetToken.
        assetToken.mint(address(targetVault), sharesToDeposit);

        vm.startPrank(operator);

        // Expect SharesRedeemed event
        vm.expectEmit(true, true, true, true);
        emit SharesRedeemed(0, operator, sharesToDeposit, sharesToDeposit); // 1:1

        // Expect NextRound event
        Price memory expectedPrice = Price(ud(1e18), ud(1e18)); // 1:1
        vm.expectEmit(true, true, true, true);
        emit NextRound(1, expectedPrice);

        vault.nextRound();
        vm.stopPrank();

        assertEq(vault.getCurrentRound(), 1);

        // Vault should now hold ASSETS (assetToken), not shares
        assertEq(targetVault.balanceOf(address(vault)), 0);
        assertEq(assetToken.balanceOf(address(vault)), sharesToDeposit);
    }

    function test_ROV0004_DepositRound1() public {
        vm.startPrank(operator);
        vault.nextRound();
        vm.stopPrank();

        assertEq(vault.getCurrentRound(), 1);

        uint256 sharesToDeposit = 1 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(sharesToDeposit, unprivilegedAccount);
        vm.stopPrank();

        assertEq(vault.balanceOf(unprivilegedAccount, 1), sharesToDeposit);
        assertEq(targetVault.balanceOf(address(vault)), sharesToDeposit);
    }

    function test_ROV0005_DepositRedeemSameRound() public {
        vm.startPrank(operator);
        vault.nextRound(); // 0->1
        vault.nextRound(); // 1->2
        vm.stopPrank();

        uint256 sharesToDeposit = 1 ether;
        vm.startPrank(unprivilegedAccount);
        vault.deposit(sharesToDeposit, unprivilegedAccount);

        // Try to redeemExchangeAsset (should fail - only valid for previous rounds)
        // For OutputVault, "Exchange Asset" means the underlying asset (obtained after round close).
        // Current round deposits are still shares.
        vm.expectRevert(
            abi.encodeWithSelector(
                CannotRedeeemExchangeAssetCurrentRound.selector,
                2,
                2
            )
        );
        vault.redeemExchangeAsset(
            2,
            sharesToDeposit,
            unprivilegedAccount,
            unprivilegedAccount
        );

        // Redeem normal (withdraw shares back)
        vault.redeem(
            2,
            sharesToDeposit,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        assertEq(targetVault.balanceOf(unprivilegedAccount), 10 ether); // Back to full
        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
    }

    function test_ROV0006_DepositRedeemBatchSameRound() public {
        vm.startPrank(operator);
        vault.nextRound();
        vault.nextRound();
        vm.stopPrank();

        uint256 sharesToDeposit = 1 ether;
        vm.startPrank(unprivilegedAccount);
        vault.deposit(sharesToDeposit, unprivilegedAccount);

        vm.expectRevert(
            abi.encodeWithSelector(
                CannotRedeeemExchangeAssetCurrentRound.selector,
                2,
                2
            )
        );
        vault.redeemExchangeAsset(
            2,
            sharesToDeposit,
            unprivilegedAccount,
            unprivilegedAccount
        );

        // Batch Redeem
        uint256[] memory ids = new uint256[](2);
        ids[0] = 2;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = sharesToDeposit / 2;
        amounts[1] = sharesToDeposit / 2;

        vault.redeemBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        assertEq(targetVault.balanceOf(unprivilegedAccount), 10 ether);
    }

    function test_ROV0007_DepositRedeemPreviousRound() public {
        uint256 sharesToDeposit = 1 ether;

        // Deposit Round 0
        vm.startPrank(unprivilegedAccount);
        vault.deposit(sharesToDeposit, unprivilegedAccount);
        vm.stopPrank();

        // Fund targetVault for redemption
        assetToken.mint(address(targetVault), sharesToDeposit);

        // Next Round (0->1) - Vault converts shares to assets
        vm.prank(operator);
        vault.nextRound();

        vm.startPrank(unprivilegedAccount);

        // Try to redeem normal (should fail - can only redeem current round)
        vm.expectRevert(
            abi.encodeWithSelector(CanOnlyRedeemCurrentRound.selector, 0, 1)
        );
        vault.redeem(
            0,
            sharesToDeposit,
            unprivilegedAccount,
            unprivilegedAccount
        );

        // Redeem Exchange Asset (Get underlying assets)
        vault.redeemExchangeAsset(
            0,
            sharesToDeposit,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        // User should have original 10 ether (9 ether shares + 1 ether assets)
        // Wait, user still has 9 ether SHARES in targetVault.
        // And now should have 1 ether ASSETS in assetToken.
        // But user started with 10 ether ASSETS, converted 10 to SHARES.
        // So user has 9 shares + 1 asset.

        assertEq(targetVault.balanceOf(unprivilegedAccount), 9 ether);
        assertEq(assetToken.balanceOf(unprivilegedAccount), 1 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
    }

    function test_ROV0008_DepositRedeemBatchPreviousRounds() public {
        uint256 sharesToDeposit = 1 ether;

        // Round 0
        vm.prank(unprivilegedAccount);
        vault.deposit(sharesToDeposit / 2, unprivilegedAccount);

        assetToken.mint(address(targetVault), sharesToDeposit / 2);
        vm.prank(operator);
        vault.nextRound(); // 0->1

        // Round 1
        vm.prank(unprivilegedAccount);
        vault.deposit(sharesToDeposit / 2, unprivilegedAccount);

        assetToken.mint(address(targetVault), sharesToDeposit / 2);
        vm.prank(operator);
        vault.nextRound(); // 1->2

        vm.startPrank(unprivilegedAccount);

        vm.expectRevert(
            abi.encodeWithSelector(CanOnlyRedeemCurrentRound.selector, 0, 2)
        );
        vault.redeem(
            0,
            sharesToDeposit / 2,
            unprivilegedAccount,
            unprivilegedAccount
        );

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = sharesToDeposit / 2;
        amounts[1] = sharesToDeposit / 2;

        vault.redeemExchangeAssetBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        assertEq(assetToken.balanceOf(unprivilegedAccount), 1 ether);
    }
}
