// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IStargateRouter} from "../../src/interfaces/IStargateRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

contract StargateAdapterReceiveTest is StargateAdapterSetupTest {
    bytes32 testTransferId = bytes32(uint256(12345));

    function testSgReceive() public {
        useNetworkA();

        // Set up a transfer to receive
        uint16 sourceChainId = CHAIN_ID_B;
        bytes memory srcAddress = abi.encode(recipient); // Sender address encoded as bytes
        uint256 amount = 1 ether;

        // Mint tokens to the adapter (simulating that Stargate has transferred tokens)
        tokenA.mint(address(adapterA), amount);

        // Create payload with operation ID
        bytes memory payload = abi.encode(testTransferId);

        // Call sgReceive as if it's coming from the Stargate Router
        vm.prank(address(stargateRouterA));
        adapterA.sgReceive(
            sourceChainId,
            srcAddress,
            1, // nonce
            address(tokenA),
            amount,
            payload
        );

        // Verify token transfer to recipient
        assertEq(tokenA.balanceOf(recipient), amount);

        // Verify router was notified
        // This would need a mock to fully test, but we can at least verify the call doesn't revert
    }

    function testSgReceiveUnauthorized() public {
        useNetworkA();

        // Set up a transfer to receive
        uint16 sourceChainId = CHAIN_ID_B;
        bytes memory srcAddress = abi.encode(recipient);
        uint256 amount = 1 ether;
        bytes memory payload = abi.encode(testTransferId);

        // Mint tokens to the adapter
        tokenA.mint(address(adapterA), amount);

        // Call sgReceive from unauthorized address (not Stargate Router)
        vm.prank(user);
        vm.expectRevert(StargateAdapter.Unauthorized.selector);
        adapterA.sgReceive(
            sourceChainId,
            srcAddress,
            1, // nonce
            address(tokenA),
            amount,
            payload
        );
    }

    function testGetOperationStatus() public {
        useNetworkA();

        // Setup a mock operation status in the router
        vm.prank(address(adapterA));
        routerA.updateOperationStatus(
            testTransferId,
            BridgeTypes.OperationStatus.PENDING
        );

        // Get operation status through adapter
        BridgeTypes.OperationStatus status = adapterA.getOperationStatus(
            testTransferId
        );

        // Verify status matches what was set
        assertEq(uint8(status), uint8(BridgeTypes.OperationStatus.PENDING));
    }
}
