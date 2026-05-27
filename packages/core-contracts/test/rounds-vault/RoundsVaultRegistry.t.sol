// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RoundsVaultRegistry} from "../../src/contracts/rounds-vault/RoundsVaultRegistry.sol";
import {IRoundsVaultBaseEnums} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEnums.sol";
import {IRoundsVaultRegistry} from "../../src/interfaces/rounds-vault/IRoundsVaultRegistry.sol";
import {IRoundsVaultRegistryErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultRegistryErrors.sol";
import {IRoundsVaultRegistryEvents} from "../../src/interfaces/rounds-vault/IRoundsVaultRegistryEvents.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

/// @dev Flavor-aware stand-in for a RoundsVaultInput. Exposes `vault()` and `VAULT_TYPE()`.
contract InputVaultStub {
    address public immutable vault;
    IRoundsVaultBaseEnums.BaseVaultType public constant VAULT_TYPE =
        IRoundsVaultBaseEnums.BaseVaultType.Input;

    constructor(address target) {
        vault = target;
    }
}

/// @dev Flavor-aware stand-in for a RoundsVaultOutput.
contract OutputVaultStub {
    address public immutable vault;
    IRoundsVaultBaseEnums.BaseVaultType public constant VAULT_TYPE =
        IRoundsVaultBaseEnums.BaseVaultType.Output;

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

    address internal owner = address(0xC0);
    address internal nonOwner = address(0xBAD);
    address internal targetA = address(0xA);
    address internal targetB = address(0xB);

    bytes32 internal constant INSTITUTION_X = bytes32("INSTITUTION_X");
    bytes32 internal constant INSTITUTION_Y = bytes32("INSTITUTION_Y");

    InputVaultStub internal inputA;
    OutputVaultStub internal outputA;
    InputVaultStub internal inputB;
    OutputVaultStub internal outputB;

    function setUp() public {
        registry = new RoundsVaultRegistry(owner);

        inputA = new InputVaultStub(targetA);
        outputA = new OutputVaultStub(targetA);
        inputB = new InputVaultStub(targetB);
        outputB = new OutputVaultStub(targetB);
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

        vm.prank(owner);
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
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(0)
        );
        assertEq(registry.getPairByTarget(targetA).outputVault, address(0));
    }

    function test_RegisterPair_OnlyOutput() public {
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(0),
            address(outputA)
        );
        assertEq(registry.getPairByTarget(targetA).inputVault, address(0));
    }

    function test_RegisterPair_RevertWhen_NonOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        vm.prank(nonOwner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
    }

    function test_RegisterPair_RevertWhen_TargetZero() public {
        vm.expectRevert(TargetVaultZero.selector);
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            address(0),
            address(inputA),
            address(outputA)
        );
    }

    function test_RegisterPair_RevertWhen_BothVaultsZero() public {
        vm.expectRevert(NoVaultProvided.selector);
        vm.prank(owner);
        registry.registerPair(INSTITUTION_X, targetA, address(0), address(0));
    }

    function test_RegisterPair_RevertWhen_AlreadyExists() public {
        vm.startPrank(owner);
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
        vm.prank(owner);
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
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputB)
        );
    }

    function test_RegisterPair_RevertWhen_InputFlavorMismatch() public {
        // Pass an Output-flavor address into the input slot.
        OutputVaultStub badInput = new OutputVaultStub(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultFlavorMismatch.selector,
                address(badInput),
                IRoundsVaultBaseEnums.BaseVaultType.Input,
                IRoundsVaultBaseEnums.BaseVaultType.Output
            )
        );
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(badInput),
            address(outputA)
        );
    }

    function test_RegisterPair_RevertWhen_OutputFlavorMismatch() public {
        InputVaultStub badOutput = new InputVaultStub(targetA);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultFlavorMismatch.selector,
                address(badOutput),
                IRoundsVaultBaseEnums.BaseVaultType.Output,
                IRoundsVaultBaseEnums.BaseVaultType.Input
            )
        );
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(badOutput)
        );
    }

    function test_RegisterPair_MultiplePairsAccumulate() public {
        vm.startPrank(owner);
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
                              SET INPUT
    //////////////////////////////////////////////////////////////*/

    function test_SetInputVault_Happy_FillInMissingSide() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(0),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectEmit(true, false, false, true);
        emit RoundsVaultPairUpdated(pairId, address(inputA), address(outputA));
        registry.setInputVault(pairId, address(inputA));
        vm.stopPrank();

        IRoundsVaultRegistry.RoundsVaultPair memory stored = registry.getPair(
            pairId
        );
        assertEq(stored.inputVault, address(inputA));
        assertEq(stored.outputVault, address(outputA));
    }

    function test_SetInputVault_Happy_ReplaceExisting() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);
        InputVaultStub freshInput = new InputVaultStub(targetA);

        registry.setInputVault(pairId, address(freshInput));
        vm.stopPrank();

        assertEq(registry.getPair(pairId).inputVault, address(freshInput));
    }

    function test_SetInputVault_RevertWhen_Zero() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(UseClearInsteadOfZero.selector, pairId)
        );
        registry.setInputVault(pairId, address(0));
        vm.stopPrank();
    }

    function test_SetInputVault_RevertWhen_NotFound() public {
        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(abi.encodeWithSelector(PairNotFound.selector, pairId));
        vm.prank(owner);
        registry.setInputVault(pairId, address(inputA));
    }

    function test_SetInputVault_RevertWhen_TargetMismatch() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(
                TargetMismatch.selector,
                address(inputB),
                targetA,
                targetB
            )
        );
        registry.setInputVault(pairId, address(inputB));
        vm.stopPrank();
    }

    function test_SetInputVault_RevertWhen_FlavorMismatch() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        // outputA wraps targetA but is flavor=Output; passing it into setInputVault must revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultFlavorMismatch.selector,
                address(outputA),
                IRoundsVaultBaseEnums.BaseVaultType.Input,
                IRoundsVaultBaseEnums.BaseVaultType.Output
            )
        );
        registry.setInputVault(pairId, address(outputA));
        vm.stopPrank();
    }

    function test_SetInputVault_RevertWhen_NonOwner() public {
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        vm.prank(nonOwner);
        registry.setInputVault(pairId, address(inputA));
    }

    /*//////////////////////////////////////////////////////////////
                              SET OUTPUT
    //////////////////////////////////////////////////////////////*/

    function test_SetOutputVault_Happy_FillInMissingSide() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(0)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectEmit(true, false, false, true);
        emit RoundsVaultPairUpdated(pairId, address(inputA), address(outputA));
        registry.setOutputVault(pairId, address(outputA));
        vm.stopPrank();

        assertEq(registry.getPair(pairId).outputVault, address(outputA));
    }

    function test_SetOutputVault_RevertWhen_FlavorMismatch() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(
                VaultFlavorMismatch.selector,
                address(inputA),
                IRoundsVaultBaseEnums.BaseVaultType.Output,
                IRoundsVaultBaseEnums.BaseVaultType.Input
            )
        );
        registry.setOutputVault(pairId, address(inputA));
        vm.stopPrank();
    }

    function test_SetOutputVault_RevertWhen_Zero() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(UseClearInsteadOfZero.selector, pairId)
        );
        registry.setOutputVault(pairId, address(0));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              CLEARS
    //////////////////////////////////////////////////////////////*/

    function test_ClearInputVault_Happy() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectEmit(true, false, false, true);
        emit RoundsVaultPairUpdated(pairId, address(0), address(outputA));
        registry.clearInputVault(pairId);
        vm.stopPrank();

        assertEq(registry.getPair(pairId).inputVault, address(0));
    }

    function test_ClearInputVault_RevertWhen_OutputAlreadyEmpty() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(0)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(UpdateWouldEmptyPair.selector, pairId)
        );
        registry.clearInputVault(pairId);
        vm.stopPrank();
    }

    function test_ClearOutputVault_Happy() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectEmit(true, false, false, true);
        emit RoundsVaultPairUpdated(pairId, address(inputA), address(0));
        registry.clearOutputVault(pairId);
        vm.stopPrank();

        assertEq(registry.getPair(pairId).outputVault, address(0));
    }

    function test_ClearOutputVault_RevertWhen_InputAlreadyEmpty() public {
        vm.startPrank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(0),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(UpdateWouldEmptyPair.selector, pairId)
        );
        registry.clearOutputVault(pairId);
        vm.stopPrank();
    }

    function test_ClearInputVault_RevertWhen_NonOwner() public {
        vm.prank(owner);
        registry.registerPair(
            INSTITUTION_X,
            targetA,
            address(inputA),
            address(outputA)
        );
        bytes32 pairId = registry.getPairId(targetA);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        vm.prank(nonOwner);
        registry.clearInputVault(pairId);
    }

    /*//////////////////////////////////////////////////////////////
                       DEACTIVATE / REACTIVATE
    //////////////////////////////////////////////////////////////*/

    function test_DeactivateThenReactivate_Flow() public {
        vm.startPrank(owner);
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
        vm.expectRevert(abi.encodeWithSelector(PairNotFound.selector, pairId));
        vm.prank(owner);
        registry.deactivatePair(pairId);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function test_GetPair_RevertWhen_NotFound() public {
        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(abi.encodeWithSelector(PairNotFound.selector, pairId));
        registry.getPair(pairId);
    }

    function test_GetPairByTarget_RevertWhen_NotFound() public {
        bytes32 pairId = registry.getPairId(targetA);
        vm.expectRevert(abi.encodeWithSelector(PairNotFound.selector, pairId));
        registry.getPairByTarget(targetA);
    }

    function test_GetPairId_IsDeterministic() public view {
        assertEq(
            registry.getPairId(targetA),
            keccak256(abi.encodePacked(targetA))
        );
    }
}
