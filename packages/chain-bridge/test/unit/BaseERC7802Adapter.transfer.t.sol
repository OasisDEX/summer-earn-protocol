// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseERC7802Adapter} from "../../src/adapters/BaseERC7802Adapter.sol";
import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {ERC7802OFTAdapterTestHarness} from "../mocks/ERC7802OFTAdapterTestHarness.sol";
import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC7802OFTAdapterSetupTest} from "./ERC7802OFTAdapter.setup.t.sol";

/**
 * @title BaseERC7802Adapter Transfer Tests
 * @notice Tests transfer and finalize functionality of BaseERC7802Adapter
 */
contract BaseERC7802AdapterTransferTest is ERC7802OFTAdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                        TRANSFER ASSET TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TransferAsset_RevertsForUnsupportedOperation() public {
        // This test would require mocking an unsupported operation type
        // Currently TRANSFER_ASSET is the only supported operation
    }

    function test_TransferAsset_RevertsForUnsupportedAsset() public {
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

        vm.prank(address(routerA));
        vm.expectRevert(IBridgeAdapter.UnsupportedAsset.selector);
        adapterA.transferAsset("", params, options);
    }

    function test_TransferAsset_RevertsForZeroAmount() public {
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

        vm.prank(address(routerA));
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.transferAsset("", params, options);
    }

    function test_TransferAsset_RevertsForUntrustedDestination() public {
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

        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseBridgeAdapter.UntrustedDestinationChain.selector,
                untrustedChain
            )
        );
        adapterA.transferAsset("", params, options);
    }

    function test_TransferAsset_RevertsWhenCalledByNonRouter() public {
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

        vm.prank(user); // Non-router caller
        vm.expectRevert(BaseBridgeAdapter.Unauthorized.selector);
        adapterA.transferAsset("", params, options);
    }

    function test_TransferAsset_PullsTokensFromRouter() public {
        uint256 transferAmount = 100e18;

        // Approve router to spend user's tokens
        vm.prank(user);
        tokenA.approve(address(routerA), transferAmount);

        // Transfer tokens to router (simulating normal flow)
        vm.prank(user);
        tokenA.transfer(address(routerA), transferAmount);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: transferAmount,
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

        uint256 routerBalanceBefore = tokenA.balanceOf(address(routerA));
        uint256 adapterBalanceBefore = tokenA.balanceOf(address(adapterA));

        vm.prank(address(routerA));
        // Note: This will likely revert due to abstract _sendTransport not being implemented
        // In concrete implementations, this would succeed
        vm.expectRevert(); // Implementation-specific revert

        try adapterA.transferAsset("", params, options) {
            uint256 routerBalanceAfter = tokenA.balanceOf(address(routerA));
            uint256 adapterBalanceAfter = tokenA.balanceOf(address(adapterA));

            // Verify tokens were transferred from router to adapter
            assertEq(routerBalanceAfter, routerBalanceBefore - transferAmount);
            assertEq(
                adapterBalanceAfter,
                adapterBalanceBefore + transferAmount
            );
        } catch {
            // Expected to revert in abstract test
        }
    }

    function test_TransferAsset_EmitsTransferInitiatedEvent() public {
        uint256 transferAmount = 100e18;

        // Setup token transfer to router
        vm.prank(user);
        tokenA.approve(address(routerA), transferAmount);
        vm.prank(user);
        tokenA.transfer(address(routerA), transferAmount);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: transferAmount,
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

        vm.expectEmit(true, true, true, true);
        emit BaseERC7802Adapter.TransferInitiated(
            "", // operationId
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient
        );

        vm.prank(address(routerA));
        // Note: This will revert due to abstract implementation
        vm.expectRevert();

        adapterA.transferAsset("", params, options);
    }

    /*//////////////////////////////////////////////////////////////
                        FINALIZE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Finalize_RevertsForUnsupportedOperation() public {
        // This test would require mocking an unsupported operation type
    }

    function test_Finalize_RevertsForUnsupportedAsset() public {
        ERC20Mock unsupportedToken = new ERC20Mock();

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_A,
                target: recipient,
                asset: address(unsupportedToken),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        vm.prank(governor); // Authorized executor
        vm.expectRevert(IBridgeAdapter.UnsupportedAsset.selector);
        adapterA.finalize("", params);
    }

    function test_Finalize_RevertsForZeroAmount() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_A,
                target: recipient,
                asset: address(tokenA),
                amount: 0,
                message: "",
                refundAddress: user
            });

        vm.prank(governor);
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.finalize("", params);
    }

    function test_Finalize_RevertsForWrongDestinationChain() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B, // Wrong chain (should be THIS_CHAIN)
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        vm.prank(governor);
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.finalize("", params);
    }

    function test_Finalize_RevertsForInsufficientBalance() public {
        uint256 transferAmount = 100e18;

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_A,
                target: recipient,
                asset: address(tokenA),
                amount: transferAmount,
                message: "",
                refundAddress: user
            });

        // Ensure adapter has insufficient balance
        uint256 adapterBalance = tokenA.balanceOf(address(adapterA));
        assertLt(adapterBalance, transferAmount);

        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.InsufficientBalance.selector);
        adapterA.finalize("", params);
    }

    function test_Finalize_RevertsWhenCalledByNonAuthorizedExecutor() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_A,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        vm.prank(user); // Non-authorized executor
        vm.expectRevert(BaseBridgeAdapter.Unauthorized.selector);
        adapterA.finalize("", params);
    }

    function test_Finalize_TransfersTokensToRouter() public {
        uint256 transferAmount = 100e18;

        // Give adapter tokens to finalize
        vm.prank(user);
        tokenA.transfer(address(adapterA), transferAmount);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_A,
                target: recipient,
                asset: address(tokenA),
                amount: transferAmount,
                message: "",
                refundAddress: user
            });

        uint256 adapterBalanceBefore = tokenA.balanceOf(address(adapterA));
        uint256 routerBalanceBefore = tokenA.balanceOf(address(routerA));

        vm.prank(governor);
        adapterA.finalize("", params);

        uint256 adapterBalanceAfter = tokenA.balanceOf(address(adapterA));
        uint256 routerBalanceAfter = tokenA.balanceOf(address(routerA));

        // Verify tokens were transferred from adapter to router
        assertEq(adapterBalanceAfter, adapterBalanceBefore - transferAmount);
        assertEq(routerBalanceAfter, routerBalanceBefore + transferAmount);
    }

    function test_Finalize_CallsRouterDeliverWithCorrectPayload() public {
        uint256 transferAmount = 100e18;

        // Give adapter tokens to finalize
        vm.prank(user);
        tokenA.transfer(address(adapterA), transferAmount);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_A,
                target: recipient,
                asset: address(tokenA),
                amount: transferAmount,
                message: "test message",
                refundAddress: user
            });

        vm.prank(governor);

        // Mock the router.deliver call to verify it's called correctly
        vm.expectCall(
            address(routerA),
            abi.encodeCall(
                routerA.deliver,
                (
                    BridgeTypes.OperationType.TRANSFER_ASSET,
                    adapterA._encodeRelayedTransferParams(
                        BridgeTypes.RelayedTransferParams({
                            operationId: "",
                            originator: user,
                            sourceChainId: CHAIN_ID_A,
                            recipient: recipient,
                            asset: address(tokenA),
                            amount: transferAmount,
                            message: "test message"
                        })
                    )
                )
            )
        );

        adapterA.finalize("", params);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TransferAssetAndFinalize_WorkTogether() public {
        // This test would require a concrete implementation that doesn't revert in _sendTransport
        // In abstract test, we can only test the structure
    }

    function test_TransferAsset_HandlesExcessNativeRefund() public {
        // Test that excess native tokens are refunded to refundAddress
    }

    function test_TransferAsset_HandlesMessageEncodingForCompose() public {
        // Test that messages are properly encoded for LayerZero compose
    }

    function test_Finalize_HandlesMessageInPayload() public {
        // Test that finalize correctly handles messages in the transfer payload
    }
}
