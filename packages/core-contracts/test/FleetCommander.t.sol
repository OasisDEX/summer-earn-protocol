// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../src/contracts/FleetCommander.sol";
import {PercentageUtils} from "../src/libraries/PercentageUtils.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract FleetCommanderTest is Test {
    using PercentageUtils for uint256;

    FleetCommander public fleetCommander;
    address public governor = address(1);
    address public raft = address(2);
    address public mockUser = address(3);
    ERC20Mock public mockToken;
    string public fleetName = "OK_Fleet";

    function setUp() public {
        mockToken = new ERC20Mock();

        ArkConfiguration[] memory initialArks = new ArkConfiguration[](2);
        initialArks[0] = ArkConfiguration({
            maxAllocation: PercentageUtils.fromDecimalPercentage(50)
        });
        initialArks[1] = ArkConfiguration({
            maxAllocation: PercentageUtils.fromDecimalPercentage(50)
        });

        FleetCommanderParams memory params = FleetCommanderParams({
            governor: governor,
            initialArks: initialArks,
            initialFundsBufferBalance: 10000 * 10 ** 18,
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
    }

    function testDeposit() public {
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);

        assertEq(amount, fleetCommander.balanceOf(mockUser));
    }

    function testWithdraw() public {
        // Arrange (Deposit first)
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

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
}
