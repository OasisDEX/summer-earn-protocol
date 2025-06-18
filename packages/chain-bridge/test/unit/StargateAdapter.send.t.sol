// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IStargateRouter} from "../../src/interfaces/IStargateRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";

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
        vm.expectRevert(
            abi.encodeWithSelector(StargateAdapter.UnsupportedAsset.selector)
        );
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

        // Transfer tokens to the router and approve the adapter
        // This simulates the router having received tokens from the user
        vm.prank(user);
        tokenA.transfer(address(routerA), 1 ether);

        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calculate the operation ID that will be generated
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A, // block.chainid in the test
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        // Setup the router to expect this operation from this adapter
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
        );

        // Mock a transfer request from the router
        vm.prank(address(routerA));

        // Expect the TransferInitiated event to be emitted (no return value)
        vm.expectEmit(true, true, true, true);
        emit TransferInitiated(
            expectedOperationId,
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            recipient
        );

        adapterA.transferAsset{value: nativeFee}(
            expectedOperationId, // Pass operation ID as first parameter
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
            adapterParams
        );

        // Verify the operation status is SENT
        assertEq(
            uint256(
                IBridgeRouter(address(routerA)).getOperationStatus(
                    expectedOperationId
                )
            ),
            uint256(BridgeTypes.OperationStatus.SENT)
        );
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
            bytes32(0), // Fake operation ID
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
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
            bytes32(0), // Fake operation ID
            9999, // Unsupported chain
            address(tokenA),
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
            adapterParams
        );
    }

    function testTransferAssetUnsupportedAsset() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // vm.prank(governor);
        // routerA.registerAdapter(address(adapterA));
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            bytes32(
                0x528376a1966c744b216d0b277b4672bcda5b6ddb690dc471e2cb20923fbda502
            ),
            address(adapterA)
        );

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Should revert when transferring unsupported asset
        vm.startPrank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(StargateAdapter.UnsupportedAsset.selector)
        );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(0), // Fake operation ID
            CHAIN_ID_B,
            address(0xdead), // Unsupported asset
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
            adapterParams
        );
        vm.stopPrank();
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

        // Transfer tokens to the router and approve the adapter
        // This simulates the router having received tokens from the user
        vm.prank(user);
        tokenA.transfer(address(routerA), 1 ether);

        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calculate the operation ID that will be generated
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A, // block.chainid in the test
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
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
            expectedOperationId, // Use the expected operation ID
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
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
            bytes32(0), // Fake operation ID
            CHAIN_ID_A,
            CHAIN_ID_B,
            address(tokenA),
            bytes4(0),
            "",
            user, // keeper
            adapterParams
        );

        // Test sendMessage (unsupported)
        vm.prank(address(routerA));
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.sendMessage(
            bytes32(0), // Fake operation ID
            CHAIN_ID_B,
            recipient,
            "",
            user, // keeper
            adapterParams
        );
    }

    function testTransferAssetMsgValueConsistency() public {
        useNetworkA();
        vm.deal(address(routerA), 10 ether); // Provide enough ETH

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

        // Transfer tokens to the router and approve the adapter
        vm.prank(user);
        tokenA.transfer(address(routerA), 1 ether);
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calculate the operation ID
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
        );

        // Test with EXACTLY the required fee - should work
        vm.prank(address(routerA));
        adapterA.transferAsset{value: requiredFee}(
            expectedOperationId,
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
            adapterParams
        );

        // Setup for second transfer - need new tokens, allowance, and operation ID
        vm.prank(user);
        tokenA.transfer(address(routerA), 1 ether);
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calculate a different operation ID for the second transfer
        bytes32 expectedOperationId2 = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp + 1, // Different timestamp to get different operation ID
                block.number
            )
        );

        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId2,
            address(adapterA)
        );

        // Test with significantly MORE than required fee - should also work
        vm.prank(address(routerA));
        adapterA.transferAsset{value: requiredFee * 100}(
            expectedOperationId2,
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
            adapterParams
        );
    }

    function testTransferAssetMsgValueConsistencyEdgeCases() public {
        useNetworkA();
        vm.deal(address(routerA), 10 ether);

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Test with 1 wei less than required - should fail
        (uint256 requiredFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        vm.prank(user);
        tokenA.transfer(address(routerA), 1 ether);
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
        );

        // Test with 1 wei less - should fail
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.InsufficientFee.selector,
                requiredFee,
                requiredFee - 1
            )
        );
        adapterA.transferAsset{value: requiredFee - 1}(
            expectedOperationId,
            CHAIN_ID_B,
            address(tokenA),
            recipient,
            1 ether,
            user,
            user, // Add keeper parameter
            adapterParams
        );
    }

    // Add event declaration for the event we expect
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );
}
