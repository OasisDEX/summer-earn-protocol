// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {FleetCommanderWhitelistParams} from "../../src/types/FleetCommanderTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Test} from "forge-std/Test.sol";

contract FleetCommanderWhitelistMaxTests is
    Test,
    TestHelpers,
    FleetCommanderTestBase
{
    FleetCommanderWhitelist public whitelistFleet;
    FleetCommanderWhitelistParams public whitelistFleetParams;
    address public nonWhitelistedUser = makeAddr("nonWhitelistedUser");

    function setUp() public {
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
        harborCommand.enlistFleetCommander(address(whitelistFleet));

        // Whitelist mockUser
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser,
            true
        );
        vm.stopPrank();
    }

    /**
     * @notice Tests that max functions return positive values during normal operation,
     * then return 0 when the fleet is paused.
     */
    function test_maxFunctions_transitionToPaused() public {
        mockToken.mint(mockUser, 1000);

        // 1. Verify normal behavior (non-zero)
        assertGt(whitelistFleet.maxDeposit(mockUser), 0);
        assertGt(whitelistFleet.maxMint(mockUser), 0);

        // Setup some shares for withdrawal tests
        vm.startPrank(mockUser);
        mockToken.approve(address(whitelistFleet), 1000);
        whitelistFleet.deposit(1000, mockUser);
        vm.stopPrank();

        assertGt(whitelistFleet.maxWithdraw(mockUser), 0);
        assertGt(whitelistFleet.maxRedeem(mockUser), 0);
        assertGt(whitelistFleet.maxBufferWithdraw(mockUser), 0);
        assertGt(whitelistFleet.maxBufferRedeem(mockUser), 0);

        // 2. Transition to paused
        vm.prank(governor);
        whitelistFleet.pause();

        // 3. Verify they return 0
        assertEq(whitelistFleet.maxDeposit(mockUser), 0);
        assertEq(whitelistFleet.maxMint(mockUser), 0);
        assertEq(whitelistFleet.maxWithdraw(mockUser), 0);
        assertEq(whitelistFleet.maxRedeem(mockUser), 0);
        assertEq(whitelistFleet.maxBufferWithdraw(mockUser), 0);
        assertEq(whitelistFleet.maxBufferRedeem(mockUser), 0);
    }

    /**
     * @notice Tests that max functions return positive values during normal operation,
     * then return 0 when the user is removed from the whitelist.
     */
    function test_maxFunctions_transitionToNonWhitelisted() public {
        mockToken.mint(mockUser, 1000);

        // 1. Verify normal behavior (non-zero)
        assertGt(whitelistFleet.maxDeposit(mockUser), 0);
        assertGt(whitelistFleet.maxMint(mockUser), 0);

        // Setup some shares for withdrawal tests
        vm.startPrank(mockUser);
        mockToken.approve(address(whitelistFleet), 1000);
        whitelistFleet.deposit(1000, mockUser);
        vm.stopPrank();

        assertGt(whitelistFleet.maxWithdraw(mockUser), 0);
        assertGt(whitelistFleet.maxRedeem(mockUser), 0);
        assertGt(whitelistFleet.maxBufferWithdraw(mockUser), 0);
        assertGt(whitelistFleet.maxBufferRedeem(mockUser), 0);

        // 2. Transition to non-whitelisted
        vm.prank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser,
            false
        );

        // 3. Verify they return 0
        assertEq(whitelistFleet.maxDeposit(mockUser), 0);
        assertEq(whitelistFleet.maxMint(mockUser), 0);
        assertEq(whitelistFleet.maxWithdraw(mockUser), 0);
        assertEq(whitelistFleet.maxRedeem(mockUser), 0);
        assertEq(whitelistFleet.maxBufferWithdraw(mockUser), 0);
        assertEq(whitelistFleet.maxBufferRedeem(mockUser), 0);
    }
}
