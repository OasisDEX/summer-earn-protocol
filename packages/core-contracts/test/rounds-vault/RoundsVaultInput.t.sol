// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RoundsVaultInput} from "../../src/contracts/rounds-vault/RoundsVaultInput.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {IRoundsVaultInputEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultInputEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Corrected relative path to access-contracts
import {IProtocolAccessManager, ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {IRoundsVaultBaseEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEvents.sol";
import {IRoundsVaultBaseErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";

// Mock Access Manager to handle role checks
contract MockAccessManager {
    bytes32 public constant FOUNDATION_ROLE = keccak256("FOUNDATION_ROLE");
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

    // Support interface check
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return interfaceId == type(IProtocolAccessManager).interfaceId; // Mocking the interface ID check
    }
}

// Functional MockERC4626 for testing interaction
contract MockERC4626 is ERC4626VaultMock {
    uint256 public constant SCALE = 1e18;

    mapping(address => uint256) public shareBalances;

    constructor(address asset_) ERC4626VaultMock(asset_) {}

    function convertToShares(
        uint256 assets
    ) external pure override returns (uint256) {
        return assets; // 1:1 for simplicity in most tests
    }

    function convertToAssets(
        uint256 shares
    ) external pure override returns (uint256) {
        return shares; // 1:1 for simplicity in most tests
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256) {
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        shareBalances[receiver] += assets;
        return assets;
    }

    // Minimal previewDeposit for exchange rate calculation in _getCurrentExchangeRate
    function previewDeposit(
        uint256 assets
    ) external pure override returns (uint256) {
        return assets; // 1:1 exchange rate
    }

    function decimals() external pure override returns (uint8) {
        return 18;
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
}

contract RoundsVaultInputTest is
    Test,
    IRoundsVaultInputEvents,
    IRoundsVaultBaseEvents,
    IRoundsVaultBaseErrors
{
    RoundsVaultInput public vault;
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

        // Deploy RoundsVaultInput
        // Constructor args: targetVault, accessManager, receiptsURI
        vault = new RoundsVaultInput(
            address(targetVault),
            address(accessManager),
            "SomeURI"
        );

        // Grant KEEPER_ROLE to operator for the vault instance
        // Role generation logic from ProtocolAccessManaged: keccak256(abi.encodePacked(roleName, roleTargetContract))
        bytes32 specificKeeperRole = keccak256(
            abi.encodePacked(ContractSpecificRoles.KEEPER_ROLE, address(vault))
        );
        accessManager.grantRole(specificKeeperRole, operator);

        accessManager.grantRole(accessManager.GOVERNOR_ROLE(), admin);

        vm.prank(admin);
        vault.setWhitelisted(address(0), true);

        // Setup accounts
        vm.startPrank(unprivilegedAccount);
        assetToken.mint(unprivilegedAccount, 10 ether); // Mint plenty
        assetToken.approve(address(vault), 10 ether);
        vm.stopPrank();
    }

    function test_RIV0001_DefaultValue() public view {
        assertEq(vault.getCurrentRound(), 0);
        assertEq(vault.exchangeAsset(), address(targetVault));

        // Initial exchange rate for round 0 is 0 because it's not set until nextRound is called
        Price memory price = vault.getExchangeRate(0);
        assertEq(price.baseAmount, 0);
        assertEq(price.quoteAmount, 0);
    }

    function test_RIV0002_DepositRound0() public {
        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets, unprivilegedAccount);
        vm.stopPrank();

        // Started with 10. 10 - 0.2 = 9.8
        assertEq(assetToken.balanceOf(unprivilegedAccount), 9.8 ether);
        assertEq(vault.balanceOfAll(unprivilegedAccount), assets);
        assertEq(vault.balanceOf(unprivilegedAccount, 0), assets);
    }

    function test_RIV0003_NextRound() public {
        uint256 assets = 0.2 ether;
        uint256 shares = assets; // 1:1

        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets, unprivilegedAccount);
        vm.stopPrank();

        // Current round is 0
        assertEq(vault.getCurrentRound(), 0);

        vm.startPrank(operator);

        vm.expectEmit(true, false, false, true); // Don't match all topics if exact struct matching is tricky, but let's try matching.
        emit AssetsDeposited(0, operator, assets, shares);

        // Price struct is (baseAmount, quoteAmount)
        Price memory expectedPrice = Price(1e18, 1e18);

        vm.expectEmit(true, true, true, true);
        emit NextRound(1, expectedPrice);

        vault.nextRound();
        vm.stopPrank();

        assertEq(vault.getCurrentRound(), 1);
    }

    function test_RIV0004_DepositRound1() public {
        vm.prank(operator);
        vault.nextRound();

        assertEq(vault.getCurrentRound(), 1);

        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets, unprivilegedAccount);
        vm.stopPrank();

        assertEq(assetToken.balanceOf(unprivilegedAccount), 9.8 ether);
        assertEq(vault.balanceOfAll(unprivilegedAccount), assets);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), assets);
    }

    function test_RIV0005_DepositRedeemSameRound() public {
        vm.startPrank(operator);
        vault.nextRound(); // 0 -> 1
        vault.nextRound(); // 1 -> 2
        vm.stopPrank();

        assertEq(vault.getCurrentRound(), 2);

        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets, unprivilegedAccount);

        assertEq(assetToken.balanceOf(unprivilegedAccount), 9.8 ether);
        assertEq(vault.balanceOfAll(unprivilegedAccount), assets);
        assertEq(vault.balanceOf(unprivilegedAccount, 2), assets);

        // Try to redeemExchangeAsset (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(
                CannotRedeeemExchangeAssetCurrentRound.selector,
                2,
                2
            )
        );
        vault.redeemExchangeAsset(
            2,
            assets,
            unprivilegedAccount,
            unprivilegedAccount
        );

        // Redeem normal receipts
        vault.redeem(2, assets, unprivilegedAccount, unprivilegedAccount);

        assertEq(assetToken.balanceOf(unprivilegedAccount), 10 ether);
        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 2), 0);
        vm.stopPrank();
    }

    function test_RIV0006_DepositRedeemBatchSameRound() public {
        vm.startPrank(operator);
        vault.nextRound(); // 0 -> 1
        vault.nextRound(); // 1 -> 2
        vm.stopPrank();

        assertEq(vault.getCurrentRound(), 2);

        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets, unprivilegedAccount);

        assertEq(assetToken.balanceOf(unprivilegedAccount), 9.8 ether);
        assertEq(vault.balanceOfAll(unprivilegedAccount), assets);
        assertEq(vault.balanceOf(unprivilegedAccount, 2), assets);

        // Try to redeemExchangeAsset (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(
                CannotRedeeemExchangeAssetCurrentRound.selector,
                2,
                2
            )
        );
        vault.redeemExchangeAsset(
            2,
            assets,
            unprivilegedAccount,
            unprivilegedAccount
        );

        // Redeem Batch
        uint256[] memory ids = new uint256[](2);
        ids[0] = 2;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = assets / 2;
        amounts[1] = assets / 2;

        vault.redeemBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );

        assertEq(assetToken.balanceOf(unprivilegedAccount), 10 ether);
        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 2), 0);
        vm.stopPrank();
    }

    function test_RIV0007_DepositRedeemPreviousRound() public {
        vm.prank(operator);
        vault.nextRound(); // 0 -> 1

        assertEq(vault.getCurrentRound(), 1);

        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets, unprivilegedAccount);
        vm.stopPrank();

        assertEq(assetToken.balanceOf(unprivilegedAccount), 9.8 ether);
        assertEq(vault.balanceOfAll(unprivilegedAccount), assets);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), assets);

        // Advance round
        vm.startPrank(operator);
        vault.nextRound(); // 1 -> 2
        vault.setRoundSettled(1);
        vm.stopPrank();

        vm.startPrank(unprivilegedAccount);

        // Try to redeem normal (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(CanOnlyRedeemCurrentRound.selector, 1, 2)
        );
        vault.redeem(1, assets, unprivilegedAccount, unprivilegedAccount);

        // Redeem exchange asset
        // Mocks transfer nothing but we verify the call success and events ideally
        // In the TS test, it checks if targetVault.transfer was called.
        // Here we just check if it reverts or not.

        vault.redeemExchangeAsset(
            1,
            assets,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        // Verify that the user received the shares (targetVault tokens)
        assertEq(targetVault.balanceOf(unprivilegedAccount), assets);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), 0);
    }

    function test_RIV0008_DepositRedeemBatchPreviousRounds() public {
        vm.prank(operator);
        vault.nextRound(); // 0 -> 1

        uint256 assets = 0.2 ether;

        // Deposit half in Round 1
        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets / 2, unprivilegedAccount);
        vm.stopPrank();

        vm.prank(operator);
        vault.nextRound(); // 1 -> 2

        // Deposit half in Round 2
        vm.startPrank(unprivilegedAccount);
        vault.deposit(assets / 2, unprivilegedAccount);
        vm.stopPrank();

        vm.startPrank(operator);
        vault.nextRound(); // 2 -> 3
        
        uint256[] memory settleIds = new uint256[](2);
        settleIds[0] = 1;
        settleIds[1] = 2;
        vault.setRoundSettledBatch(settleIds);
        vm.stopPrank();

        vm.startPrank(unprivilegedAccount);

        // Try to redeem normal (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(CanOnlyRedeemCurrentRound.selector, 1, 3)
        );
        vault.redeem(1, assets / 2, unprivilegedAccount, unprivilegedAccount);

        // Redeem Batch Exchange Asset
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = assets / 2;
        amounts[1] = assets / 2;

        vault.redeemExchangeAssetBatch(
            ids,
            amounts,
            unprivilegedAccount,
            unprivilegedAccount
        );

        vm.stopPrank();

        assertEq(targetVault.balanceOf(unprivilegedAccount), assets);

        assertEq(vault.balanceOfAll(unprivilegedAccount), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 1), 0);
        assertEq(vault.balanceOf(unprivilegedAccount, 2), 0);
    }

    function test_RIV0009_RevertIfNotWhitelisted() public {
        // Disable open whitelist
        vm.prank(admin);
        vault.setWhitelisted(address(0), false);

        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.deposit(assets, unprivilegedAccount);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeem(0, assets, unprivilegedAccount, unprivilegedAccount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = assets;

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeemBatch(ids, amounts, unprivilegedAccount, unprivilegedAccount);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeemExchangeAsset(0, assets, unprivilegedAccount, unprivilegedAccount);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeemExchangeAssetBatch(ids, amounts, unprivilegedAccount, unprivilegedAccount);
        vm.stopPrank();
    }

    function test_RIV0010_RevertIfCallerNotWhitelisted() public {
        // We whitelist the receiver but not the caller
        address receiver = address(0x4);
        
        vm.prank(admin);
        vault.setWhitelisted(address(0), false);
        
        vm.prank(admin);
        vault.setWhitelisted(receiver, true);

        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.deposit(assets, receiver);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeem(0, assets, receiver, unprivilegedAccount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = assets;

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeemBatch(ids, amounts, receiver, unprivilegedAccount);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeemExchangeAsset(0, assets, receiver, unprivilegedAccount);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount));
        vault.redeemExchangeAssetBatch(ids, amounts, receiver, unprivilegedAccount);
        vm.stopPrank();
    }
}
