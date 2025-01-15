// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetCommanderPausable} from "../../src/contracts/FleetCommanderPausable.sol";

import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {Test} from "forge-std/Test.sol";

import {IArkConfigProviderEvents} from "../../src/events/IArkConfigProviderEvents.sol";

import {IArkConfigProviderEvents} from "../../src/events/IArkConfigProviderEvents.sol";

import {ArkParams, BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {IFleetCommanderConfigProviderEvents} from "../../src/events/IFleetCommanderConfigProviderEvents.sol";
import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";

import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {ContractSpecificRoles, IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PERCENTAGE_100, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract ManagementTest is Test, TestHelpers, FleetCommanderTestBase {
    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
    }

    function test_ConstructorInitialization() public {
        FleetCommanderParams memory params = FleetCommanderParams({
            configurationManager: address(configurationManager),
            accessManager: address(accessManager),
            initialMinimumBufferBalance: 1000,
            initialRebalanceCooldown: 1 hours,
            asset: address(mockToken),
            name: "Fleet Commander",
            symbol: "FC",
            details: "Mock details",
            depositCap: 10000,
            initialTipRate: Percentage.wrap(0)
        });

        FleetCommander newFleetCommander = new FleetCommander(params);
        FleetConfig memory config = newFleetCommander.getConfig();

        assertEq(config.minimumBufferBalance, 1000);
        assertEq(config.depositCap, 10000);
        assertEq(config.maxRebalanceOperations, 50);
        assertTrue(
            newFleetCommander.isArkActiveOrBufferArk(address(config.bufferArk))
        );
    }

    function test_GetArks() public view {
        address[] memory arks = fleetCommander.getActiveArks();
        assertEq(arks.length, 4);
        assertEq(arks[0], address(mockArk1));
        assertEq(arks[1], address(mockArk2));
        assertEq(arks[2], address(mockArk3));
        assertEq(arks[3], address(mockArk4));
    }

    function test_SetMaxAllocationArkNotFound() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0x123)
            )
        );
        fleetCommander.setArkDepositCap(address(0x123), 1000);
    }

    function test_SetMinBufferBalance() public {
        uint256 newBalance = 2000;

        vm.prank(governor);
        vm.expectEmit(false, false, false, true);
        emit IFleetCommanderConfigProviderEvents
            .FleetCommanderminimumBufferBalanceUpdated(newBalance);
        fleetCommander.setMinimumBufferBalance(newBalance);

        FleetConfig memory config = fleetCommander.getConfig();
        assertEq(config.minimumBufferBalance, newBalance);
    }

    function test_TransferDisabled() public {
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderTransfersDisabled()")
        );
        fleetCommander.transfer(address(0x123), 100);
    }

    function test_TransferFromDisabled() public {
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderTransfersDisabled()")
        );
        fleetCommander.transferFrom(address(this), address(0x123), 100);
    }

    function test_RemoveArkWithNonZeroAllocation() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkDepositCapGreaterThanZero(address)",
                address(mockArk1)
            )
        );
        fleetCommander.removeArk(address(mockArk1));
    }

    function test_RemoveBufferArk() public {
        address bufferArkAddress = fleetCommander.bufferArk();
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                bufferArkAddress
            )
        );
        vm.startPrank(governor);
        fleetCommander.removeArk(bufferArkAddress);
        vm.stopPrank();
    }

    function test_RemoveSuccessful() public {
        // First, set max allocation to 0
        uint256 initialArksCount = fleetCommander.getActiveArks().length;
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(mockArk1), 0);

        vm.expectEmit();
        emit IAccessControl.RoleRevoked(
            accessManager.generateRole(
                ContractSpecificRoles.COMMANDER_ROLE,
                address(mockArk1)
            ),
            address(fleetCommander),
            address(fleetCommander)
        );
        vm.prank(governor);
        vm.expectEmit();
        emit IFleetCommanderConfigProviderEvents.ArkRemoved(address(mockArk1));
        fleetCommander.removeArk(address(mockArk1));
        assertEq(fleetCommander.getActiveArks().length, initialArksCount - 1);
        assertEq(
            fleetCommander.isArkActiveOrBufferArk(address(mockArk1)),
            false
        );
    }

    function test_RemoveArkWithNonZeroAssets() public {
        // First, set max allocation to 0
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(mockArk1), 0);

        // Mock non-zero assets
        mockToken.mint(address(mockArk1), 1000);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkAssetsNotZero(address)",
                address(mockArk1)
            )
        );
        fleetCommander.removeArk(address(mockArk1));
    }

    function test_RebalanceWithInvalidArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(0),
            toArk: address(mockArk1),
            amount: 100,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceToArkWithZeroMaxAllocation() public {
        // Set max allocation of mockArk1 to 0
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(mockArk1), 0);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(mockArk2),
            toArk: address(mockArk1),
            amount: 100,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkDepositCapZero(address)",
                address(mockArk1)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_SetMaxRebalanceOperations() public {
        uint256 newMaxRebalanceOperations = 20;
        vm.prank(governor);
        vm.expectEmit();
        emit IFleetCommanderConfigProviderEvents
            .FleetCommanderMaxRebalanceOperationsUpdated(
                newMaxRebalanceOperations
            );

        fleetCommander.setMaxRebalanceOperations(newMaxRebalanceOperations);

        FleetConfig memory config = fleetCommander.getConfig();
        assertEq(config.maxRebalanceOperations, newMaxRebalanceOperations);
    }

    function test_SetDepositCap() public {
        uint256 newDepositCap = 10000;
        vm.prank(governor);
        vm.expectEmit();
        emit IFleetCommanderConfigProviderEvents
            .FleetCommanderDepositCapUpdated(newDepositCap);

        fleetCommander.setFleetDepositCap(newDepositCap);

        FleetConfig memory config = fleetCommander.getConfig();
        assertEq(config.depositCap, newDepositCap);
    }

    function test_setArkDepositCap() public {
        uint256 newDepositCap = 10000;
        vm.prank(governor);
        vm.expectEmit();
        emit IArkConfigProviderEvents.DepositCapUpdated(newDepositCap);
        fleetCommander.setArkDepositCap(address(mockArk2), newDepositCap);
        assertEq(mockArk2.depositCap(), newDepositCap);
    }

    function test_SetArkMaxDepositPercentageOfTVL() public {
        vm.prank(governor);
        vm.expectEmit();
        emit IArkConfigProviderEvents.MaxDepositPercentageOfTVLUpdated(
            PERCENTAGE_100
        );
        fleetCommander.setArkMaxDepositPercentageOfTVL(
            address(mockArk2),
            PERCENTAGE_100
        );
        assertEq(
            Percentage.unwrap(mockArk2.maxDepositPercentageOfTVL()),
            Percentage.unwrap(PERCENTAGE_100)
        );
    }

    function test_updateRebalanceCooldown_ShouldFail() public {
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotCurator(address)", keeper)
        );
        fleetCommander.updateRebalanceCooldown(0);
    }

    function test_SetArkDepositCapInvalidArk_ShouldFail() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(0x123), 1000);
    }

    function test_SetArkMaxDepositPercentageOfTVLInvalidArk_ShouldFail()
        public
    {
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.setArkMaxDepositPercentageOfTVL(
            address(0x123),
            PERCENTAGE_100
        );
    }

    function test_SetArkMoveToMax() public {
        uint256 maxMoveTo = 1000;
        vm.prank(governor);
        vm.expectEmit();
        emit IArkConfigProviderEvents.MaxRebalanceInflowUpdated(maxMoveTo);
        fleetCommander.setArkMaxRebalanceInflow(address(mockArk2), maxMoveTo);

        assertEq(mockArk2.maxRebalanceInflow(), maxMoveTo);
    }

    function test_SetArkMoveToMax_FailNotCurator() public {
        uint256 maxMoveTo = 1000;
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotCurator(address)", keeper)
        );

        fleetCommander.setArkMaxRebalanceInflow(address(mockArk2), maxMoveTo);
    }

    function test_SetArkMoveToMaxInvalidArk_ShouldFail() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.setArkMaxRebalanceInflow(
            address(0x123),
            type(uint256).max
        );
    }

    function test_SetArkMoveMaxRebalanceOutflow() public {
        uint256 maxMoveFrom = 1000;
        vm.prank(governor);
        vm.expectEmit();
        emit IArkConfigProviderEvents.MaxRebalanceOutflowUpdated(maxMoveFrom);
        fleetCommander.setArkMaxRebalanceOutflow(
            address(mockArk2),
            maxMoveFrom
        );

        assertEq(mockArk2.maxRebalanceOutflow(), maxMoveFrom);
    }

    function test_SetArkMoveMaxRebalanceOutflowInvalidArk_ShouldFail() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.setArkMaxRebalanceOutflow(
            address(0x123),
            type(uint256).max
        );
    }

    function test_AddArkWithAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderInvalidArkAddress()")
        );
        vm.prank(governor);
        fleetCommander.addArk(address(0));
    }

    function test_AddAlreadyExistingArk() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkAlreadyExists(address)",
                address(mockArk1)
            )
        );
        vm.prank(governor);
        fleetCommander.addArk(address(mockArk1));
    }

    function test_RemoveNotExistingArk() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.removeArk(address(0x123));
    }

    function test_AddArkWithExistingCommander() public {
        // Create a new mock Ark with a commander already set
        BufferArk mockArkWithCommander = new BufferArk(
            ArkParams({
                name: "MockArkWithCommander",
                details: "Mock details",
                accessManager: address(accessManager),
                asset: address(mockToken),
                configurationManager: address(configurationManager),
                depositCap: 1000,
                maxRebalanceOutflow: 500,
                maxRebalanceInflow: 500,
                requiresKeeperData: false,
                maxDepositPercentageOfTVL: PERCENTAGE_100
            }),
            address(fleetCommander)
        );
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(mockArkWithCommander),
            address(fleetCommander)
        );
        // Try to add the Ark with an existing commander, assuming the fleet has the appropriate role
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderAlreadyRegistered()")
        );
        fleetCommander.addArk(address(mockArkWithCommander));
    }

    function test_PauseAndUnpause() public {
        vm.prank(governor);
        fleetCommander.pause();
        assertTrue(fleetCommander.paused());

        // Try to unpause immediately (should fail)
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderPausableMinimumPauseTimeNotElapsed()"
            )
        );
        fleetCommander.unpause();

        // Wait for minimum pause time
        vm.warp(block.timestamp + fleetCommander.minimumPauseTime());

        // Now unpause should succeed
        vm.prank(governor);
        fleetCommander.unpause();
        assertFalse(fleetCommander.paused());
    }

    function test_PauseAndUnpauseBeforeTime() public {
        vm.prank(governor);
        fleetCommander.pause();
        assertTrue(fleetCommander.paused());

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderPausableMinimumPauseTimeNotElapsed()"
            )
        );
        fleetCommander.unpause();
    }

    function test_SetMinimumPauseTime() public {
        uint256 newMinimumPauseTime = 48 hours;

        vm.prank(governor);
        vm.expectEmit(false, false, false, true);
        emit FleetCommanderPausable.MinimumPauseTimeUpdated(
            newMinimumPauseTime
        );
        fleetCommander.setMinimumPauseTime(newMinimumPauseTime);

        assertEq(fleetCommander.minimumPauseTime(), newMinimumPauseTime);
    }

    function test_PauseNonGovernor() public {
        vm.prank(address(0x123));
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGuardianOrGovernor(address)",
                address(0x123)
            )
        );
        fleetCommander.pause();
    }

    function test_UnpauseNonGovernor() public {
        // First pause the contract
        vm.prank(governor);
        fleetCommander.pause();

        // Try to unpause with non-governor address
        vm.prank(address(0x123));
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGuardianOrGovernor(address)",
                address(0x123)
            )
        );
        fleetCommander.unpause();
    }

    function test_SetMinimumPauseTimeNonGovernor() public {
        vm.prank(address(0x123));
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGovernor(address)",
                address(0x123)
            )
        );
        fleetCommander.setMinimumPauseTime(48 hours);
    }

    function test_setDepositCapWhenPaused() public {
        vm.prank(governor);
        fleetCommander.pause();

        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        fleetCommander.setFleetDepositCap(1000);
    }

    function test_UpdateStakingRewardsManager() public {
        address initialStakingRewardsManager = fleetCommander
            .getConfig()
            .stakingRewardsManager;

        vm.prank(governor);
        fleetCommander.updateStakingRewardsManager();

        FleetConfig memory config = fleetCommander.getConfig();
        assertNotEq(config.stakingRewardsManager, initialStakingRewardsManager);
        assertNotEq(config.stakingRewardsManager, address(0));
    }

    function test_TransfersDisabledByDefault() public view {
        assertEq(
            fleetCommander.transfersEnabled(),
            false,
            "Transfers should be disabled by default"
        );
    }

    function test_SetTransfersEnabled() public {
        vm.prank(governor);
        fleetCommander.setFleetTokenTransferability();

        assertEq(
            fleetCommander.transfersEnabled(),
            true,
            "Transfers should be enabled after setting"
        );
    }

    function test_SetTransfersEnabled_EmitsEvent() public {
        vm.prank(governor);

        vm.expectEmit(true, true, true, true);
        emit IFleetCommanderConfigProviderEvents.TransfersEnabled();
        fleetCommander.setFleetTokenTransferability();
    }

    function test_SetTransfersEnabled_OnlyGovernor() public {
        // Test non-governor cannot enable transfers
        vm.prank(address(0x123));
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGovernor(address)",
                address(0x123)
            )
        );
        fleetCommander.setFleetTokenTransferability();
    }
}
