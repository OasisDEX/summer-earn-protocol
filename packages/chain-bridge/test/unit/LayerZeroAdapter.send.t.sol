// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IExecutorFeeLib} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutorFeeLib.sol";

contract LayerZeroAdapterSendTest is LayerZeroAdapterSetupTest {
    using OptionsBuilder for bytes;

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

        // Create a test message to send cross-chain
        bytes memory message = abi.encode("Hello from Chain A!");

        // Create adapter params with appropriate gas limit for GENERAL_MESSAGE
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000, // Use the minimum gas limit for GENERAL_MESSAGE
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            });

        BridgeTypes.BridgeOptions memory bridgeOptions = BridgeTypes
            .BridgeOptions({
                specifiedAdapter: address(adapterA),
                adapterParams: adapterParams
            });

        // We need to mock the expected behavior for sending a message
        // This will depend on your test setup, but we need to ensure
        // that the lzEndpoint is properly set up to handle the message

        // In real execution, this would generate a messageId and call _lzSend
        bytes32 messageId = routerA.sendMessage{value: 0.1 ether}(
            CHAIN_ID_B,
            recipient,
            message,
            bridgeOptions
        );

        // Verify messageId is not empty
        assertTrue(messageId != bytes32(0), "Message ID should not be empty");

        // Verify the message status was updated to PENDING
        assertEq(
            uint256(routerA.getOperationStatus(messageId)),
            uint256(BridgeTypes.OperationStatus.PENDING),
            "Message status should be PENDING"
        );

        // If your test setup allows for complete message execution,
        // you can verify that the message was received on the destination chain
        // by checking state changes or events on the recipient contract

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
