// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderPrivateWithTransfer} from "../../src/contracts/FleetCommanderPrivateWithTransfer.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Test, console} from "forge-std/Test.sol";

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

        // Whitelist users
        vm.startPrank(governor);
        privateFleetCommander.setWhitelisted(mockUser, true);
        privateFleetCommander.setWhitelisted(operator, true);
        // Note: setFleetTokenTransferability is NOT called here.
        // It stays FALSE (default) to test operator bypasses.
        vm.stopPrank();

        // Operator deposits for themselves and for mockUser
        mockToken.mint(operator, amount * 2);
        vm.startPrank(operator);
        mockToken.approve(address(privateFleetCommander), amount * 2);
        privateFleetCommander.deposit(amount, operator);
        privateFleetCommander.deposit(amount, mockUser);
        vm.stopPrank();
    }

    /**
     * @notice Test that an account with OPERATOR_ROLE can transfer to a non-whitelisted user,
     * even when general transfers are disabled (transfersEnabled = false).
     */
    function test_OperatorBypass_TransferToNonWhitelisted_AndDisabled() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // General transfers are disabled (already set in setUp)
        assertFalse(privateFleetCommander.transfersEnabled());

        vm.startPrank(operator);
        // Operator transfers to a non-whitelisted user (bypasses transferability and whitelist)
        privateFleetCommander.transfer(nonWhitelistedUser, amountToTransfer);
        vm.stopPrank();

        assertEq(
            privateFleetCommander.balanceOf(nonWhitelistedUser),
            amountToTransfer
        );
    }

    /**
     * @notice Test that an account with OPERATOR_ROLE can transferFrom a whitelisted user
     * to a non-whitelisted user, even when general transfers are disabled.
     */
    function test_OperatorBypass_TransferFromToNonWhitelisted_AndDisabled()
        public
    {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // mockUser has shares from setUp. mockUser approves operator.
        vm.startPrank(mockUser);
        privateFleetCommander.approve(operator, amountToTransfer);
        vm.stopPrank();

        // General transfers are disabled (already set in setUp)
        assertFalse(privateFleetCommander.transfersEnabled());

        vm.startPrank(operator);
        // Operator transfers from whitelisted mockUser to non-whitelisted user (bypasses both)
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

    /**
     * @notice Test that a normal whitelisted user CANNOT transfer to a non-whitelisted user,
     * even if transfers are enabled.
     */
    function test_NonOperator_RevertIfTransferToNonWhitelisted() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // Enable transfers for this test
        vm.prank(governor);
        privateFleetCommander.setFleetTokenTransferability();

        // Ensure mockUser has enough balance (from setUp)
        vm.startPrank(mockUser);
        vm.expectRevert(); // Validation fails because recipient is not whitelisted
        privateFleetCommander.transfer(nonWhitelistedUser, amountToTransfer);
        vm.stopPrank();
    }

    /**
     * @notice Test that a normal whitelisted user CANNOT transferFrom to a non-whitelisted user,
     * even if transfers are enabled.
     */
    function test_NonOperator_RevertIfTransferFromToNonWhitelisted() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        address mockUser2 = makeAddr("mockUser2");
        vm.startPrank(governor);
        privateFleetCommander.setWhitelisted(mockUser2, true);
        privateFleetCommander.setFleetTokenTransferability(); // Enable transfers
        vm.stopPrank();

        // Operator deposits for mockUser2
        mockToken.mint(operator, amountToTransfer);
        vm.startPrank(operator);
        mockToken.approve(address(privateFleetCommander), amountToTransfer);
        privateFleetCommander.deposit(amountToTransfer, mockUser2);
        vm.stopPrank();

        // mockUser2 approves mockUser
        vm.startPrank(mockUser2);
        privateFleetCommander.approve(mockUser, amountToTransfer);
        vm.stopPrank();

        vm.startPrank(mockUser);
        vm.expectRevert();
        // Fails because recipient (nonWhitelistedUser) is not whitelisted
        privateFleetCommander.transferFrom(
            mockUser2,
            nonWhitelistedUser,
            amountToTransfer
        );
        vm.stopPrank();
    }

    /**
     * @notice Test that a normal whitelisted user CANNOT transfer if transfers are disabled.
     */
    function test_NonOperator_RevertIfTransfersDisabled() public {
        uint256 amountToTransfer = 10 * 10 ** 6;
        address whitelistedRecipient = makeAddr("whitelistedRecipient");

        vm.prank(governor);
        privateFleetCommander.setWhitelisted(whitelistedRecipient, true);
        // Transfers stay DISABLED (default)

        vm.startPrank(mockUser);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderTransfersDisabled()")
        );
        privateFleetCommander.transfer(whitelistedRecipient, amountToTransfer);
        vm.stopPrank();
    }
}
