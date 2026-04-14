// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {FleetCommanderParams, FleetCommanderWhitelistParams} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Test, console} from "forge-std/Test.sol";

contract FleetCommanderWhitelistTest is
    Test,
    TestHelpers,
    FleetCommanderTestBase
{
    FleetCommanderWhitelist public whitelistFleet;
    FleetCommanderWhitelistParams public whitelistFleetParams;
    FleetCommanderStorageWriter public whitelistFleetStorageWriter;
    address public operator = makeAddr("operator");
    address public nonWhitelistedUser = makeAddr("nonWhitelistedUser");

    function setUp() public {
        // We override accessManager to use V2 before setupBaseContracts
        accessManager = new ProtocolAccessManagerV2(governor);

        setupBaseContracts();

        mockToken = new ERC20Mock();

        vm.startPrank(governor);
        whitelistFleetParams = FleetCommanderWhitelistParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            asset: address(mockToken),
            name: fleetName,
            symbol: "TEST-SUM",
            details: "TestFleet-details",
            initialTipRate: PercentageUtils.fromIntegerPercentage(0),
            depositCap: type(uint256).max,
            isOperatorGatewayOpen: true
        });

        whitelistFleet = new FleetCommanderWhitelist(whitelistFleetParams);

        whitelistFleetStorageWriter = new FleetCommanderStorageWriter(
            address(whitelistFleet)
        );
        harborCommand.enlistFleetCommander(address(whitelistFleet));

        // Grant Operator role to the operator address
        IProtocolAccessManagerV2(address(accessManager)).grantOperatorRole(
            address(whitelistFleet),
            operator
        );
        IProtocolAccessManagerV2(address(accessManager))
            .grantWhitelistManagerRole(address(whitelistFleet));
        vm.stopPrank();

        uint256 amount = 1000 * 10 ** 6;

        vm.startPrank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser,
            true
        );
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            operator,
            true
        );
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser2,
            true
        );
        vm.stopPrank();

        // Operator deposits for themselves and for mockUser
        mockToken.mint(operator, amount * 2);
        vm.startPrank(operator);
        mockToken.approve(address(whitelistFleet), amount * 2);
        whitelistFleet.deposit(amount, operator);
        whitelistFleet.deposit(amount, mockUser);
        vm.stopPrank();
    }

    /**
     * @notice Test that an account with OPERATOR_ROLE can transfer to a non-whitelisted user,
     * even when general transfers are disabled (transfersEnabled = false).
     */
    function test_OperatorCanBypass_TransferToNonWhitelisted_AndDisabled()
        public
    {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // General transfers are disabled (already set in setUp)
        assertFalse(whitelistFleet.transfersEnabled());

        vm.startPrank(operator);
        // Operator transfers to a non-whitelisted user (bypasses transferability and whitelist)
        whitelistFleet.transfer(nonWhitelistedUser, amountToTransfer);
        vm.stopPrank();

        assertEq(
            whitelistFleet.balanceOf(nonWhitelistedUser),
            amountToTransfer
        );
    }

    /**
     * @notice Test that an account with OPERATOR_ROLE can transferFrom a whitelisted user
     * to a non-whitelisted user, even when general transfers are disabled.
     */
    function test_OperatorCanBypass_TransferFromToNonWhitelisted_AndDisabled()
        public
    {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // mockUser has shares from setUp. mockUser approves operator.
        vm.startPrank(mockUser);
        whitelistFleet.approve(operator, amountToTransfer);
        vm.stopPrank();

        // General transfers are disabled (already set in setUp)
        assertFalse(whitelistFleet.transfersEnabled());

        vm.startPrank(operator);
        // Operator transfers from whitelisted mockUser to non-whitelisted user (bypasses both)
        whitelistFleet.transferFrom(
            mockUser,
            nonWhitelistedUser,
            amountToTransfer
        );
        vm.stopPrank();

        assertEq(
            whitelistFleet.balanceOf(nonWhitelistedUser),
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
        whitelistFleet.setFleetTokenTransferability(true);

        // Ensure mockUser has enough balance (from setUp)
        vm.startPrank(mockUser);
        vm.expectRevert(); // Validation fails because recipient is not whitelisted
        whitelistFleet.transfer(nonWhitelistedUser, amountToTransfer);
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
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser2,
            true
        );
        whitelistFleet.setFleetTokenTransferability(true); // Enable transfers
        vm.stopPrank();

        // Operator deposits for mockUser2
        mockToken.mint(operator, amountToTransfer);
        vm.startPrank(operator);
        mockToken.approve(address(whitelistFleet), amountToTransfer);
        whitelistFleet.deposit(amountToTransfer, mockUser2);
        vm.stopPrank();

        // mockUser2 approves mockUser
        vm.startPrank(mockUser2);
        whitelistFleet.approve(mockUser, amountToTransfer);
        vm.stopPrank();

        vm.startPrank(mockUser);
        vm.expectRevert();
        // Fails because recipient (nonWhitelistedUser) is not whitelisted
        whitelistFleet.transferFrom(
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
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            whitelistedRecipient,
            true
        );
        // Transfers stay DISABLED (default)

        vm.startPrank(mockUser);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderTransfersDisabled()")
        );
        whitelistFleet.transfer(whitelistedRecipient, amountToTransfer);
        vm.stopPrank();
    }
}
