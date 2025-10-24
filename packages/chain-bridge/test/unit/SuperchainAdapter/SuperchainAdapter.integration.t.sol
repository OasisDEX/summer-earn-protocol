// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SuperchainAdapterSetupTest} from "./SuperchainAdapter.setup.t.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {BridgeMessagingHelper} from "../../../src/libraries/BridgeMessagingHelper.sol";

contract SuperchainAdapterIntegrationTest is SuperchainAdapterSetupTest {
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );

    event ERC20Sent(
        address indexed token,
        uint32 indexed destinationChainId,
        address indexed recipient,
        uint256 amount
    );

    function testFullTransferCycle() public {
        uint256 transferAmount = 1000e18;
        bytes32 operationId = keccak256("integration-test-operation");

        // Step 1: Execute transfer on Chain A
        useChainA();

        // Fund router and approve adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Expect events from transfer
        vm.expectEmit(true, true, true, true);
        emit TransferInitiated(
            operationId,
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient
        );

        vm.expectEmit(true, true, true, true);
        emit ERC20Sent(
            address(tokenA),
            EXTERNAL_ID_B,
            address(adapterB),
            transferAmount
        );

        // Execute transfer
        vm.prank(address(routerA));
        adapterA.transferAsset(operationId, params, options);

        // Verify transfer state on Chain A
        assertEq(tokenA.balanceOf(address(adapterA)), transferAmount);
        assertEq(tokenA.balanceOf(address(routerA)), 0);

        // Step 2: Simulate cross-chain message delivery and relay on Chain B
        useChainB();

        // Create the relayed transfer parameters that would be sent
        BridgeTypes.RelayedTransferParams memory relayParams = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: ""
            });

        bytes memory relayMessage = BridgeMessagingHelper
            .encodeRelayedTransferParams(relayParams);

        // Set up cross-domain context
        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        // Mint tokens to adapter (simulating tokens received from Superchain bridge)
        tokenB.mint(address(adapterB), transferAmount);

        // Mock the router deliver call
        vm.mockCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, relayMessage)
            ),
            abi.encode()
        );

        // Execute relay
        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(relayMessage);

        // Verify final state on Chain B
        assertEq(tokenB.balanceOf(address(routerB)), transferAmount);
        assertEq(tokenB.balanceOf(address(adapterB)), 0);

        // Verify router.deliver was called
        vm.expectCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, relayMessage)
            )
        );
    }

    function testCrossChainRegistryIntegration() public {
        useChainA();

        // Verify adapter A can resolve peer adapter for Chain B
        address peerAdapter = adapterA.CROSS_CHAIN_REGISTRY().getAdapterPeer(
            address(adapterA),
            CHAIN_ID_B
        );
        assertEq(peerAdapter, address(adapterB));

        // Verify adapter B can resolve peer adapter for Chain A
        useChainB();
        address peerAdapterB = adapterB.CROSS_CHAIN_REGISTRY().getAdapterPeer(
            address(adapterB),
            CHAIN_ID_A
        );
        assertEq(peerAdapterB, address(adapterA));
    }

    function testAccessControlIntegration() public {
        useChainA();

        // Test that only governor can set asset support
        vm.prank(user);
        vm.expectRevert();
        adapterA.setAssetSupport(address(tokenA), true);

        // Test that governor can set asset support
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), true);
        assertTrue(adapterA.supportedAsset(address(tokenA)));

        // Test that only governor can map external IDs
        vm.prank(user);
        vm.expectRevert();
        adapterA.mapExternalId(999, 999);

        // Test that governor can map external IDs
        vm.prank(governor);
        adapterA.mapExternalId(999, 999);
        assertEq(adapterA.chainToExternalId(999), 999);
    }

    function testMultiChainAssetSupport() public {
        // Test asset support on both chains
        useChainA();
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), true);
        assertTrue(adapterA.supportedAsset(address(tokenA)));

        useChainB();
        vm.prank(governor);
        adapterB.setAssetSupport(address(tokenB), true);
        assertTrue(adapterB.supportedAsset(address(tokenB)));

        // Test that assets are not cross-chain supported by default
        useChainA();
        assertFalse(adapterA.supportedAsset(address(tokenB)));

        useChainB();
        assertFalse(adapterB.supportedAsset(address(tokenA)));
    }

    function testEstimateTransferAssetsIntegration() public {
        useChainA();

        uint256 transferAmount = 1000e18;

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Test estimation
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateTransferAssets(
            params,
            options
        );

        // Superchain bridge transfers are free
        assertEq(nativeFee, 0);
        assertEq(tokenFee, 0);
    }

    function testSupportsOperationIntegration() public {
        useChainA();

        // Test that adapter supports TRANSFER_ASSET
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );

        // Test that adapter does not support MESSAGE
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );

        useChainB();

        // Test same on Chain B
        assertTrue(
            adapterB.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertFalse(
            adapterB.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
    }

    function testConcurrentTransfers() public {
        uint256 transferAmount = 1000e18;
        bytes32 operationId1 = keccak256("concurrent-1");
        bytes32 operationId2 = keccak256("concurrent-2");

        // Execute two transfers on Chain A
        useChainA();

        // First transfer
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params1 = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        vm.prank(address(routerA));
        adapterA.transferAsset(operationId1, params1, options);

        // Second transfer
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params2 = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        vm.prank(address(routerA));
        adapterA.transferAsset(operationId2, params2, options);

        // Verify both transfers completed
        assertEq(tokenA.balanceOf(address(adapterA)), transferAmount * 2);

        // Simulate relay of both messages on Chain B
        useChainB();

        // First relay
        BridgeTypes.RelayedTransferParams memory relayParams1 = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId1,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: ""
            });

        bytes memory relayMessage1 = BridgeMessagingHelper
            .encodeRelayedTransferParams(relayParams1);

        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        tokenB.mint(address(adapterB), transferAmount);

        vm.mockCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, relayMessage1)
            ),
            abi.encode()
        );

        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(relayMessage1);

        // Second relay
        BridgeTypes.RelayedTransferParams memory relayParams2 = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId2,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: ""
            });

        bytes memory relayMessage2 = BridgeMessagingHelper
            .encodeRelayedTransferParams(relayParams2);

        tokenB.mint(address(adapterB), transferAmount);

        vm.mockCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, relayMessage2)
            ),
            abi.encode()
        );

        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(relayMessage2);

        // Verify both relays completed
        assertEq(tokenB.balanceOf(address(routerB)), transferAmount * 2);
        assertEq(tokenB.balanceOf(address(adapterB)), 0);
    }

    function testErrorHandlingIntegration() public {
        useChainA();

        // Test unsupported asset
        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(0x999), // Unsupported asset
            1000e18,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        adapterA.transferAsset(keccak256("test"), params, options);

        // Test unsupported chain
        params = createTransferParams(
            9999, // Unsupported chain
            address(tokenA),
            1000e18,
            recipient,
            user,
            user
        );

        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedDestinationChain.selector,
                9999
            )
        );
        adapterA.transferAsset(keccak256("test"), params, options);
    }
}
