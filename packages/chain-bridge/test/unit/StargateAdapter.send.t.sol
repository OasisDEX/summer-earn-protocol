// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IStargateRouter} from "../../src/interfaces/IStargateRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";

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
            adapterParams
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
        vm.expectRevert(StargateAdapter.UnsupportedChain.selector);
        adapterA.estimateFee(
            9999, // Unsupported chain
            address(tokenA),
            1 ether,
            adapterParams
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
        vm.expectRevert(StargateAdapter.UnsupportedAsset.selector);
        adapterA.estimateFee(
            CHAIN_ID_B,
            address(0xdead), // Unsupported asset
            1 ether,
            adapterParams
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
            adapterParams
        );

        // Approve tokens for the adapter
        vm.prank(user);
        tokenA.approve(address(adapterA), 1 ether);

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
        vm.expectRevert(StargateAdapter.Unauthorized.selector);
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
        vm.expectRevert(StargateAdapter.UnsupportedChain.selector);
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
        vm.expectRevert(StargateAdapter.UnsupportedAsset.selector);
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
            adapterParams
        );

        // Try to transfer with insufficient fee (half of required)
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                StargateAdapter.InsufficientFee.selector,
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
        vm.expectRevert(StargateAdapter.OperationNotSupported.selector);
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
        vm.expectRevert(StargateAdapter.OperationNotSupported.selector);
        adapterA.sendMessage(CHAIN_ID_B, recipient, "", user, adapterParams);
    }
}
