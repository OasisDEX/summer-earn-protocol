// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RoundsVaultRegistry} from "../../src/contracts/rounds-vault/RoundsVaultRegistry.sol";
import {IRoundsVaultRegistry} from "../../src/interfaces/rounds-vault/IRoundsVaultRegistry.sol";
import {IRoundsVaultRegistryErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultRegistryErrors.sol";
import {IRoundsVaultRegistryEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultRegistryEvents.sol";
import {MockAccessManager} from "../mocks/MockAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @dev Minimal stand-in for a RoundsVaultInput/Output: only exposes `vault()` because that is the
 *      single view the registry calls during validation.
 */
contract VaultWrapperStub {
    address public immutable vault;

    constructor(address target) {
        vault = target;
    }
}

contract RoundsVaultRegistryTest is
    Test,
    IRoundsVaultRegistryErrors,
    IRoundsVaultRegistryEvents
{
    RoundsVaultRegistry internal registry;
    MockAccessManager internal accessManager;

    address internal governor = address(0xC0);
    address internal nonGovernor = address(0xBAD);
    address internal targetA = address(0xA);
    address internal targetB = address(0xB);

    bytes32 internal constant INSTITUTION_X =
        bytes32("INSTITUTION_X");
    bytes32 internal constant INSTITUTION_Y =
        bytes32("INSTITUTION_Y");

    VaultWrapperStub internal inputA;
    VaultWrapperStub internal outputA;
    VaultWrapperStub internal inputB;
    VaultWrapperStub internal outputB;

    function setUp() public {
        accessManager = new MockAccessManager();
        accessManager.grantRole(accessManager.GOVERNOR_ROLE(), governor);

        registry = new RoundsVaultRegistry(address(accessManager));

        inputA = new VaultWrapperStub(targetA);
        outputA = new VaultWrapperStub(targetA);
        inputB = new VaultWrapperStub(targetB);
        outputB = new VaultWrapperStub(targetB);
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTER PAIR
    //////////////////////////////////////////////////////////////*/

    function test_RegisterPair_Happy() public {
        bytes32 expectedPairId = registry.getPairId(targetA);

        vm.expectEmit(true, true, true, true);
        emit RoundsVaultPairRegistered(
            expectedPairId,
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );

        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );

        IRoundsVaultRegistry.RoundsVaultPair memory stored = registry.getPair(
            expectedPairId
        );
        assertEq(stored.inputVault, address(inputA));
        assertEq(stored.outputVault, address(outputA));
        assertEq(stored.targetVault, targetA);
        assertEq(stored.institutionId, INSTITUTION_X);
        assertTrue(stored.active);
        assertEq(uint256(stored.registeredAt), block.timestamp);

        assertEq(registry.pairCount(), 1);
        assertEq(registry.pairIdAt(0), expectedPairId);
    }

    function test_RegisterPair_OnlyInput() public {
        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(0)
        );

        IRoundsVaultRegistry.RoundsVaultPair memory stored = registry
            .getPairByTarget(targetA);
        assertEq(stored.inputVault, address(inputA));
        assertEq(stored.outputVault, address(0));
    }

    function test_RegisterPair_OnlyOutput() public {
        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(0),
            address(outputA)
        );

        IRoundsVaultRegistry.RoundsVaultPair memory stored = registry
            .getPairByTarget(targetA);
        assertEq(stored.outputVault, address(outputA));
        assertEq(stored.inputVault, address(0));
    }

    function test_RegisterPair_RevertWhen_NonGovernor() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlErrors.CallerIsNotGovernor.selector, nonGovernor)
        );
        vm.prank(nonGovernor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
    }

    function test_RegisterPair_RevertWhen_TargetZero() public {
        vm.expectRevert(TargetVaultZero.selector);
        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            address(0),
            address(inputA),
            address(outputA)
        );
    }

    function test_RegisterPair_RevertWhen_BothVaultsZero() public {
        vm.expectRevert(NoVaultProvided.selector);
        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(0),
            address(0)
        );
    }

    function test_RegisterPair_RevertWhen_AlreadyExists() public {
        vm.startPrank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );

        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(PairAlreadyExists.selector, pairId)
        );
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        vm.stopPrank();
    }

    function test_RegisterPair_RevertWhen_InputTargetMismatch() public {
        // inputB wraps targetB, but we declare target as targetA
        vm.expectRevert(
            abi.encodeWithSelector(
                TargetMismatch.selector,
                address(inputB),
                targetA,
                targetB
            )
        );
        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputB),
            address(outputA)
        );
    }

    function test_RegisterPair_RevertWhen_OutputTargetMismatch() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TargetMismatch.selector,
                address(outputB),
                targetA,
                targetB
            )
        );
        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputB)
        );
    }

    function test_RegisterPair_MultiplePairsAccumulate() public {
        vm.startPrank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        registry.registerPair(
            INSTITUTION_Y,
            targetB,
            address(inputB),
            address(outputB)
        );
        vm.stopPrank();

        assertEq(registry.pairCount(), 2);
        assertEq(registry.pairIdAt(0), registry.getPairId(targetA));
        assertEq(registry.pairIdAt(1), registry.getPairId(targetB));
    }

    /*//////////////////////////////////////////////////////////////
                              UPDATE PAIR
    //////////////////////////////////////////////////////////////*/

    function test_UpdatePair_FillInMissingSide() public {
        // First register with only input
        vm.startPrank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(0)
        );
        bytes32 pairId = registry.getPairId(targetA);

        // Now fill in the output side
        vm.expectEmit(true, false, false, true);
        emit RoundsVaultPairUpdated(
            pairId,
            address(inputA),
            address(outputA)
        );
        registry.updatePair(pairId, address(0), address(outputA));
        vm.stopPrank();

        IRoundsVaultRegistry.RoundsVaultPair memory stored = registry.getPair(
            pairId
        );
        assertEq(stored.inputVault, address(inputA));
        assertEq(stored.outputVault, address(outputA));
    }

    function test_UpdatePair_RevertWhen_NotFound() public {
        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(PairNotFound.selector, pairId)
        );
        vm.prank(governor);
        registry.updatePair(pairId, address(inputA), address(0));
    }

    function test_UpdatePair_RevertWhen_NewVaultTargetMismatch() public {
        vm.startPrank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        // inputB wraps targetB, but pair's target is targetA
        vm.expectRevert(
            abi.encodeWithSelector(
                TargetMismatch.selector,
                address(inputB),
                targetA,
                targetB
            )
        );
        registry.updatePair(pairId, address(inputB), address(0));
        vm.stopPrank();
    }

    function test_UpdatePair_RevertWhen_NonGovernor() public {
        vm.prank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );

        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlErrors.CallerIsNotGovernor.selector, nonGovernor)
        );
        vm.prank(nonGovernor);
        registry.updatePair(pairId, address(inputA), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                       DEACTIVATE / REACTIVATE
    //////////////////////////////////////////////////////////////*/

    function test_DeactivateThenReactivate_Flow() public {
        vm.startPrank(governor);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectEmit(true, false, false, true);
        emit RoundsVaultPairDeactivated(pairId);
        registry.deactivatePair(pairId);
        assertFalse(registry.getPair(pairId).active);

        vm.expectRevert(
            abi.encodeWithSelector(PairStateUnchanged.selector, pairId)
        );
        registry.deactivatePair(pairId);

        vm.expectEmit(true, false, false, true);
        emit RoundsVaultPairReactivated(pairId);
        registry.reactivatePair(pairId);
        assertTrue(registry.getPair(pairId).active);

        vm.expectRevert(
            abi.encodeWithSelector(PairStateUnchanged.selector, pairId)
        );
        registry.reactivatePair(pairId);
        vm.stopPrank();
    }

    function test_Deactivate_RevertWhen_NotFound() public {
        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(PairNotFound.selector, pairId)
        );
        vm.prank(governor);
        registry.deactivatePair(pairId);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function test_GetPair_RevertWhen_NotFound() public {
        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(PairNotFound.selector, pairId)
        );
        registry.getPair(pairId);
    }

    function test_GetPairByTarget_RevertWhen_NotFound() public {
        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(PairNotFound.selector, pairId)
        );
        registry.getPairByTarget(targetA);
    }

    function test_GetPairId_IsDeterministic() public view {
        assertEq(
            registry.getPairId(targetA),
            keccak256(abi.encodePacked(targetA))
        );
    }
}
