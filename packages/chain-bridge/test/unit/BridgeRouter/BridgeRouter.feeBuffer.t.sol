// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {Bps, BPS_FACTOR} from "../../../src/helpers/Bps.sol";
import {BridgeOptionsTestHelper} from "../../helpers/BridgeOptionsTestHelper.sol";

// Import the event
import {BridgeRouter} from "../../../src/router/BridgeRouter.sol";

contract BridgeRouterFeeBufferTest is BridgeRouterSetup {
    /*//////////////////////////////////////////////////////////////
                            GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetFeeBufferBps_ReturnsDefaultValue() public {
        Bps bufferBps = router.getFeeBufferBps();
        assertEq(
            Bps.unwrap(bufferBps),
            100,
            "Default fee buffer should be 1% (100 bps)"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetFeeBufferBps_ByGovernor() public {
        Bps newBufferBps = Bps.wrap(200); // 2%

        vm.prank(governor);
        router.setFeeBufferBps(newBufferBps);

        Bps currentBufferBps = router.getFeeBufferBps();
        assertEq(
            Bps.unwrap(currentBufferBps),
            200,
            "Fee buffer should be updated to 2%"
        );
    }

    function testSetFeeBufferBps_ByKeeper() public {
        Bps newBufferBps = Bps.wrap(150); // 1.5%

        vm.prank(keeper);
        router.setFeeBufferBps(newBufferBps);

        Bps currentBufferBps = router.getFeeBufferBps();
        assertEq(
            Bps.unwrap(currentBufferBps),
            150,
            "Fee buffer should be updated to 1.5%"
        );
    }

    function testSetFeeBufferBps_RevertsIfBelowMinimum() public {
        Bps invalidBufferBps = Bps.wrap(50); // 0.5% - below 1% minimum

        vm.prank(governor);
        vm.expectRevert(IBridgeRouter.InvalidFeeBuffer.selector);
        router.setFeeBufferBps(invalidBufferBps);
    }

    function testSetFeeBufferBps_RevertsIfAboveMaximum() public {
        Bps invalidBufferBps = Bps.wrap(1500); // 15% - above 10% maximum

        vm.prank(governor);
        vm.expectRevert(IBridgeRouter.InvalidFeeBuffer.selector);
        router.setFeeBufferBps(invalidBufferBps);
    }

    function testSetFeeBufferBps_RevertsIfUnauthorized() public {
        Bps newBufferBps = Bps.wrap(200);

        vm.prank(user);
        vm.expectRevert();
        router.setFeeBufferBps(newBufferBps);
    }

    function testSetFeeBufferBps_EmitsEvent() public {
        Bps newBufferBps = Bps.wrap(250); // 2.5%

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IBridgeRouter.FeeBufferUpdated(100, 250);
        router.setFeeBufferBps(newBufferBps);
    }

    function testSetFeeBufferBps_AllowsMinimumValue() public {
        Bps minimumBufferBps = Bps.wrap(100); // 1% - minimum allowed

        vm.prank(governor);
        router.setFeeBufferBps(minimumBufferBps);

        Bps currentBufferBps = router.getFeeBufferBps();
        assertEq(
            Bps.unwrap(currentBufferBps),
            100,
            "Fee buffer should be set to minimum 1%"
        );
    }

    function testSetFeeBufferBps_AllowsMaximumValue() public {
        Bps maximumBufferBps = Bps.wrap(1000); // 10% - maximum allowed

        vm.prank(governor);
        router.setFeeBufferBps(maximumBufferBps);

        Bps currentBufferBps = router.getFeeBufferBps();
        assertEq(
            Bps.unwrap(currentBufferBps),
            1000,
            "Fee buffer should be set to maximum 10%"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        FEE BUFFER APPLICATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testQuoteTransferAssets_AppliesFeeBuffer() public {
        // Set custom fee buffer
        vm.prank(governor);
        router.setFeeBufferBps(Bps.wrap(200)); // 2%

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
        uint256 expectedNativeFee = (0.1 ether * (BPS_FACTOR + 200)) /
            BPS_FACTOR;
        uint256 expectedTokenFee = (0 * (BPS_FACTOR + 200)) / BPS_FACTOR;

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
        // Set custom fee buffer
        vm.prank(governor);
        router.setFeeBufferBps(Bps.wrap(300)); // 3%

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
        uint256 expectedNativeFee = (0.02 ether * (BPS_FACTOR + 300)) /
            BPS_FACTOR;
        uint256 expectedTokenFee = (0 * (BPS_FACTOR + 300)) / BPS_FACTOR;

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

    function testFeeBufferCalculation_WithDifferentValues() public {
        uint256 baseFee = 1000; // 1000 wei base fee

        // Test 1% buffer (default)
        vm.prank(governor);
        router.setFeeBufferBps(Bps.wrap(100));
        uint256 bufferedFee1 = (baseFee * (BPS_FACTOR + 100)) / BPS_FACTOR;
        assertEq(bufferedFee1, 1010, "1% buffer should add 10 wei");

        // Test 2% buffer
        vm.prank(governor);
        router.setFeeBufferBps(Bps.wrap(200));
        uint256 bufferedFee2 = (baseFee * (BPS_FACTOR + 200)) / BPS_FACTOR;
        assertEq(bufferedFee2, 1020, "2% buffer should add 20 wei");

        // Test 5% buffer
        vm.prank(governor);
        router.setFeeBufferBps(Bps.wrap(500));
        uint256 bufferedFee5 = (baseFee * (BPS_FACTOR + 500)) / BPS_FACTOR;
        assertEq(bufferedFee5, 1050, "5% buffer should add 50 wei");

        // Test 10% buffer (maximum)
        vm.prank(governor);
        router.setFeeBufferBps(Bps.wrap(1000));
        uint256 bufferedFee10 = (baseFee * (BPS_FACTOR + 1000)) / BPS_FACTOR;
        assertEq(bufferedFee10, 1100, "10% buffer should add 100 wei");
    }

    function testFeeBufferCalculation_WithZeroBaseFee() public {
        // Test that zero base fee remains zero regardless of buffer
        vm.prank(governor);
        router.setFeeBufferBps(Bps.wrap(500)); // 5% buffer

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
        router.setFeeBufferBps(Bps.wrap(1000)); // 10% buffer

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

        uint256 expectedFee = (largeFee * (BPS_FACTOR + 1000)) / BPS_FACTOR;
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
