// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RoundsVaultOutput} from "../../src/contracts/rounds-vault/RoundsVaultOutput.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {IRoundsVaultOutputEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultOutputEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IProtocolAccessManager, ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {IRoundsVaultBaseEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEvents.sol";
import {IRoundsVaultBaseErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";

// Mock Access Manager
contract MockAccessManager {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

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

// Functional MockERC4626
contract MockERC4626 is ERC4626VaultMock {
    mapping(address => uint256) public shareBalances;

    constructor(address asset_) ERC4626VaultMock(asset_) {}

    function convertToShares(
        uint256 assets
    ) external pure override returns (uint256) {
        return assets; // 1:1
    }

    function convertToAssets(
        uint256 shares
    ) external pure override returns (uint256) {
        return shares; // 1:1
    }

    // Needed for vault.deposit() which does transferFrom logic on the asset (which is Shares here)
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

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return shareBalances[account];
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256) {
        // User sends Underlying -> Mock
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        // Mint shares
        shareBalances[receiver] += assets;
        return assets;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override returns (uint256) {
        require(shareBalances[owner] >= shares, "Insufficient shares");
        shareBalances[owner] -= shares;
        // Check if mock has enough underlying
        require(
            IERC20(underlying).balanceOf(address(this)) >= shares,
            "Mock: Insufficient underlying"
        );
        IERC20(underlying).transfer(receiver, shares);
        return shares;
    }

    function previewRedeem(
        uint256 shares
    ) external pure override returns (uint256) {
        return shares;
    }

    function maxRedeem(address owner) external view override returns (uint256) {
        return shareBalances[owner];
    }
}

contract RoundsVaultOutputTest is
    Test,
    IRoundsVaultOutputEvents,
    IRoundsVaultBaseEvents,
    IRoundsVaultBaseErrors
{
    RoundsVaultOutput public vault;
    MockERC20 public assetToken;
    MockERC4626 public targetVault;
    MockAccessManager public accessManager;

    address public admin = address(0x1);
    address public operator = address(0x2);
    address public unprivilegedAccount = address(0x3);

    function setUp() public {
        // 1. Underlying Asset (e.g. USDC)
        assetToken = new MockERC20();
        assetToken.initialize("AssetToken", "AST", 18);

        // 2. Target Vault (e.g. aUSDC). Asset is USDC.
        targetVault = new MockERC4626(address(assetToken));

        accessManager = new MockAccessManager();

        // 3. Output Vault.
        // Logic: Deposit targetVault (Shares). Retrieve assetToken (Underlying).
        vault = new RoundsVaultOutput(
            address(targetVault),
            address(accessManager),
            "SomeURI"
        );

        // Grant KEEPER_ROLE
        bytes32 specificKeeperRole = keccak256(
            abi.encodePacked(ContractSpecificRoles.KEEPER_ROLE, address(vault))
        );
        accessManager.grantRole(specificKeeperRole, operator);

        accessManager.grantRole(accessManager.GOVERNOR_ROLE(), admin);

        vm.prank(admin);
        vault.setWhitelisted(address(0), true);

        // Setup user with Shares
        vm.startPrank(unprivilegedAccount);
        // Mint underlying
        assetToken.mint(unprivilegedAccount, 10 ether);
        assetToken.approve(address(targetVault), 10 ether);
        // Deposit into target vault to get Shares
        targetVault.deposit(10 ether, unprivilegedAccount);
        vm.stopPrank();
    }

    function test_ROV0001_DefaultValue() public view {
        assertEq(vault.getCurrentRound(), 0);
        // exchangeAsset() should return what?
        // RoundsVaultBase returns _sharesToken.
        // In OutputVault, we expect to get back Assets.
        // But constructor sets _sharesToken = targetVault.
        // So this will behave as returning Shares.
        assertEq(vault.exchangeAsset(), address(assetToken));
    }

    function test_ROV0002_DepositRound0() public {
        uint256 sharesToDeposit = 1 ether;

        vm.startPrank(unprivilegedAccount);

        // Approve OutputVault to pull Shares (targetVault)
        // MockERC4626 inherits ERC4626VaultMock which mocks approve always returning true

        vault.deposit(sharesToDeposit, unprivilegedAccount);

        vm.stopPrank();

        // OutputVault should hold Keys (Shares)
        assertEq(targetVault.balanceOf(address(vault)), sharesToDeposit);
        assertEq(targetVault.balanceOf(unprivilegedAccount), 9 ether);

        assertEq(vault.balanceOfAll(unprivilegedAccount), sharesToDeposit);
    }

    function test_ROV0003_NextRound() public {
        uint256 sharesToDeposit = 1 ether;

        vm.prank(unprivilegedAccount);
        vault.deposit(sharesToDeposit, unprivilegedAccount);

        // Execute Round
        vm.startPrank(operator);

        // This should emit SharesRedeemed
        // RoundsVaultBase -> _operate -> _redeemFromTarget
        // _redeemFromTarget calls targetVault.redeem
        // targetVault.redeem transfers AssetToken to OutputVault

        vault.nextRound();
        vm.stopPrank();

        // OutputVault should now hold AssetToken (Underlying)
        assertEq(assetToken.balanceOf(address(vault)), sharesToDeposit);
        // And zero Shares
        assertEq(targetVault.balanceOf(address(vault)), 0);
    }

    function test_ROV0007_DepositRedeemPreviousRound() public {
        uint256 sharesToDeposit = 1 ether;

        vm.prank(unprivilegedAccount);
        vault.deposit(sharesToDeposit, unprivilegedAccount);

        vm.startPrank(operator);
        vault.nextRound(); // 0 -> 1
        vault.setRoundSettled(0);
        vm.stopPrank();

        // Now User redeems receipt from Round 0
        vm.startPrank(unprivilegedAccount);

        // This is where it might fail if RoundsVaultBase tries to send Shares
        vault.redeemExchangeAsset(
            0,
            sharesToDeposit,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        // User should have received Assets
        assertEq(assetToken.balanceOf(unprivilegedAccount), 1 ether);
    }

    function test_ROV0004_DepositRound1() public {
        // 1. Move to Round 1
        uint256 shares0 = 1 ether;
        vm.prank(unprivilegedAccount);
        vault.deposit(shares0, unprivilegedAccount);

        vm.prank(operator);
        vault.nextRound();

        // 2. Deposit Round 1
        uint256 shares1 = 2 ether;

        // The user needs more shares first
        vm.startPrank(unprivilegedAccount);
        assetToken.mint(unprivilegedAccount, 2 ether);
        assetToken.approve(address(targetVault), 2 ether);
        targetVault.deposit(2 ether, unprivilegedAccount);

        vault.deposit(shares1, unprivilegedAccount);
        vm.stopPrank();

        assertEq(vault.balanceOfAll(unprivilegedAccount), shares0 + shares1);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), shares1);
    }

    function test_ROV0005_DepositRedeemSameRound() public {
        uint256 shares = 1 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(shares, unprivilegedAccount);

        // Redeem from Round 0 (current) -> Should get back Shares
        uint256 returnedShares = vault.redeem(
            0,
            shares,
            unprivilegedAccount,
            unprivilegedAccount
        );
        vm.stopPrank();

        assertEq(returnedShares, shares);
        assertEq(targetVault.balanceOf(unprivilegedAccount), 10 ether); // Original balance
        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
    }

    function test_ROV0006_DepositRedeemBatchSameRound() public {
        uint256 shares = 1 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(shares, unprivilegedAccount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = shares;

        uint256 returnedShares = vault.redeemBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );
        vm.stopPrank();

        assertEq(returnedShares, shares);
        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
    }

    function test_ROV0008_DepositRedeemBatchPreviousRounds() public {
        // Round 0
        uint256 shares0 = 1 ether;
        vm.prank(unprivilegedAccount);
        vault.deposit(shares0, unprivilegedAccount);

        vm.prank(operator);
        vault.nextRound(); // 0 -> 1

        // Round 1
        uint256 shares1 = 2 ether;
        vm.startPrank(unprivilegedAccount);
        assetToken.mint(unprivilegedAccount, 2 ether);
        assetToken.approve(address(targetVault), 2 ether);
        targetVault.deposit(2 ether, unprivilegedAccount);
        vault.deposit(shares1, unprivilegedAccount);
        vm.stopPrank();

        vm.startPrank(operator);
        vault.nextRound(); // 1 -> 2
        
        uint256[] memory settleIds = new uint256[](2);
        settleIds[0] = 0;
        settleIds[1] = 1;
        vault.setRoundSettledBatch(settleIds);
        vm.stopPrank();

        // Redeem Batch (0 and 1) -> Should get Assets
        vm.startPrank(unprivilegedAccount);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = shares0;
        amounts[1] = shares1;

        uint256 returnedAssets = vault.redeemExchangeAssetBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );
        vm.stopPrank();

        // Expected assets = shares0 + shares1 (1:1 conversion in mock)
        assertEq(returnedAssets, shares0 + shares1);

        assertEq(assetToken.balanceOf(unprivilegedAccount), 3 ether);
    }

    function test_ROV0009_RevertIfNotWhitelisted() public {
        // Disable open whitelist
        vm.prank(admin);
        vault.setWhitelisted(address(0), false);

        uint256 shares = 1 ether;

        vm.startPrank(unprivilegedAccount);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.deposit(shares, unprivilegedAccount);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeem(0, shares, unprivilegedAccount, unprivilegedAccount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = shares;

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemExchangeAsset(
            0,
            shares,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemExchangeAssetBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );
        vm.stopPrank();
    }

    function test_ROV0010_RevertIfCallerNotWhitelisted() public {
        address receiver = address(0x4);

        // Disable open whitelist
        vm.prank(admin);
        vault.setWhitelisted(address(0), false);

        vm.prank(admin);
        vault.setWhitelisted(receiver, true);

        uint256 shares = 1 ether;

        vm.startPrank(unprivilegedAccount);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.deposit(shares, receiver);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeem(0, shares, receiver, unprivilegedAccount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = shares;

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemBatch(ids, amounts, receiver, unprivilegedAccount);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemExchangeAsset(0, shares, receiver, unprivilegedAccount);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemExchangeAssetBatch(
            ids,
            amounts,
            receiver,
            unprivilegedAccount
        );
        vm.stopPrank();
    }

    function test_ROV0011_RevertIfOwnerNotWhitelisted() public {
        address validCaller = address(0x4);
        address receiver = address(0x5);
        address owner = unprivilegedAccount; // not whitelisted

        // Disable open whitelist
        vm.prank(admin);
        vault.setWhitelisted(address(0), false);

        vm.startPrank(admin);
        vault.setWhitelisted(validCaller, true);
        vault.setWhitelisted(receiver, true);
        vm.stopPrank();

        uint256 shares = 1 ether;

        vm.startPrank(validCaller);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, owner)
        );
        vault.redeem(0, shares, receiver, owner);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = shares;

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, owner)
        );
        vault.redeemBatch(ids, amounts, receiver, owner);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, owner)
        );
        vault.redeemExchangeAsset(0, shares, receiver, owner);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, owner)
        );
        vault.redeemExchangeAssetBatch(
            ids,
            amounts,
            receiver,
            owner
        );
        vm.stopPrank();
    }

    function test_ROV0012_RevertIfReceiverNotWhitelisted() public {
        address validCaller = address(0x4);
        address receiver = address(0x5); // not whitelisted
        address owner = address(0x6);

        // Disable open whitelist
        vm.prank(admin);
        vault.setWhitelisted(address(0), false);

        vm.startPrank(admin);
        vault.setWhitelisted(validCaller, true);
        vault.setWhitelisted(owner, true);
        vm.stopPrank();

        uint256 shares = 1 ether;

        vm.startPrank(validCaller);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.deposit(shares, receiver);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeem(0, shares, receiver, owner);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = shares;

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeemBatch(ids, amounts, receiver, owner);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeemExchangeAsset(0, shares, receiver, owner);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeemExchangeAssetBatch(
            ids,
            amounts,
            receiver,
            owner
        );
        vm.stopPrank();
    }
}
