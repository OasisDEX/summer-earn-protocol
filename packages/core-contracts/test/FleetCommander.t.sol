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

/**
 * @title FleetCommanderTest
 * @dev Comprehensive test suite for the FleetCommander contract
 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Basic operations (deposit, withdraw)
 * - Buffer adjustment
 * - Rebalancing operations
 * - Error cases and edge scenarios
 */
contract FleetCommanderTest is Test, ArkTestHelpers {
    using PercentageUtils for uint256;

    FleetCommander public fleetCommander;
    FleetCommanderStorageWriter public fleetCommanderStorageWriter;
    address public governor = address(1);
    address public raft = address(2);
    address public mockUser = address(3);
    address public mockUser2 = address(5);
    address public keeper = address(4);

    address ark1 = address(10);
    address ark2 = address(11);
    address ark3 = address(12);

    address invalidArk = address(999);

    ERC20Mock public mockToken;
    ArkMock public mockArk1;
    ArkMock public mockArk2;
    ArkMock public mockArk3;

    string public fleetName = "OK_Fleet";

    uint256 public BUFFER_BALANCE_SLOT;
    uint256 public MIN_BUFFER_BALANCE_SLOT;

    uint256 ark1_MAX_ALLOCATION = 10000 * 10 ** 6;
    uint256 ark2_MAX_ALLOCATION = 15000 * 10 ** 6;

    function setUp() public {
        mockToken = new ERC20Mock();

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft
            })
        );
        // Instantiate ArkMock contracts for ark1 and ark2
        mockArk1 = new ArkMock(
            ArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        mockArk2 = new ArkMock(
            ArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        mockArk3 = new ArkMock(
            ArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        ark1 = address(mockArk1);
        ark2 = address(mockArk2);
        ark3 = address(mockArk3);

        ArkConfiguration[] memory initialArks = new ArkConfiguration[](3);
        initialArks[0] = ArkConfiguration({
            ark: ark1,
            maxAllocation: ark1_MAX_ALLOCATION
        });
        initialArks[1] = ArkConfiguration({
            ark: ark2,
            maxAllocation: ark2_MAX_ALLOCATION
        });
        initialArks[2] = ArkConfiguration({
            ark: ark3,
            maxAllocation: 10000 * 10 ** 6
        });
        FleetCommanderParams memory params = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialArks: initialArks,
            initialFundsBufferBalance: 10000 * 10 ** 6,
            initialRebalanceCooldown: 0,
            asset: address(mockToken),
            name: fleetName,
            symbol: string(abi.encodePacked(mockToken.symbol(), "-SUM")),
            initialMinimumPositionWithdrawal: PercentageUtils
                .fromDecimalPercentage(2),
            initialMaximumBufferWithdrawal: PercentageUtils
                .fromDecimalPercentage(20),
            depositCap: 100000000 * 10 ** 6
        });
        fleetCommander = new FleetCommander(params);
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

    function test_Deposit() public {
        uint256 amount = 1000 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;

        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        mockArkTotalAssets(ark1, 0);
        mockArkTotalAssets(ark2, 0);

        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);

        assertEq(amount, fleetCommander.balanceOf(mockUser));
    }

    function test_DepositRebalanceForceWithdraw() public {
        // Arrange
        uint256 user1Deposit = ark1_MAX_ALLOCATION;
        uint256 user2Deposit = ark2_MAX_ALLOCATION;
        uint256 depositCap = ark1_MAX_ALLOCATION + ark2_MAX_ALLOCATION;
        uint256 minBufferBalance = 1000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Set deposit cap
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        // Mint tokens for users
        mockToken.mint(mockUser, user1Deposit);
        mockToken.mint(mockUser2, user2Deposit);

        // User 1 deposits
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), user1Deposit);
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
        mockToken.approve(address(fleetCommander), user2Deposit);
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
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: user1Deposit
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark2,
            amount: user2Deposit
        });

        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Advance time and update Ark1 and Ark2 balances to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        mockToken.mint(ark1, (user1Deposit * 5) / 100);
        mockToken.mint(ark2, (user2Deposit * 10) / 100);

        // User 1 withdraws
        vm.startPrank(mockUser);
        uint256 user1Shares = fleetCommander.balanceOf(mockUser);
        uint256 user1Assets = fleetCommander.previewRedeem(user1Shares);
        fleetCommander.forceWithdraw(user1Assets, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User 1 balance should be 0"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            user1Assets,
            "User 1 should receive assets"
        );
        vm.stopPrank();

        // User 2 withdraws
        vm.startPrank(mockUser2);
        uint256 user2Shares = fleetCommander.balanceOf(mockUser2);
        uint256 user2Assets = fleetCommander.previewRedeem(user2Shares);
        fleetCommander.forceWithdraw(user2Assets, mockUser2, mockUser2);

        assertEq(
            fleetCommander.balanceOf(mockUser2),
            0,
            "User 2 balance should be 0"
        );
        assertEq(
            mockToken.balanceOf(mockUser2),
            user2Assets,
            "User 2 should receive assets"
        );
        vm.stopPrank();

        // Assert
        // TODO: One wei off due to rounding error
        assertEq(
            fleetCommander.totalAssets(),
            1,
            "Total assets should be 0 after withdrawals"
        );
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

    function test_Withdraw() public {
        // Arrange (Deposit first)
        uint256 amount = 1000 * 10 ** 6;
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        // since the funds do not leave the queue in this test we do not need to mock the total assets
        mockArkTotalAssets(ark1, 0);
        mockArkTotalAssets(ark2, 0);

        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);

        assertEq(amount, fleetCommander.balanceOf(mockUser));

        // Act
        vm.prank(mockUser);
        uint256 withdrawalAmount = amount / 10;
        fleetCommander.withdraw(amount / 10, mockUser, mockUser);

        // Assert
        assertEq(amount - withdrawalAmount, fleetCommander.balanceOf(mockUser));
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

    function test_AdjustBufferSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(initialBufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(fleetCommander), initialBufferBalance);

        // Mock Ark behavior
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        // Prepare rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: 3000 * 10 ** 6
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark2,
            amount: 2000 * 10 ** 6
        });

        // Act
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Assert
        assertEq(
            fleetCommander.fundsBufferBalance(),
            minBufferBalance,
            "Buffer balance should be equal to minBufferBalance"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
    }

    function test_AdjustBufferNoExcessFunds() public {
        // Arrange
        uint256 bufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(bufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(bufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(FleetCommanderNoExcessFunds.selector)
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }

    function test_AdjustBufferInvalidSourceArk() public {
        // Arrange
        uint256 bufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(bufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1, // Invalid source, should be FleetCommander
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderInvalidSourceArk.selector,
                ark1
            )
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }

    function test_AdjustBufferPartialMove() public {
        // Arrange
        uint256 initialBufferBalance = 12000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(initialBufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(fleetCommander), initialBufferBalance);

        mockArkRate(ark1, 105);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: 3000 * 10 ** 6 // More than excess funds
        });

        // Act
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Assert
        assertEq(
            fleetCommander.fundsBufferBalance(),
            minBufferBalance,
            "Buffer balance should be equal to minBufferBalance"
        );

        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        fleetCommanderStorageWriter.setFundsBufferBalance(initialBufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        mockToken.mint(address(fleetCommander), initialBufferBalance);
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            fleetCommander.fundsBufferBalance(),
            initialBufferBalance,
            "Buffer balance should remain unchanged"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance + 10000 * 10 ** 6,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceMultipleArks() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        uint256 ark1IntitialBalance = 5000 * 10 ** 6;
        uint256 ark2IntitialBalance = 2500 * 10 ** 6;
        uint256 ark3IntitialBalance = 2500 * 10 ** 6;

        fleetCommanderStorageWriter.setFundsBufferBalance(initialBufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        mockToken.mint(address(fleetCommander), initialBufferBalance);
        mockToken.mint(ark1, ark1IntitialBalance);
        mockToken.mint(ark2, ark2IntitialBalance);
        mockToken.mint(ark3, ark3IntitialBalance);

        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);
        mockArkRate(ark3, 115);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark1,
            toArk: ark3,
            amount: 500 * 10 ** 6
        });

        // Act
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            fleetCommander.fundsBufferBalance(),
            initialBufferBalance,
            "Buffer balance should remain unchanged"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance +
                ark1IntitialBalance +
                ark2IntitialBalance +
                ark3IntitialBalance,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceInvalidSourceArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: invalidArk, // Invalid source
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                invalidArk
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceInvalidTargetArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: address(this), // Invalid target
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(this)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceZeroAmount() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 0 // Zero amount
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceAmountZero(address)",
                ark2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceExceedMaxAllocation() public {
        // Arrange
        mockArkTotalAssets(ark1, 5000 * 10 ** 6);
        mockArkTotalAssets(ark2, ark2_MAX_ALLOCATION); // Already at max allocation
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantRebalanceToArk(address)",
                ark2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceLowerRate() public {
        // Arrange
        mockArkTotalAssets(ark1, 5000 * 10 ** 6);
        mockArkTotalAssets(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 110);
        mockArkRate(ark2, 105); // Lower rate than source

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderTargetArkRateTooLow(address,uint256,uint256)",
                ark2,
                105,
                110
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceCooldownNotElapsed() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });
        mockToken.mint(ark1, 5000 * 10 ** 6);

        // First rebalance
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        uint256 cooldown = 1 days;
        vm.prank(governor);
        fleetCommander.updateRebalanceCooldown(cooldown);

        // Try to rebalance again immediately
        vm.expectRevert(
            abi.encodeWithSelector(
                CooldownNotElapsed.selector,
                fleetCommander.getLastActionTimestamp(),
                cooldown,
                block.timestamp
            )
        );

        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Advance time and try again
        vm.warp(block.timestamp + cooldown + 1);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData); // This should succeed
    }
}
