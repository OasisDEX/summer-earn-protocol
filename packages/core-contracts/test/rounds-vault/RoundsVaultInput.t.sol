// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RoundsVaultInput} from "../../src/contracts/rounds-vault/RoundsVaultInput.sol";
import {IRoundsVaultInputEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultInputEvents.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
// Corrected relative path to access-contracts
import {IRoundsVaultBaseEnums} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEnums.sol";
import {IRoundsVaultBaseErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {IRoundsVaultBaseEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEvents.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {MockAccessManager} from "../mocks/MockAccessManager.sol";

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

    // Minimal previewDeposit for exchange rate calculation in _getFallbackExchangeRate
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

        // Initial exchange rate for round 0 is 0 because it's not set until setRoundSettled is called
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

        // Price struct is (baseAmount, quoteAmount)
        Price memory expectedPrice = Price(assets, shares);

        // Settle round 0 should revert because it's Opened
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRoundState.selector,
                0,
                IRoundsVaultBaseEnums.RoundState.Opened,
                IRoundsVaultBaseEnums.RoundState.InSettlement
            )
        );
        vault.setRoundSettled(0);

        vm.expectEmit(true, false, false, true);
        emit RoundAdvanced(0);

        vault.nextRound();

        assertEq(vault.getCurrentRound(), 1);

        vm.expectEmit(true, false, false, true); // Don't match all topics if exact struct matching is tricky, but let's
        // try matching.
        emit AssetsDeposited(0, operator, assets, shares);

        vm.expectEmit(true, true, true, true);
        emit RoundSettled(0, expectedPrice);

        vault.setRoundSettled(0);
        vm.stopPrank();
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

        vault.setRoundSettled(1);
        vault.setRoundSettled(2);
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
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.deposit(assets, unprivilegedAccount);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeem(0, assets, unprivilegedAccount, unprivilegedAccount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = assets;

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
            assets,
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

    function test_RIV0010_RevertIfCallerNotWhitelisted() public {
        // We whitelist the receiver but not the caller
        address receiver = address(0x4);

        vm.prank(admin);
        vault.setWhitelisted(address(0), false);

        vm.prank(admin);
        vault.setWhitelisted(receiver, true);

        uint256 assets = 0.2 ether;

        vm.startPrank(unprivilegedAccount);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.deposit(assets, receiver);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeem(0, assets, receiver, unprivilegedAccount);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = assets;

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemBatch(ids, amounts, receiver, unprivilegedAccount);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, unprivilegedAccount)
        );
        vault.redeemExchangeAsset(0, assets, receiver, unprivilegedAccount);

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

    function test_RIV0013_SetRoundSettledRevertsIfInvalidState() public {
        vm.startPrank(operator); // keeper

        // Scenario 1: Round 0 is currently Opened (1)
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRoundState.selector,
                0,
                IRoundsVaultBaseEnums.RoundState.Opened,
                IRoundsVaultBaseEnums.RoundState.InSettlement
            )
        );
        vault.setRoundSettled(0);

        // Move to next round
        vault.nextRound(); // Round 0 -> InSettlement, Round 1 -> Opened

        // Scenario 2: Round 1 is Opened (1)
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRoundState.selector,
                1,
                IRoundsVaultBaseEnums.RoundState.Opened,
                IRoundsVaultBaseEnums.RoundState.InSettlement
            )
        );
        vault.setRoundSettled(1);

        // Success: Round 0 is InSettlement (2)
        vault.setRoundSettled(0); // Round 0 -> Settled

        // Scenario 3: Round 0 is already Settled (3)
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRoundState.selector,
                0,
                IRoundsVaultBaseEnums.RoundState.Settled,
                IRoundsVaultBaseEnums.RoundState.InSettlement
            )
        );
        vault.setRoundSettled(0);

        // Batch test
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRoundState.selector,
                1,
                IRoundsVaultBaseEnums.RoundState.Opened,
                IRoundsVaultBaseEnums.RoundState.InSettlement
            )
        );
        vault.setRoundSettled(1);
        vm.stopPrank();
    }

    function test_RIV0011_RevertIfOwnerNotWhitelisted() public {
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

        uint256 assets = 0.2 ether;

        vm.startPrank(validCaller);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, owner));
        vault.redeem(0, assets, receiver, owner);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = assets;

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, owner));
        vault.redeemBatch(ids, amounts, receiver, owner);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, owner));
        vault.redeemExchangeAsset(0, assets, receiver, owner);

        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, owner));
        vault.redeemExchangeAssetBatch(ids, amounts, receiver, owner);
        vm.stopPrank();
    }

    function test_RIV0012_RevertIfReceiverNotWhitelisted() public {
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

        uint256 assets = 0.2 ether;

        vm.startPrank(validCaller);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.deposit(assets, receiver);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeem(0, assets, receiver, owner);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = assets;

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeemBatch(ids, amounts, receiver, owner);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeemExchangeAsset(0, assets, receiver, owner);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        vault.redeemExchangeAssetBatch(ids, amounts, receiver, owner);
        vm.stopPrank();
    }

    function test_RIV0014_TransferUpdatesTotalSupply() public {
        uint256 assets = 0.2 ether;
        address accountA = unprivilegedAccount;
        address accountB = address(0xB);

        vm.prank(admin);
        vault.setWhitelisted(accountB, true);

        // 1. Deposit to accountA
        vm.startPrank(accountA);
        vault.deposit(assets, accountA);

        // Ensure accountA has the supply and accountB has 0
        assertEq(vault.balanceOfAll(accountA), assets);
        assertEq(vault.balanceOfAll(accountB), 0);

        // 2. Transfer NFT from accountA to accountB
        vault.safeTransferFrom(accountA, accountB, 0, assets, bytes(""));
        vm.stopPrank();

        // 3. Verify balanceOfAll properly tracks the transfer
        assertEq(vault.balanceOfAll(accountA), 0);
        assertEq(vault.balanceOfAll(accountB), assets);

        // Settle the round so we can call redeemExchangeAsset
        vm.startPrank(operator);
        vault.nextRound(); // 0 -> InSettlement
        vault.setRoundSettled(0); // 0 -> Settled
        vm.stopPrank();

        // 4. Redeem with target wallet
        vm.startPrank(accountB);
        vault.redeemExchangeAsset(0, assets, accountB, accountB);
        vm.stopPrank();

        // 5. Check that balanceOfAll() correctly reflects the burned tokens
        assertEq(vault.balanceOfAll(accountB), 0);
    }
}
