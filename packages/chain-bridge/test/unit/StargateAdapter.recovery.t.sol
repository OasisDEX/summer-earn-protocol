// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {MockFleetProxy} from "../mocks/MockFleetProxy.sol";
import {MockStargateV2Pool} from "../mocks/MockStargateV2.sol";
import {StargateAdapterTestWrapper} from "./StargateAdapterTestWrapper.sol";

/**
 * @title StargateAdapterRecoveryTest
 * @notice Simple test suite for StargateAdapter recovery functionality
 */
contract StargateAdapterRecoveryTest is StargateAdapterSetupTest {
    StargateAdapterTestWrapper public wrapperB;
    MockFleetProxy public fleetProxy;
    MockStargateV2Pool public mockStargate;

    bytes32 public constant TEST_OPERATION_ID = bytes32("test-operation-id");
    address public constant TEST_ORIGINATOR = address(0x1234);
    uint256 public constant TEST_AMOUNT = 1 ether;

    event ComposeFailedAssetsHeld(
        bytes32 indexed operationId,
        address indexed asset,
        uint256 amount,
        address intendedRecipient,
        bool isDeposit,
        string reason
    );

    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    function setUp() public override {
        super.setUp();

        useNetworkB();

        // Deploy test wrapper
        vm.startPrank(governor);
        wrapperB = new StargateAdapterTestWrapper(
            address(registryB), // Use registry instead of router
            address(accessManagerB), // Use access manager instead of owner
            lzEndpointB,
            address(0xdead) // Mock HarborCommand address for testing
        );
        vm.stopPrank();

        // Deploy mock contracts
        fleetProxy = new MockFleetProxy(address(tokenB));
        mockStargate = new MockStargateV2Pool(address(tokenB));

        // Mint tokens to wrapper for testing
        tokenB.mint(address(wrapperB), TEST_AMOUNT * 5);
    }

    /*//////////////////////////////////////////////////////////////
                      FAILED COMPOSE STORAGE TESTS
    //////////////////////////////////////////////////////////////*/

    function testAddFailedCompose() public {
        // Add a test failed compose
        wrapperB.addTestFailedCompose(
            TEST_OPERATION_ID,
            address(tokenB),
            TEST_AMOUNT,
            address(fleetProxy),
            TEST_ORIGINATOR,
            CHAIN_ID_A,
            true // isDeposit
        );

        // Check it was stored
        bytes32[] memory failedOps = wrapperB.getFailedOperations();
        assertEq(failedOps.length, 1);
        assertEq(failedOps[0], TEST_OPERATION_ID);

        // Check details
        StargateAdapter.FailedCompose memory failed = wrapperB.getFailedCompose(
            TEST_OPERATION_ID
        );
        assertEq(failed.asset, address(tokenB));
        assertEq(failed.amount, TEST_AMOUNT);
        assertEq(failed.intendedRecipient, address(fleetProxy));
        assertTrue(failed.isDeposit);
    }

    /*//////////////////////////////////////////////////////////////
                      RECOVERY FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testRecoverFailedComposesFleetProxy() public {
        // Add a test failed compose for FleetProxy
        wrapperB.addTestFailedCompose(
            TEST_OPERATION_ID,
            address(tokenB),
            TEST_AMOUNT,
            address(fleetProxy),
            TEST_ORIGINATOR,
            CHAIN_ID_A,
            true // isDeposit
        );

        // Verify it was stored
        assertEq(wrapperB.getFailedOperations().length, 1);

        // Recover it
        bytes32[] memory opsToRecover = new bytes32[](1);
        opsToRecover[0] = TEST_OPERATION_ID;

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(tokenB), TEST_AMOUNT, address(fleetProxy));

        vm.prank(governor);
        wrapperB.manualRecovery(
            address(tokenB),
            TEST_AMOUNT,
            address(fleetProxy),
            TEST_OPERATION_ID,
            true, // tryReceiveCall
            "" // customMessage
        );

        // Check it was cleared
        assertEq(wrapperB.getFailedOperations().length, 0);

        // Check tokens were transferred
        assertEq(tokenB.balanceOf(address(fleetProxy)), TEST_AMOUNT);
    }

    function testRecoverFailedComposesNonDeposit() public {
        // Add a test failed compose for withdrawal (not a deposit)
        address mockRecipient = address(0x9999);
        wrapperB.addTestFailedCompose(
            TEST_OPERATION_ID,
            address(tokenB),
            TEST_AMOUNT,
            mockRecipient,
            TEST_ORIGINATOR,
            CHAIN_ID_A,
            false // isDeposit = false (withdrawal)
        );

        // Recover it - should use the simplified CrossChainArk recovery (just emit event)
        bytes32[] memory opsToRecover = new bytes32[](1);
        opsToRecover[0] = TEST_OPERATION_ID;

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(tokenB), TEST_AMOUNT, mockRecipient);

        vm.prank(governor);
        wrapperB.manualRecovery(
            address(tokenB),
            TEST_AMOUNT,
            mockRecipient,
            TEST_OPERATION_ID,
            false, // tryReceiveCall
            "" // customMessage
        );

        // Check it was cleared from failed list
        assertEq(wrapperB.getFailedOperations().length, 0);
    }

    function testRecoverFailedComposesUnauthorized() public {
        vm.expectRevert(); // Should revert with Ownable error
        vm.prank(user);
        wrapperB.manualRecovery(
            address(tokenB),
            0,
            address(0x9999),
            bytes32(0),
            false,
            ""
        );
    }

    function testRecoverFailedComposesInsufficientBalance() public {
        // Add a failed operation
        wrapperB.addTestFailedCompose(
            TEST_OPERATION_ID,
            address(tokenB),
            TEST_AMOUNT,
            address(fleetProxy),
            TEST_ORIGINATOR,
            CHAIN_ID_A,
            true
        );

        // Remove tokens from wrapper - transfer from wrapper to this test contract
        uint256 wrapperBalance = tokenB.balanceOf(address(wrapperB));
        vm.prank(address(wrapperB));
        assertTrue(tokenB.transfer(address(this), wrapperBalance));

        // Verify wrapper now has 0 balance
        assertEq(tokenB.balanceOf(address(wrapperB)), 0);

        // Try to recover manually - should revert with InsufficientBalance
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        wrapperB.manualRecovery(
            address(tokenB),
            TEST_AMOUNT,
            address(fleetProxy),
            TEST_OPERATION_ID,
            false,
            ""
        );

        // Operation should still be in failed list since recovery failed
        assertEq(wrapperB.getFailedOperations().length, 1);
    }

    /*//////////////////////////////////////////////////////////////
                      MANUAL RECOVERY TESTS
    //////////////////////////////////////////////////////////////*/

    function testManualRecovery() public {
        address recipient = address(0x9999);

        vm.expectEmit(true, false, true, false);
        emit TokensRecovered(address(tokenB), TEST_AMOUNT, recipient);

        vm.prank(governor);
        wrapperB.manualRecovery(
            address(tokenB),
            TEST_AMOUNT,
            recipient,
            bytes32(0), // No operation ID
            false, // tryReceiveCall
            "" // customMessage
        );

        // Check tokens were transferred
        assertEq(tokenB.balanceOf(recipient), TEST_AMOUNT);
    }

    function testManualRecoveryWithOperationIdClearing() public {
        // Add a failed operation first
        wrapperB.addTestFailedCompose(
            TEST_OPERATION_ID,
            address(tokenB),
            TEST_AMOUNT,
            address(fleetProxy),
            TEST_ORIGINATOR,
            CHAIN_ID_A,
            true
        );

        address recipient = address(0x9999);

        vm.prank(governor);
        wrapperB.manualRecovery(
            address(tokenB),
            TEST_AMOUNT,
            recipient,
            TEST_OPERATION_ID, // Clear this operation
            false, // tryReceiveCall
            "" // customMessage
        );

        // Check operation was cleared
        StargateAdapter.FailedCompose memory failed = wrapperB.getFailedCompose(
            TEST_OPERATION_ID
        );
        assertEq(failed.asset, address(0)); // Should be cleared
    }

    function testManualRecoveryUnauthorized() public {
        vm.expectRevert(); // Should revert with Ownable error
        vm.prank(user);
        wrapperB.manualRecovery(
            address(tokenB),
            TEST_AMOUNT,
            address(0x9999),
            bytes32(0),
            false, // tryReceiveCall
            "" // customMessage
        );
    }

    function testManualRecoveryZeroAddress() public {
        vm.expectRevert(); // Should revert with InvalidParams
        vm.prank(governor);
        wrapperB.manualRecovery(
            address(tokenB),
            TEST_AMOUNT,
            address(0), // Zero address
            bytes32(0),
            false, // tryReceiveCall
            "" // customMessage
        );
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetFailedOperationsEmpty() public view {
        bytes32[] memory failedOps = wrapperB.getFailedOperations();
        assertEq(failedOps.length, 0);
    }

    function testGetFailedComposeNonExistent() public view {
        StargateAdapter.FailedCompose memory failed = wrapperB.getFailedCompose(
            bytes32("nonexistent")
        );
        assertEq(failed.asset, address(0));
        assertEq(failed.amount, 0);
    }

    function testGetAdapterBalance() public view {
        uint256 balance = wrapperB.getAdapterBalance(address(tokenB));
        assertEq(balance, TEST_AMOUNT * 5);
    }
}
