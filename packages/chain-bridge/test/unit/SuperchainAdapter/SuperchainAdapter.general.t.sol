// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SuperchainAdapter} from "../../../src/adapters/SuperchainAdapter.sol";
import {MockCrossChainRegistry} from "../../mocks/MockCrossChainRegistry.sol";
import {MockSuperchainTokenBridge} from "../../mocks/MockSuperchainTokenBridge.sol";
import {MockL2ToL2CrossDomainMessenger} from "../../mocks/MockL2ToL2CrossDomainMessenger.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

contract SuperchainAdapterGeneralTest is Test {
    SuperchainAdapter public adapter;
    MockCrossChainRegistry public registry;
    MockSuperchainTokenBridge public superchainBridge;
    MockL2ToL2CrossDomainMessenger public l2ToL2Messenger;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public user = address(0x2);
    address public token = address(0x3);

    uint16 public constant CHAIN_ID_A = 1;
    uint16 public constant CHAIN_ID_B = 2;
    uint32 public constant EXTERNAL_ID_B = 100;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        registry = new MockCrossChainRegistry();
        superchainBridge = new MockSuperchainTokenBridge();
        l2ToL2Messenger = new MockL2ToL2CrossDomainMessenger();

        vm.prank(governor);
        adapter = new SuperchainAdapter(
            address(registry),
            address(accessManager),
            address(superchainBridge),
            address(l2ToL2Messenger)
        );

        // Setup chain mapping
        vm.prank(governor);
        adapter.mapExternalId(CHAIN_ID_B, EXTERNAL_ID_B);

        // Setup peer relationship
        vm.prank(governor);
        registry.registerRelationship(
            address(adapter),
            address(0x999), // peer adapter
            CHAIN_ID_B,
            CHAIN_ID_B,
            registry.PEER_RELATIONSHIP()
        );

        // Set up the registry to return the peer adapter
        vm.prank(governor);
        registry.setAdapterPeer(address(adapter), CHAIN_ID_B, address(0x999));
    }

    function testConstructor_RevertWhenZeroSuperchainBridge() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        new SuperchainAdapter(
            address(registry),
            address(accessManager),
            address(0),
            address(l2ToL2Messenger)
        );
    }

    function testConstructor_RevertWhenZeroL2ToL2Messenger() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        new SuperchainAdapter(
            address(registry),
            address(accessManager),
            address(superchainBridge),
            address(0)
        );
    }

    function testSupportsOperation_TransferAsset() public view {
        assertTrue(
            adapter.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertFalse(
            adapter.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
    }

    function testSupportsAssetTransfer_SupportedAsset() public {
        // Add supported asset
        vm.prank(governor);
        adapter.setAssetSupport(token, true);

        assertTrue(adapter.supportsAssetTransfer(CHAIN_ID_B, token));
        assertFalse(adapter.supportsAssetTransfer(CHAIN_ID_B, address(0x4))); // unsupported asset
        assertFalse(adapter.supportsAssetTransfer(CHAIN_ID_A, token)); // unsupported chain
    }

    function testSetAssetSupport_OnlyGovernor() public {
        vm.prank(user);
        vm.expectRevert();
        adapter.setAssetSupport(token, true);

        vm.prank(governor);
        adapter.setAssetSupport(token, true);
        assertTrue(adapter.supportedAsset(token));
    }

    function testSetAssetSupport_RevertWhenZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        adapter.setAssetSupport(address(0), true);
    }

    function testEstimateTransferAssets_SupportedAsset() public {
        // Add supported asset
        vm.prank(governor);
        adapter.setAssetSupport(token, true);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: user,
                asset: token,
                amount: 1000e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        (uint256 nativeFee, uint256 tokenFee) = adapter.estimateTransferAssets(
            params,
            options
        );
        assertEq(nativeFee, 0); // Superchain bridge transfers are free
        assertEq(tokenFee, 0);
    }

    function testEstimateTransferAssets_RevertWhenUnsupportedAsset() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: user,
                asset: token,
                amount: 1000e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        adapter.estimateTransferAssets(params, options);
    }

    function testEstimateTransferAssets_RevertWhenZeroAmount() public {
        // Add supported asset
        vm.prank(governor);
        adapter.setAssetSupport(token, true);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: user,
                asset: token,
                amount: 0,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidAmount.selector);
        adapter.estimateTransferAssets(params, options);
    }

    function testEstimateTransferAssets_RevertWhenUntrustedDestination()
        public
    {
        // Add supported asset
        vm.prank(governor);
        adapter.setAssetSupport(token, true);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_A, // unmapped chain
                target: user,
                asset: token,
                amount: 1000e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedDestinationChain.selector,
                CHAIN_ID_A
            )
        );
        adapter.estimateTransferAssets(params, options);
    }

    function testSupportsMessageOperation_OnlyTransferAsset() public view {
        assertTrue(
            adapter.supportsMessageOperation(
                CHAIN_ID_B,
                BridgeTypes.OperationType.TRANSFER_ASSET
            )
        );
        assertFalse(
            adapter.supportsMessageOperation(
                CHAIN_ID_B,
                BridgeTypes.OperationType.MESSAGE
            )
        );
    }

    function testEstimateSendMessage_Reverts() public {
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: user,
                message: "test",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.OperationNotSupported.selector
            )
        );
        adapter.estimateSendMessage(params, options);
    }

    function testSendMessage_Reverts() public {
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: user,
                message: "test",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.OperationNotSupported.selector
            )
        );
        adapter.sendMessage(bytes32(0), params, options);
    }

    function testRelayMessage_RevertWhenUnauthorizedCaller() public {
        // Create test parameters
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: bytes32(uint256(123)),
                originator: address(0x999),
                sourceChainId: CHAIN_ID_B,
                recipient: user,
                asset: token,
                amount: 1000e18,
                message: "test message"
            });

        bytes memory message = abi.encode(params);

        // Call from unauthorized address (not L2ToL2Messenger)
        vm.prank(user);
        vm.expectRevert(IBaseBridgeAdapterErrors.Unauthorized.selector);
        adapter.relayMessage(message);
    }
}
