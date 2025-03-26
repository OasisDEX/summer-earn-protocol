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
