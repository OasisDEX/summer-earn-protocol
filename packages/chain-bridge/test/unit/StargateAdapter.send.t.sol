// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IStargateRouter} from "../../src/interfaces/IStargateRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeRouterTestHelper} from "../../test/helpers/BridgeRouterTestHelper.sol";

contract StargateAdapterSendTest is StargateAdapterSetupTest {
    function testEstimateFee() public {
        useNetworkA();

        // Create adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Estimate fee for transferring assets
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Verify the fee is returned properly
        assertTrue(nativeFee > 0);
        assertEq(tokenFee, 0); // No token fee for Stargate adapter
    }

    function testEstimateFeeUnsupportedChain() public {
        useNetworkA();

        // Create adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Should revert when estimating fee for unsupported chain
        vm.expectRevert(IBridgeAdapter.UnsupportedChain.selector);
        adapterA.estimateFee(
            9999, // Unsupported chain
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    function testEstimateFeeUnsupportedAsset() public {
        useNetworkA();

        // Create adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Should revert when estimating fee for unsupported asset
        vm.expectRevert(IBridgeAdapter.UnsupportedAsset.selector);
        adapterA.estimateFee(
            CHAIN_ID_B,
            address(0xdead), // Unsupported asset
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    function testTransferAsset() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // First estimate the fee
        (uint256 nativeFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Approve tokens for the adapter
        vm.prank(user);
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calculate the operation ID that will be generated
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A, // block.chainid in the test
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp
            )
        );

        // Setup the router to expect this operation from this adapter
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
        );

        // Mock a transfer request from the router
        vm.prank(address(routerA));
        bytes32 operationId = adapterA.transferAsset{value: nativeFee}(
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            adapterParams
        );

        // Verify operation ID was generated and returned
        assertTrue(operationId != bytes32(0));

        // Verify it matches our pre-calculated ID
        assertEq(operationId, expectedOperationId);
    }

    function testTransferAssetUnauthorized() public {
        useNetworkA();
        vm.deal(user, 1 ether); // Provide ETH to the user

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Approve tokens for the adapter
        vm.prank(user);
        tokenA.approve(address(adapterA), 1 ether);

        // Should revert when called by non-router
        vm.prank(user);
        vm.expectRevert(IBridgeAdapter.Unauthorized.selector);
        adapterA.transferAsset{value: 0.1 ether}(
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            adapterParams
        );
    }

    function testTransferAssetUnsupportedChain() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Should revert when transferring to unsupported chain
        vm.prank(address(routerA));
        vm.expectRevert(IBridgeAdapter.UnsupportedChain.selector);
        adapterA.transferAsset{value: 0.1 ether}(
            9999, // Unsupported chain
            address(tokenA),
            recipient,
            1 ether,
            user,
            adapterParams
        );
    }

    function testTransferAssetUnsupportedAsset() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Should revert when transferring unsupported asset
        vm.prank(address(routerA));
        vm.expectRevert(IBridgeAdapter.UnsupportedAsset.selector);
        adapterA.transferAsset{value: 0.1 ether}(
            CHAIN_ID_B,
            address(0xdead), // Unsupported asset
            recipient,
            1 ether,
            user,
            adapterParams
        );
    }

    function testTransferAssetInsufficientFee() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Estimate the required fee
        (uint256 requiredFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Add token approval for the adapter - this is needed
        vm.prank(user);
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calculate the operation ID that will be generated
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A, // block.chainid in the test
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp
            )
        );

        // Setup the router to expect this operation from this adapter
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
        );

        // Try to transfer with insufficient fee (half of required)
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.InsufficientFee.selector,
                requiredFee,
                requiredFee / 2
            )
        );
        adapterA.transferAsset{value: requiredFee / 2}(
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            adapterParams
        );
    }

    function testUnsupportedOperations() public {
        useNetworkA();

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Test readState (unsupported)
        vm.prank(address(routerA));
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.readState(
            CHAIN_ID_B,
            address(tokenA),
            bytes4(0),
            "",
            user,
            adapterParams
        );

        // Test sendMessage (unsupported)
        vm.prank(address(routerA));
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.sendMessage(CHAIN_ID_B, recipient, "", user, adapterParams);
    }
}
