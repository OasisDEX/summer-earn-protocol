// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";

import "../../src/contracts/arks/CompoundV3Ark.sol";
import "../../src/contracts/arks/AaveV3Ark.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../../src/events/IArkEvents.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";

/**
 * @title Lifecycle test suite for FleetCommander
 * @dev Test suite of full lifecycle tests EG Deposit -> Rebalance -> ForceWithdraw
 */
contract LifecycleTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    // Arks
    CompoundV3Ark public compoundArk;
    AaveV3Ark public aaveArk;

    // External contracts
    IComet public usdcCompoundCometContract;
    IPoolV3 public aaveV3PoolContract;
    IERC20 public usdcTokenContract;

    // Constants
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant AAVE_V3_POOL_ADDRESS =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant COMPOUND_USDC_COMET_ADDRESS =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    uint256 constant FORK_BLOCK = 20276596;

    function setUp() public {
        console.log("Setting up LifecycleTest");

        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        initializeFleetCommanderWithoutArks(USDC_ADDRESS);
        setupExternalContracts();
        setupArks();
        addArksToFleetCommander();
        grantPermissions();

        logSetupInfo();
    }

    function setupExternalContracts() internal {
        usdcTokenContract = IERC20(USDC_ADDRESS);
        aaveV3PoolContract = IPoolV3(AAVE_V3_POOL_ADDRESS);
        usdcCompoundCometContract = IComet(COMPOUND_USDC_COMET_ADDRESS);
    }

    function setupArks() internal {
        ArkParams memory arkParams = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(usdcTokenContract),
            maxAllocation: type(uint256).max
        });
        aaveArk = new AaveV3Ark(address(aaveV3PoolContract), arkParams);
        compoundArk = new CompoundV3Ark(
            address(usdcCompoundCometContract),
            arkParams
        );
    }

    function addArksToFleetCommander() internal {
        address[] memory arks = new address[](2);
        arks[0] = address(compoundArk);
        arks[1] = address(aaveArk);
        vm.prank(governor);
        fleetCommander.addArks(arks);
    }

    function grantPermissions() internal {
        vm.startPrank(governor);
        compoundArk.grantCommanderRole(address(fleetCommander));
        aaveArk.grantCommanderRole(address(fleetCommander));
        bufferArk.grantCommanderRole(address(fleetCommander));
        accessManager.grantKeeperRole(keeper);
        vm.stopPrank();
    }

    function logSetupInfo() internal view {
        console.log("aave ark:", address(aaveArk));
        console.log("compound ark:", address(compoundArk));
        console.log("buffer ark:", address(bufferArk));
        console.log("fleet commander:", address(fleetCommander));
    }

    function test_DepositRebalanceForceWithdrawFork() public {
        // Arrange
        uint256 user1Deposit = ARK1_MAX_ALLOCATION;
        uint256 user2Deposit = ARK2_MAX_ALLOCATION;
        uint256 depositCap = ARK1_MAX_ALLOCATION + ARK2_MAX_ALLOCATION;
        uint256 minBufferBalance = 0;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Set deposit cap
        fleetCommanderStorageWriter.setDepositCap(depositCap);
        // Mint tokens for users
        deal(address(usdcTokenContract), mockUser, user1Deposit);
        deal(address(usdcTokenContract), mockUser2, user2Deposit);

        // User 1 deposits
        vm.startPrank(mockUser);
        usdcTokenContract.approve(address(fleetCommander), user1Deposit);
        uint256 user1PreviewShares = fleetCommander.previewDeposit(
            user1Deposit
        );
        uint256 user1DepositedShares = fleetCommander.deposit(
            user1Deposit,
            mockUser
        );
        assertEq(
            user1PreviewShares,
            user1DepositedShares,
            "Preview and deposited shares should be equal"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            user1Deposit,
            "User 1 balance should be equal to deposit"
        );
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(mockUser2);
        usdcTokenContract.approve(address(fleetCommander), user2Deposit);
        uint256 user2PreviewShares = fleetCommander.previewDeposit(
            user2Deposit
        );
        uint256 user2DepositedShares = fleetCommander.deposit(
            user2Deposit,
            mockUser2
        );
        assertEq(
            user2PreviewShares,
            user2DepositedShares,
            "Preview and deposited shares should be equal"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser2),
            user2Deposit,
            "User 2 balance should be equal to deposit"
        );
        vm.stopPrank();

        // Rebalance funds to Ark1 and Ark2
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: address(bufferArk),
            toArk: address(compoundArk),
            amount: user1Deposit
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(bufferArk),
            toArk: address(aaveArk),
            amount: user2Deposit
        });

        // Advance time to move past cooldown window
        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Advance time and update Ark1 and Ark2 balances to simulate interest accrual
        vm.warp(block.timestamp + 5 days);

        // User 1 withdraws

        vm.startPrank(mockUser);
        uint256 user1Shares = fleetCommander.balanceOf(mockUser);
        uint256 user1Assets = fleetCommander.previewRedeem(user1Shares);
        console.log("User 1 shares:", fleetCommander.balanceOf(mockUser));
        console.log("User 1 assets:", user1Assets);
        console.log("cmpound ark assets:", compoundArk.totalAssets());
        console.log("aave ark assets:", aaveArk.totalAssets());
        console.log("fleet assets", fleetCommander.totalAssets());
        fleetCommander.forceWithdraw(user1Assets, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User 1 balance should be 0"
        );
        assertEq(
            usdcTokenContract.balanceOf(mockUser),
            user1Assets,
            "User 1 should receive assets"
        );
        vm.stopPrank();

        // User 2 withdraws

        vm.startPrank(mockUser2);
        uint256 user2Shares = fleetCommander.balanceOf(mockUser2);
        uint256 user2Assets = fleetCommander.previewRedeem(user2Shares);
        console.log("User 2 shares:", fleetCommander.balanceOf(mockUser2));
        console.log("User 2 assets:", user2Assets);
        fleetCommander.forceWithdraw(user2Assets, mockUser2, mockUser2);

        assertEq(
            fleetCommander.balanceOf(mockUser2),
            0,
            "User 2 balance should be 0"
        );
        assertEq(
            usdcTokenContract.balanceOf(mockUser2),
            user2Assets,
            "User 2 should receive assets"
        );
        vm.stopPrank();

        // Assert
        assertEq(
            fleetCommander.totalAssets(),
            0,
            "Total assets should be 0 after withdrawals"
        );
    }
}
