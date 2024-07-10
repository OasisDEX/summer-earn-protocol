// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommander} from "../src/contracts/FleetCommander.sol";
import {PercentageUtils, Percentage} from "../src/libraries/PercentageUtils.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ArkTestHelpers} from "./helpers/ArkHelpers.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {ArkConfiguration, FleetCommanderParams, RebalanceData} from "../src/types/FleetCommanderTypes.sol";
import {FleetCommanderInvalidSourceArk, FleetCommanderNoExcessFunds} from "../src/errors/FleetCommanderErrors.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {CooldownNotElapsed} from "../src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol";
import {ArkMock} from "../test/mocks/ArkMock.sol";

import {FleetCommanderStorageWriter} from "./helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

/**
 * @title ERC4626 methods test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's ERC4626 methods
 */
contract FleetCommanderTest is Test, ArkTestHelpers, FleetCommanderTestBase {
//    using PercentageUtils for uint256;
//
//    FleetCommander public fleetCommander;
//    FleetCommanderStorageWriter public fleetCommanderStorageWriter;
//    address public governor = address(1);
//    address public raft = address(2);
//    address public mockUser = address(3);
//    address public mockUser2 = address(5);
//    address public keeper = address(4);
//
//    address ark1 = address(10);
//    address ark2 = address(11);
//    address ark3 = address(12);
//
//    address invalidArk = address(999);
//
//    ERC20Mock public mockToken;
//    ArkMock public mockArk1;
//    ArkMock public mockArk2;
//    ArkMock public mockArk3;
//
//    string public fleetName = "OK_Fleet";
//
//    uint256 public BUFFER_BALANCE_SLOT;
//    uint256 public MIN_BUFFER_BALANCE_SLOT;
//
//    uint256 ark1_MAX_ALLOCATION = 10000 * 10 ** 6;
//    uint256 ark2_MAX_ALLOCATION = 15000 * 10 ** 6;

    function setUp() public {
        fleetCommander = new FleetCommander(defaultFleetCommanderParams);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );

        vm.startPrank(governor);
        accessManager.grantKeeperRole(keeper);
        mockArk1.grantCommanderRole(address(fleetCommander));
        mockArk2.grantCommanderRole(address(fleetCommander));
        mockArk3.grantCommanderRole(address(fleetCommander));
        vm.stopPrank();
    }

    function test_MaxDeposit() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 depositCap = 100000 * 10 ** 6;

        // Set deposit cap and total assets
        fleetCommanderStorageWriter.setDepositCap(depositCap);
        fleetCommanderStorageWriter.setFundsBufferBalance(0);

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.prank(mockUser);
        uint256 maxDeposit = fleetCommander.maxDeposit(mockUser);

        // Assert
        assertEq(
            maxDeposit,
            userBalance,
            "Max deposit should be the user balance - first deposit so shares equal balance"
        );
    }

    function test_MaxMint() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 depositCap = 50000 * 10 ** 6;

        // Set deposit cap and total assets
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.prank(mockUser);
        uint256 maxMint = fleetCommander.maxMint(mockUser);

        // Assert
        assertEq(
            maxMint,
            userBalance,
            "Max mint should be the user balance - first deposit so shares equal balance"
        );
    }

    function test_MaxWithdraw() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 bufferBalance = fleetCommander.fundsBufferBalance();
        uint256 depositCap = 50000 * 10 ** 6;
        Percentage maxBufferPercentage = PercentageUtils.fromDecimalPercentage(
            20
        );

        // Set buffer balance and max buffer withdrawal percentage
        fleetCommanderStorageWriter.setMaxBufferWithdrawalPercentage(
            maxBufferPercentage
        );
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), userBalance);
        fleetCommander.deposit(userBalance, mockUser);
        uint256 maxWithdraw = fleetCommander.maxWithdraw(mockUser);
        vm.stopPrank();

        // Assert
        assertEq(
            maxWithdraw,
            (bufferBalance + userBalance).applyPercentage(maxBufferPercentage),
            "Max withdraw should be the buffer withdrawal percentage of the total assets (initial buffer + deposited user funds)"
        );
    }

    function test_MaxRedeem() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 bufferBalance = fleetCommander.fundsBufferBalance();
        Percentage maxBufferPercentage = PercentageUtils.fromDecimalPercentage(
            20
        );

        // Set buffer balance and max buffer withdrawal percentage
        fleetCommanderStorageWriter.setMaxBufferWithdrawalPercentage(
            maxBufferPercentage
        );

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), userBalance);
        fleetCommander.deposit(userBalance, mockUser);
        uint256 maxRedeem = fleetCommander.maxRedeem(mockUser);

        // Assert
        assertEq(
            maxRedeem,
            (bufferBalance + userBalance).applyPercentage(maxBufferPercentage),
            "Max redeem should be the buffer withdrawal percentage of the total assets (initial buffer + deposited user funds)"
        );
    }

    function test_Mint() public {
        // Arrange
        uint256 mintAmount = 1000 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;
        uint256 bufferBalance = fleetCommander.fundsBufferBalance();

        // Set buffer balance
        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);

        mockToken.mint(mockUser, mintAmount);

        // Act
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), mintAmount);
        fleetCommander.mint(mintAmount, mockUser);
        vm.stopPrank();

        // Assert
        assertEq(
            fleetCommander.balanceOf(mockUser),
            mintAmount,
            "Mint should increase the user's balance"
        );
        assertEq(
            fleetCommander.fundsBufferBalance(),
            bufferBalance + mintAmount,
            "Buffer balance should be updated"
        );
    }

    function test_Redeem() public {
        // Arrange
        uint256 depositAmount = 1000 * 10 ** 6;
        uint256 redeemAmount = 100 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;

        // Set buffer balance
        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);

        mockToken.mint(mockUser, depositAmount);

        // Deposit first
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), depositAmount);
        fleetCommander.deposit(depositAmount, mockUser);

        uint256 bufferBalance = fleetCommander.fundsBufferBalance();

        // Act
        fleetCommander.redeem(redeemAmount, mockUser, mockUser);
        vm.stopPrank();

        // Assert
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositAmount - redeemAmount,
            "Redeem should decrease the user's balance"
        );
        assertEq(
            fleetCommander.fundsBufferBalance(),
            bufferBalance - redeemAmount,
            "Buffer balance should be updated"
        );
    }
}
