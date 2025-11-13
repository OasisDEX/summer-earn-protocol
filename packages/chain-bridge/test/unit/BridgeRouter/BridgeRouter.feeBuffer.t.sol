// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {Bps, toBps, fromBps} from "../../../src/helpers/Bps.sol";
import {BpsUtils} from "../../../src/helpers/BpsUtils.sol";
import {BridgeOptionsTestHelper} from "../../helpers/BridgeOptionsTestHelper.sol";

contract BridgeRouterFeeBufferTest is BridgeRouterSetup {
    /*//////////////////////////////////////////////////////////////
                            GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetFeeBufferBps_ReturnsDefaultValue() public {
        Bps bufferBps = router.getFeeBufferBps();
        assertEq(
            fromBps(bufferBps),
            fromBps(BpsUtils.fromIntegerBPS(100)),
            "Default fee buffer should be 1% (100 bps)"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetFeeBufferBps_ByGovernor() public {
        Bps newBufferBps = BpsUtils.fromIntegerBPS(200); // 2%

        vm.prank(governor);
        router.setFeeBufferBps(newBufferBps);

        Bps currentBufferBps = router.getFeeBufferBps();
        assertEq(
            fromBps(currentBufferBps),
            fromBps(newBufferBps),
            "Fee buffer should be updated to 2%"
        );
    }

    function testSetFeeBufferBps_ByKeeper_Reverts() public {
        Bps newBufferBps = toBps(150); // 1.5%

        vm.prank(keeper);
        vm.expectRevert();
        router.setFeeBufferBps(newBufferBps);
    }

    function testSetFeeBufferBps_RevertsIfBelowMinimum() public {
        Bps invalidBufferBps = toBps(50); // 0.5% - below 1% minimum

        vm.prank(governor);
        vm.expectRevert(IBridgeRouter.InvalidFeeBuffer.selector);
        router.setFeeBufferBps(invalidBufferBps);
    }

    function testSetFeeBufferBps_RevertsIfAboveMaximum() public {
        Bps invalidBufferBps = toBps(1500); // 15% - above 10% maximum

        vm.prank(governor);
        vm.expectRevert(IBridgeRouter.InvalidFeeBuffer.selector);
        router.setFeeBufferBps(invalidBufferBps);
    }

    function testSetFeeBufferBps_RevertsIfUnauthorized() public {
        Bps newBufferBps = toBps(200);

        vm.prank(user);
        vm.expectRevert();
        router.setFeeBufferBps(newBufferBps);
    }

    function testSetFeeBufferBps_EmitsEvent() public {
        Bps initialBufferBps = router.getFeeBufferBps();

        Bps newBufferBps = BpsUtils.fromIntegerBPS(250); // 2.5%

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IBridgeRouter.FeeBufferUpdated(
            fromBps(initialBufferBps),
            fromBps(newBufferBps)
        );
        router.setFeeBufferBps(newBufferBps);
    }

    function testSetFeeBufferBps_AllowsMinimumValue() public {
        Bps minimumBufferBps = BpsUtils.fromIntegerBPS(100); // 1% - minimum allowed

        vm.prank(governor);
        router.setFeeBufferBps(minimumBufferBps);

        Bps currentBufferBps = router.getFeeBufferBps();
        assertEq(
            fromBps(currentBufferBps),
            fromBps(minimumBufferBps),
            "Fee buffer should be set to minimum 1%"
        );
    }

    function testSetFeeBufferBps_AllowsMaximumValue() public {
        Bps maximumBufferBps = BpsUtils.fromIntegerBPS(1000); // 10% - maximum allowed

        vm.prank(governor);
        router.setFeeBufferBps(maximumBufferBps);

        Bps currentBufferBps = router.getFeeBufferBps();
        assertEq(
            fromBps(currentBufferBps),
            fromBps(maximumBufferBps),
            "Fee buffer should be set to maximum 10%"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        FEE BUFFER APPLICATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testQuoteTransferAssets_AppliesFeeBuffer() public {
        Bps bufferFee = BpsUtils.fromIntegerBPS(200);

        // Set custom fee buffer
        vm.prank(governor);
        router.setFeeBufferBps(bufferFee);

        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .defaultOptions(address(mockAdapter));

        // Get quote with custom buffer
        (uint256 nativeFee, uint256 tokenFee, ) = router.quoteTransferAssets(
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

        // MockAdapter returns 0.1 ether base fee
        uint256 expectedNativeFee = BpsUtils.addBps(0.1 ether, bufferFee);
        uint256 expectedTokenFee = BpsUtils.addBps(0, bufferFee);

        assertEq(
            nativeFee,
            expectedNativeFee,
            "Native fee should have 2% buffer applied"
        );
        assertEq(
            tokenFee,
            expectedTokenFee,
            "Token fee should have 2% buffer applied"
        );
    }

    function testQuoteSendMessage_AppliesFeeBuffer() public {
        Bps bufferFee = BpsUtils.fromIntegerBPS(300);

        // Set custom fee buffer
        vm.prank(governor);
        router.setFeeBufferBps(bufferFee); // 3%

        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .defaultOptions(address(mockAdapter));

        // Get quote with custom buffer
        (uint256 nativeFee, uint256 tokenFee, ) = router.quoteSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                originator: user,
                destinationChainId: DEST_CHAIN_ID,
                target: recipient,
                message: "test message",
                refundAddress: user
            }),
            options
        );

        // MockAdapter returns 0.02 ether base fee for messages
        uint256 expectedNativeFee = BpsUtils.addBps(0.02 ether, bufferFee);
        uint256 expectedTokenFee = BpsUtils.addBps(0, bufferFee);

        assertEq(
            nativeFee,
            expectedNativeFee,
            "Native fee should have 3% buffer applied"
        );
        assertEq(
            tokenFee,
            expectedTokenFee,
            "Token fee should have 3% buffer applied"
        );
    }

    function testFeeBufferCalculation_SetFee() public {
        uint256 baseFee = 1000; // 1000 wei base fee
        Bps initialBps = BpsUtils.fromIntegerBPS(100); // 1%

        assertEq(
            fromBps(router.getFeeBufferBps()),
            fromBps(initialBps),
            "Initial buffer should be 1%"
        );

        Bps newBps = BpsUtils.fromIntegerBPS(1000); // 10%

        vm.expectEmit(true, true, true, true);
        emit IBridgeRouter.FeeBufferUpdated(
            fromBps(initialBps),
            fromBps(newBps)
        );

        vm.prank(governor);
        router.setFeeBufferBps(newBps);
    }

    function testFeeBufferCalculation_WithZeroBaseFee() public {
        // Test that zero base fee remains zero regardless of buffer
        vm.prank(governor);
        router.setFeeBufferBps(BpsUtils.fromIntegerBPS(500)); // 5% buffer

        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .defaultOptions(address(mockAdapter));

        // Mock adapter to return zero fees
        vm.mockCall(
            address(mockAdapter),
            abi.encodeWithSelector(mockAdapter.estimateTransferAssets.selector),
            abi.encode(0, 0) // Zero fees
        );

        (uint256 nativeFee, uint256 tokenFee, ) = router.quoteTransferAssets(
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

        assertEq(nativeFee, 0, "Zero base fee should remain zero");
        assertEq(tokenFee, 0, "Zero base fee should remain zero");
    }

    function testFeeBufferCalculation_WithLargeBaseFee() public {
        // Test with large base fee to ensure no overflow
        vm.prank(governor);
        router.setFeeBufferBps(BpsUtils.fromIntegerBPS(1000)); // 10% buffer

        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .defaultOptions(address(mockAdapter));

        // Mock adapter to return large fees
        uint256 largeFee = 1e18; // 1 ETH
        vm.mockCall(
            address(mockAdapter),
            abi.encodeWithSelector(mockAdapter.estimateTransferAssets.selector),
            abi.encode(largeFee, largeFee)
        );

        (uint256 nativeFee, uint256 tokenFee, ) = router.quoteTransferAssets(
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

        uint256 expectedFee = BpsUtils.addBps(
            largeFee,
            BpsUtils.fromIntegerBPS(1000)
        );
        assertEq(
            nativeFee,
            expectedFee,
            "Large base fee should be buffered correctly"
        );
        assertEq(
            tokenFee,
            expectedFee,
            "Large base fee should be buffered correctly"
        );
    }
}
