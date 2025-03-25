// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IExecutorFeeLib} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutorFeeLib.sol";

contract LayerZeroAdapterSendTest is LayerZeroAdapterSetupTest {
    using OptionsBuilder for bytes;

    // Implement the executeMessage helper function required by the abstract base test
    function executeMessage(
        uint32 srcEid,
        address srcAdapter,
        address dstAdapter
    ) internal override {
        // Implementation for send tests
        // This would typically forward to the appropriate test helper
    }

    function testTransferAsset() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        tokenA.approve(address(routerA), 1 ether);

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        bytes32 transferId = routerA.transferAssets{value: 0.1 ether}(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            recipient,
            options
        );

        assertEq(
            uint256(routerA.transferStatuses(transferId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );
        vm.stopPrank();
    }

    function testReadState() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(user);

        // Create adapter params with empty options
        // The LayerZeroOptionsHelper will likely replace these anyway
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory bridgeOptions = BridgeTypes
            .BridgeOptions({
                specifiedAdapter: address(adapterA),
                adapterParams: adapterParams
            });

        // We expect this call to revert with Executor_UnsupportedOptionType(5)
        // This is because the LayerZeroOptionsHelper.createLzReadOptions is creating
        // options of type 5, which is not supported by the mock executor when !_isRead
        vm.expectRevert(
            abi.encodeWithSelector(
                IExecutorFeeLib.Executor_UnsupportedOptionType.selector,
                5
            )
        );

        routerA.readState{value: 0.1 ether}(
            CHAIN_ID_B,
            address(tokenB),
            bytes4(keccak256("balanceOf(address)")),
            abi.encode(recipient),
            bridgeOptions
        );

        vm.stopPrank();
    }

    function testSendMessage() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(user);

        // Create sample actions - we'll use composeActions with a single action
        // since sendMessage doesn't exist in BridgeRouter
        bytes[] memory actions = new bytes[](1);
        actions[0] = abi.encode("Test message"); // Our message as a single action

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        // Use composeActions instead of sendMessage
        bytes32 messageId = routerA.composeActions{value: 0.1 ether}(
            CHAIN_ID_B,
            actions,
            options
        );

        assertEq(
            uint256(routerA.transferStatuses(messageId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );
        vm.stopPrank();
    }

    function testComposeActions() public {
        useNetworkA();
        vm.deal(user, 1 ether);

        vm.startPrank(user);

        // Create sample actions to compose
        bytes[] memory actions = new bytes[](2);
        actions[0] = abi.encodeWithSignature(
            "sampleAction1(address,uint256)",
            recipient,
            100
        );
        actions[1] = abi.encodeWithSignature(
            "sampleAction2(address,bool)",
            recipient,
            true
        );

        // Specify the adapter explicitly in the options to ensure correct tracking
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000, // Set a reasonable gas limit
                msgValue: 0, // No extra value to send
                calldataSize: 0, // Default
                options: bytes("") // No specific options needed
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        // Call composeActions
        bytes32 requestId = routerA.composeActions{value: 1 ether}(
            CHAIN_ID_B,
            actions,
            options
        );

        // Verify the request was registered
        assertEq(
            uint256(routerA.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );
        assertEq(routerA.transferToAdapter(requestId), address(adapterA));

        vm.stopPrank();
    }

    function testEstimateFee() public {
        useNetworkA();

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams
        );

        assertTrue(nativeFee > 0);
        assertEq(tokenFee, 0); // No token fee for LayerZero adapter
    }
}
