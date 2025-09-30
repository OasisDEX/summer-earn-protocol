// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeRouter} from "../../../src/router/BridgeRouter.sol";

import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

import {RejectETH} from "../../mocks/RejectETH.sol";

// (moved) ReentrancyAttacker now lives in BridgeRouter.recovery.t.sol tests

contract BridgeRouterAdminTest is BridgeRouterSetup {
    // ---- ADMIN FUNCTION TESTS ----

    function testPauseUnpause_ByGovernor_Succeeds() public {
        vm.startPrank(governor);

        // Pause
        assertFalse(router.paused());
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterPaused(governor);
        router.pause();
        assertTrue(router.paused());

        // Unpause
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterUnpaused(governor);
        router.unpause();
        assertFalse(router.paused());

        vm.stopPrank();
    }

    function testPause_ByGuardian_Succeeds_Unpause_Reverts() public {
        vm.startPrank(guardian);

        // Guardian can pause
        assertFalse(router.paused());
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterPaused(guardian);
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

    function testPause_Unauthorized_Reverts() public {
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

    function testExecuteTransferAssets_Reverts_WhenPaused() public {
        // Pause the router
        vm.prank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterPaused(governor);
        router.pause();

        // User attempts to queue (NO VALUE)
        vm.startPrank(user);
        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeToken: address(0)
        });

        // Get fee estimate first (for keeper execution)
        (uint256 nativeFee, , address specifiedAdapter) = router
            .quoteTransferAssets(
                BridgeTypes.ExecuteTransferParams({
                    originator: user,
                    destinationChainId: DEST_CHAIN_ID,
                    target: recipient,
                    asset: address(token),
                    amount: TRANSFER_AMOUNT,
                    message: "",
                    refundAddress: user
                }),
                options
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
                target: user,
                originator: user,
                refundAddress: address(executor),
                message: ""
            }),
            options
        );

        vm.stopPrank();
    }

    function testExecuteReadState_Reverts_WhenPaused() public {
        // Pause the router
        vm.prank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterPaused(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeToken: address(0)
        });

        vm.stopPrank(); // User stops queueing

        vm.startPrank(executor);

        // Get quote for execution
        (uint256 nativeFee, , ) = router.quoteReadState(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(0x1234), // Target contract
                selector: bytes4(keccak256("someFunction()")),
                readParams: "",
                originator: user,
                refundAddress: user
            }),
            options
        );

        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeReadState{value: nativeFee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(mockAdapter), // Use mock adapter as target contract
                selector: bytes4(keccak256("test()")), // Example function selector
                readParams: "", // Empty params
                originator: user,
                refundAddress: address(keeper)
            }),
            options
        );

        vm.stopPrank();
    }

    function testExecuteSendMessage_Reverts_WhenPaused() public {
        // Pause the router
        vm.prank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterPaused(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeToken: address(0)
        });

        vm.stopPrank(); // User stops queueing

        // Attempt to execute the queued operation (e.g., by keeper)
        vm.startPrank(executor);

        // The router's execute call should revert because it's paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user, // Send to self for testing
                message: "", // Empty message
                originator: user,
                refundAddress: address(keeper)
            }),
            options
        );
        vm.stopPrank();
    }

    // recover assets tests moved to BridgeRouter.recovery.t.sol
}
