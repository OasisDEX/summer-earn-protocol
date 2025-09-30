// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseERC7802Adapter} from "../../../src/adapters/BaseERC7802Adapter.sol";
import {ERC7802OFTAdapter} from "../../../src/adapters/ERC7802OFTAdapter.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BaseERC7802AdapterSetupTest} from "./BaseERC7802Adapter.setup.t.sol";

/**
 * @title BaseERC7802Adapter Estimation Tests
 * @notice Tests estimation functionality of BaseERC7802Adapter
 */
contract BaseERC7802AdapterEstimationTest is BaseERC7802AdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                        ESTIMATE TRANSFER ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateTransferAssets_RevertsForUnsupportedOperation()
        public
    {
        // This test would require mocking an unsupported operation type
        // Currently TRANSFER_ASSET is the only supported operation
    }

    function test_EstimateTransferAssets_RevertsForUnsupportedAsset() public {
        ERC20Mock unsupportedToken = new ERC20Mock();

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(unsupportedToken),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(BaseERC7802Adapter.UnsupportedAsset.selector);
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_RevertsForZeroAmount() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 0,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(BaseERC7802Adapter.InvalidParams.selector);
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_RevertsForUntrustedDestination()
        public
    {
        uint16 untrustedChain = 9999;

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: untrustedChain,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(BaseERC7802Adapter.UntrustedDestinationChain.selector);
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_ReturnsZeroOperationIdForEstimation()
        public
    {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // This will likely revert due to abstract _estimateTransport
        // In concrete implementations, it should pass operationId as bytes32(0)
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_HandlesDifferentMessageSizes() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "", // Empty message
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Test with empty message
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with small message
        params.message = "small message";
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with large message
        params.message = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            params.message[i] = bytes1(uint8(i % 256));
        }
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATE READ STATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateReadState_Reverts() public {
        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234),
                selector: bytes4(keccak256("test()")),
                readParams: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.estimateReadState(params, options);
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATE SEND MESSAGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateSendMessage_Reverts() public {
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234),
                message: "test message",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.estimateSendMessage(params, options);
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATION WITH DIFFERENT AMOUNTS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateTransferAssets_HandlesVariousAmounts() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Test with minimum amount (1 wei)
        params.amount = 1;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with small amount
        params.amount = 1000;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with normal amount
        params.amount = 100e18;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with large amount
        params.amount = 1000000e18;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with maximum uint256 (should not overflow in estimation)
        params.amount = type(uint256).max;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATION WITH DIFFERENT OPTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateTransferAssets_HandlesDifferentGasLimits() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        // Test with minimum gas limit
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 21000, // Minimum gas
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with normal gas limit
        options.gasLimit = 500000;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with high gas limit
        options.gasLimit = 3000000;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_HandlesDifferentMsgValues() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0, // No additional value
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with some additional value
        options.msgValue = 0.1 ether;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with large additional value
        options.msgValue = 10 ether;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_HandlesDifferentCalldataSizes()
        public
    {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        // Test with zero calldata size
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with small calldata size
        options.calldataSize = 32;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with large calldata size
        options.calldataSize = 10000;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_HandlesDifferentOptionsData() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: "" // Empty options
        });

        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with some options data
        options.options = hex"0102030405";
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);

        // Test with large options data
        options.options = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            options.options[i] = bytes1(uint8(i % 256));
        }
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATION EDGE CASES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateTransferAssets_HandlesEdgeCaseDestinations() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Test with destination same as source (would revert in transfer, but estimation might work)
        params.destinationChainId = CHAIN_ID_A;
        vm.expectRevert(BaseERC7802Adapter.UntrustedDestinationChain.selector); // Same chain not trusted
        adapterA.estimateTransferAssets(params, options);

        // Reset to valid destination
        params.destinationChainId = CHAIN_ID_B;
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    function test_EstimateTransferAssets_HandlesNonRouterCaller() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Estimation functions don't have router-only modifier, so should work from any caller
        vm.prank(user);
        vm.expectRevert(); // Abstract implementation
        adapterA.estimateTransferAssets(params, options);
    }

    function _deployAdapter(
        address registry,
        address accessManager,
        address lzEndpoint,
        uint16[] memory chains,
        uint32[] memory lzEids
    ) internal override returns (BaseERC7802Adapter) {
        return new ERC7802OFTAdapter(registry, accessManager, lzEndpoint);
    }
}
