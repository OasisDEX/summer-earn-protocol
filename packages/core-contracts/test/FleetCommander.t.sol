// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../src/contracts/FleetCommander.sol";
import {PercentageUtils} from "../src/libraries/PercentageUtils.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ArkTestHelpers} from "./helpers/ArkHelpers.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {FleetCommanderInvalidSourceArk, FleetCommanderNoExcessFunds, FleetCommanderRebalanceCooldownNotElapsed} from "../src/errors/FleetCommanderErrors.sol";
import {ArkMock} from "../src/contracts/test/ArkMock.sol";

contract FleetCommanderTest is Test, ArkTestHelpers {
    using PercentageUtils for uint256;

    FleetCommander public fleetCommander;
    address public governor = address(1);
    address public raft = address(2);
    address public mockUser = address(3);
    address public keeper = address(4);
    address ark_1 = address(10);
    address ark_2 = address(11);
    address ark_3 = address(12);
    address invalid_ark = address(999);
    ERC20Mock public mockToken;
    ArkMock public mockArk1;
    ArkMock public mockArk2;
    ArkMock public mockArk3;
    string public fleetName = "OK_Fleet";

    uint256 public BUFFER_BALANCE_SLOT = uint256(8);
    uint256 public MIN_BUFFER_BALANCE_SLOT = uint256(6);

    uint256 ARK_1_MAX_ALLOCATION = 10000 * 10 ** 6;
    uint256 ARK_2_MAX_ALLOCATION = 15000 * 10 ** 6;

    function setUp() public {
        mockToken = new ERC20Mock();

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({governor: governor, raft: raft})
        );
        // Instantiate ArkMock contracts for ark_1 and ark_2
        mockArk1 = new ArkMock(
            ArkParams({
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        mockArk2 = new ArkMock(
            ArkParams({
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        mockArk3 = new ArkMock(
            ArkParams({
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        ark_1 = address(mockArk1);
        ark_2 = address(mockArk2);
        ark_3 = address(mockArk3);

        ArkConfiguration[] memory initialArks = new ArkConfiguration[](3);
        initialArks[0] = ArkConfiguration({
            ark: ark_1,
            maxAllocation: ARK_1_MAX_ALLOCATION
        });
        initialArks[1] = ArkConfiguration({
            ark: ark_2,
            maxAllocation: ARK_2_MAX_ALLOCATION
        });
        initialArks[2] = ArkConfiguration({
            ark: ark_3,
            maxAllocation: 10000 * 10 ** 6
        });
        FleetCommanderParams memory params = FleetCommanderParams({
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
                .fromDecimalPercentage(20)
        });
        fleetCommander = new FleetCommander(params);

        vm.prank(governor);
        fleetCommander.grantRole(keccak256("KEEPER_ROLE"), keeper);
    }

    function testDeposit() public {
        uint256 amount = 1000 * 10 ** 6;
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        mockArkTotalAssets(ark_1, 0);
        mockArkTotalAssets(ark_2, 0);

        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);

        assertEq(amount, fleetCommander.balanceOf(mockUser));
    }

    function testWithdraw() public {
        // Arrange (Deposit first)
        uint256 amount = 1000 * 10 ** 6;
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        // since the funds do not leave the queue in this test we do not need to mock the total assets
        mockArkTotalAssets(ark_1, 0);
        mockArkTotalAssets(ark_2, 0);

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

    function testAdjustBufferSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        vm.store(
            address(fleetCommander),
            bytes32(BUFFER_BALANCE_SLOT),
            bytes32(initialBufferBalance)
        ); // Slot for fundsBufferBalance
        vm.store(
            address(fleetCommander),
            bytes32(MIN_BUFFER_BALANCE_SLOT),
            bytes32(minBufferBalance)
        ); // Slot for minFundsBufferBalance

        // Mock token balance
        mockToken.mint(address(fleetCommander), initialBufferBalance);

        // Mock Ark behavior
        mockArkTotalAssets(ark_1, 0);
        mockArkTotalAssets(ark_2, 0);
        mockArkRate(ark_1, 105);
        mockArkRate(ark_2, 110);

        // Prepare rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark_1,
            amount: 3000 * 10 ** 6
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark_2,
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

    function testAdjustBufferNoExcessFunds() public {
        // Arrange
        uint256 bufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        vm.store(
            address(fleetCommander),
            bytes32(BUFFER_BALANCE_SLOT),
            bytes32(bufferBalance)
        ); // Slot for fundsBufferBalance
        vm.store(
            address(fleetCommander),
            bytes32(MIN_BUFFER_BALANCE_SLOT),
            bytes32(bufferBalance)
        ); // Slot for minFundsBufferBalance

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark_1,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(FleetCommanderNoExcessFunds.selector)
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }

    function testAdjustBufferInvalidSourceArk() public {
        // Arrange
        uint256 bufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        vm.store(
            address(fleetCommander),
            bytes32(BUFFER_BALANCE_SLOT),
            bytes32(bufferBalance)
        ); // Slot for fundsBufferBalance
        vm.store(
            address(fleetCommander),
            bytes32(MIN_BUFFER_BALANCE_SLOT),
            bytes32(minBufferBalance)
        ); // Slot for minFundsBufferBalance

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1, // Invalid source, should be FleetCommander
            toArk: ark_2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderInvalidSourceArk.selector,
                ark_1
            )
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }

    function testAdjustBufferPartialMove() public {
        // Arrange
        uint256 initialBufferBalance = 12000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        vm.store(
            address(fleetCommander),
            bytes32(BUFFER_BALANCE_SLOT),
            bytes32(initialBufferBalance)
        ); // Slot for fundsBufferBalance
        vm.store(
            address(fleetCommander),
            bytes32(MIN_BUFFER_BALANCE_SLOT),
            bytes32(minBufferBalance)
        ); // Slot for minFundsBufferBalance

        // Mock token balance
        mockToken.mint(address(fleetCommander), initialBufferBalance);

        mockArkTotalAssets(ark_1, 0);
        mockArkRate(ark_1, 105);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark_1,
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
        // mockArkTotalAssets(ark_1, initialBufferBalance);
        // mockArkTotalAssets(ark_2, 0);
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
    }

    function testRebalanceSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        vm.store(
            address(fleetCommander),
            bytes32(BUFFER_BALANCE_SLOT),
            bytes32(initialBufferBalance)
        );
        vm.store(
            address(fleetCommander),
            bytes32(MIN_BUFFER_BALANCE_SLOT),
            bytes32(minBufferBalance)
        );

        mockToken.mint(address(fleetCommander), initialBufferBalance);
        mockArkTotalAssets(ark_1, 5000 * 10 ** 6);
        mockArkTotalAssets(ark_2, 5000 * 10 ** 6);
        mockArkRate(ark_1, 105);
        mockArkRate(ark_2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1,
            toArk: ark_2,
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

    function testRebalanceMultipleArks() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        uint256 ark1IntitialBalance = 5000 * 10 ** 6;
        uint256 ark2IntitialBalance = 2500 * 10 ** 6;
        uint256 ark3IntitialBalance = 2500 * 10 ** 6;

        vm.store(
            address(fleetCommander),
            bytes32(BUFFER_BALANCE_SLOT),
            bytes32(initialBufferBalance)
        );
        vm.store(
            address(fleetCommander),
            bytes32(MIN_BUFFER_BALANCE_SLOT),
            bytes32(minBufferBalance)
        );

        mockToken.mint(address(fleetCommander), initialBufferBalance);
        mockArkTotalAssets(ark_1, ark1IntitialBalance);
        mockArkTotalAssets(ark_2, ark2IntitialBalance);
        mockArkTotalAssets(ark_3, ark3IntitialBalance);
        mockArkRate(ark_1, 105);
        mockArkRate(ark_2, 110);
        mockArkRate(ark_3, 115);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1,
            toArk: ark_2,
            amount: 1000 * 10 ** 6
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark_1,
            toArk: ark_3,
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

    function testRebalanceInvalidSourceArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: invalid_ark, // Invalid source
            toArk: ark_2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                invalid_ark
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function testRebalanceInvalidTargetArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1,
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

    function testRebalanceZeroAmount() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1,
            toArk: ark_2,
            amount: 0 // Zero amount
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceAmountZero(address)",
                ark_2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function testRebalanceExceedMaxAllocation() public {
        // Arrange
        mockArkTotalAssets(ark_1, 5000 * 10 ** 6);
        mockArkTotalAssets(ark_2, ARK_2_MAX_ALLOCATION); // Already at max allocation
        mockArkRate(ark_1, 105);
        mockArkRate(ark_2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1,
            toArk: ark_2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantRebalanceToArk(address)",
                ark_2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function testRebalanceLowerRate() public {
        // Arrange
        mockArkTotalAssets(ark_1, 5000 * 10 ** 6);
        mockArkTotalAssets(ark_2, 5000 * 10 ** 6);
        mockArkRate(ark_1, 110);
        mockArkRate(ark_2, 105); // Lower rate than source

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1,
            toArk: ark_2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderTargetArkRateTooLow(address,uint256,uint256)",
                ark_2,
                105,
                110
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function testRebalanceCooldownNotElapsed() public {
        // Arrange

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark_1,
            toArk: ark_2,
            amount: 1000 * 10 ** 6
        });

        // First rebalance
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        uint256 cooldown = 1 days;
        vm.prank(governor);
        fleetCommander.updateRebalanceCooldown(cooldown);

        // Try to rebalance again immediately
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderRebalanceCooldownNotElapsed.selector,
                cooldown,
                block.timestamp
            )
        );
        fleetCommander.rebalance(rebalanceData);

        // Advance time and try again
        vm.warp(block.timestamp + cooldown + 1);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData); // This should succeed
    }
}
