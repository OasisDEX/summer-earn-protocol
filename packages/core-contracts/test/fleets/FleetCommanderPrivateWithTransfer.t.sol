// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {FleetCommanderPrivateWithTransfer} from "../../src/contracts/FleetCommanderPrivateWithTransfer.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract FleetCommanderPrivateWithTransferTest is
    Test,
    TestHelpers,
    FleetCommanderTestBase
{
    FleetCommanderPrivateWithTransfer public privateFleetCommander;
    address public operator = makeAddr("operator");
    address public nonWhitelistedUser = makeAddr("nonWhitelistedUser");

    function setUp() public {
        // We override accessManager to use V2 before setupBaseContracts
        accessManager = new ProtocolAccessManagerV2(governor);

        setupBaseContracts();

        mockToken = new ERC20Mock();

        vm.startPrank(governor);
        fleetCommanderParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            asset: address(mockToken),
            name: fleetName,
            symbol: "TEST-SUM",
            details: "TestFleet-details",
            initialTipRate: PercentageUtils.fromIntegerPercentage(0),
            depositCap: type(uint256).max
        });

        privateFleetCommander = new FleetCommanderPrivateWithTransfer(
            fleetCommanderParams
        );
        fleetCommander = privateFleetCommander; // Set base variable

        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(privateFleetCommander)
        );
        harborCommand.enlistFleetCommander(address(privateFleetCommander));

        // Grant Operator role to the operator address
        IProtocolAccessManagerV2(address(accessManager)).grantOperatorRole(
            address(privateFleetCommander),
            operator
        );
        vm.stopPrank();

        uint256 amount = 1000 * 10 ** 6;

        // Mint tokens to mockUser & operator
        mockToken.mint(mockUser, amount);
        mockToken.mint(operator, amount);

        // Deposit some funds so mockUser has shares
        vm.startPrank(governor);
        privateFleetCommander.setWhitelisted(mockUser, true);
        privateFleetCommander.setWhitelisted(operator, true);
        privateFleetCommander.setFleetTokenTransferability(); // Enable transfers globally
        vm.stopPrank();

        // mockUser deposits
        vm.startPrank(mockUser);
        mockToken.approve(address(privateFleetCommander), amount);
        privateFleetCommander.deposit(amount, mockUser);
        vm.stopPrank();

        // operator deposits
        vm.startPrank(operator);
        mockToken.approve(address(privateFleetCommander), amount);
        privateFleetCommander.deposit(amount, operator);
        vm.stopPrank();
    }

    function test_OperatorCanTransferToNonWhitelisted() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        vm.startPrank(operator);
        // Operator transfers to a non-whitelisted user
        privateFleetCommander.transfer(nonWhitelistedUser, amountToTransfer);
        vm.stopPrank();

        assertEq(
            privateFleetCommander.balanceOf(nonWhitelistedUser),
            amountToTransfer
        );
    }

    function test_OperatorCanTransferFromNonWhitelistedToNonWhitelisted()
        public
    {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // mockUser approves operator
        vm.startPrank(mockUser);
        privateFleetCommander.approve(operator, amountToTransfer);
        vm.stopPrank();

        vm.startPrank(operator);
        // Operator transfers from mockUser (who is whitelisted) to nonWhitelistedUser (who is NOT whitelisted)
        // Since operator is doing it, it bypasses the to/from whitelist checks
        privateFleetCommander.transferFrom(
            mockUser,
            nonWhitelistedUser,
            amountToTransfer
        );
        vm.stopPrank();

        assertEq(
            privateFleetCommander.balanceOf(nonWhitelistedUser),
            amountToTransfer
        );
    }

    function test_NonOperatorCannotTransferToNonWhitelisted() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        vm.startPrank(mockUser);
        vm.expectRevert(); // Typically fails with a validation error
        privateFleetCommander.transfer(nonWhitelistedUser, amountToTransfer);
        vm.stopPrank();
    }

    function test_NonOperatorCannotTransferFromToNonWhitelisted() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // Ensure mockUser has approval from itself, or someone else doing transferFrom
        // We'll have mockUser2 approve mockUser
        address mockUser2 = makeAddr("mockUser2");
        vm.prank(governor);
        privateFleetCommander.setWhitelisted(mockUser2, true);

        mockToken.mint(mockUser2, amountToTransfer);
        vm.startPrank(mockUser2);
        mockToken.approve(address(privateFleetCommander), amountToTransfer);
        privateFleetCommander.deposit(amountToTransfer, mockUser2);
        privateFleetCommander.approve(mockUser, amountToTransfer);
        vm.stopPrank();

        vm.startPrank(mockUser);
        vm.expectRevert();
        // Since mockUser is not an operator, transfer to nonWhitelistedUser should fail
        privateFleetCommander.transferFrom(
            mockUser2,
            nonWhitelistedUser,
            amountToTransfer
        );
        vm.stopPrank();
    }
}
