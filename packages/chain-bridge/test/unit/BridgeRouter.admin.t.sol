// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {Test} from "forge-std/Test.sol";

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

contract BridgeRouterAdminTest is BridgeRouterSetup {
    // ---- ADMIN FUNCTION TESTS ----

    function testPauseByGovernor() public {
        vm.startPrank(governor);

        // Pause
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());

        // Unpause
        router.unpause();
        assertFalse(router.paused());

        vm.stopPrank();
    }

    function testPauseByGuardian() public {
        vm.startPrank(guardian);

        // Guardian can pause
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());

        // Guardian cannot unpause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.unpause();

        vm.stopPrank();
    }

    function testPauseUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-guardian/governor tries to pause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGuardianOrGovernor.selector,
                user
            )
        );
        router.pause();

        vm.stopPrank();
    }

    function testSendWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        // User attempts to queue (NO VALUE)
        vm.startPrank(user);
        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });

        // Get fee estimate first (for keeper execution)
        (uint256 nativeFee, , address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        // vm.deal(user, nativeFee); // REMOVED: User no longer pays

        // Verify the specified adapter matches what we provided
        assertEq(specifiedAdapter, address(mockAdapter));

        vm.stopPrank(); // User stops queueing

        vm.startPrank(executor);

        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeTransferAssets{value: nativeFee}(
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: TRANSFER_AMOUNT,
                recipient: user,
                originator: user,
                keeper: address(executor),
                options: options
            })
        );

        vm.stopPrank();
    }

    function testReadStateWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });

        vm.stopPrank(); // User stops queueing

        vm.startPrank(executor);

        // Get quote for execution
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0), // No asset
            0, // No amount
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeReadState{value: nativeFee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                destinationContract: address(mockAdapter), // Use mock adapter as target contract
                selector: bytes4(keccak256("test()")), // Example function selector
                readParams: "", // Empty params
                originator: user,
                keeper: address(keeper),
                options: options
            })
        );

        vm.stopPrank();
    }

    function testSendMessageWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });
        vm.stopPrank(); // User stops queueing

        // Attempt to execute the queued operation (e.g., by keeper)
        vm.startPrank(executor);

        // The router's execute call should revert because it's paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                recipient: user, // Send to self for testing
                message: "", // Empty message
                originator: user,
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();
    }
}
