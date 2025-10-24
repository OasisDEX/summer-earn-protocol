// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SuperchainAdapterSetupTest} from "./SuperchainAdapter.setup.t.sol";
import {SuperchainAdapter} from "../../../src/adapters/SuperchainAdapter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";

contract SuperchainAdapterGeneralTest is SuperchainAdapterSetupTest {
    uint16 public constant GENERAL_CHAIN_ID_A = 1;
    uint16 public constant GENERAL_CHAIN_ID_B = 2;
    uint32 public constant GENERAL_EXTERNAL_ID_B = 100;

    function setUp() public override {
        super.setUp();

        // Additional setup for general tests
        useChainA();

        // Setup chain mapping for general tests
        vm.prank(governor);
        adapterA.mapExternalId(GENERAL_CHAIN_ID_B, GENERAL_EXTERNAL_ID_B);

        // Setup peer relationship for general tests
        vm.prank(governor);
        registryA.registerRelationship(
            address(adapterA),
            address(0x999), // peer adapter
            GENERAL_CHAIN_ID_B,
            GENERAL_CHAIN_ID_B,
            registryA.PEER_RELATIONSHIP()
        );

        // Set up the registry to return the peer adapter
        vm.prank(governor);
        registryA.setAdapterPeer(
            address(adapterA),
            GENERAL_CHAIN_ID_B,
            address(0x999)
        );
    }

    function testConstructor_RevertWhenZeroSuperchainBridge() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        new SuperchainAdapter(
            address(registryA),
            address(accessManagerA),
            address(0),
            address(l2ToL2MessengerA)
        );
    }

    function testConstructor_RevertWhenZeroL2ToL2Messenger() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        new SuperchainAdapter(
            address(registryA),
            address(accessManagerA),
            address(superchainBridgeA),
            address(0)
        );
    }

    function testSupportsOperation_TransferAsset() public view {
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
    }

    function testSupportsOperation_WithAssetSupport() public {
        // Add supported asset
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), true);

        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
    }

    function testSetAssetSupport_OnlyGovernor() public {
        vm.prank(user);
        vm.expectRevert();
        adapterA.setAssetSupport(address(tokenA), true);

        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), true);
        assertTrue(adapterA.supportedAsset(address(tokenA)));
    }

    function testSetAssetSupport_RevertWhenZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidParams.selector);
        adapterA.setAssetSupport(address(0), true);
    }

    function testEstimateTransferAssets_SupportedAsset() public {
        // Add supported asset
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), true);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: GENERAL_CHAIN_ID_B,
                target: user,
                asset: address(tokenA),
                amount: 1000e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateTransferAssets(
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
                destinationChainId: GENERAL_CHAIN_ID_B,
                target: user,
                asset: address(tokenA),
                amount: 1000e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
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
        adapterA.estimateTransferAssets(params, options);
    }

    function testEstimateTransferAssets_RevertWhenZeroAmount() public {
        // Add supported asset
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), true);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: GENERAL_CHAIN_ID_B,
                target: user,
                asset: address(tokenA),
                amount: 0,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 100000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidAmount.selector);
        adapterA.estimateTransferAssets(params, options);
    }

    function testEstimateTransferAssets_RevertWhenUntrustedDestination()
        public
    {
        // Add supported asset
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), true);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: GENERAL_CHAIN_ID_A, // unmapped chain
                target: user,
                asset: address(tokenA),
                amount: 1000e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
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
                GENERAL_CHAIN_ID_A
            )
        );
        adapterA.estimateTransferAssets(params, options);
    }

    function testSupportsOperation_MessageNotSupported() public view {
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
    }

    function testRelayMessage_RevertWhenUnauthorizedCaller() public {
        // Create test parameters
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: bytes32(uint256(123)),
                originator: address(0x999),
                sourceChainId: GENERAL_CHAIN_ID_B,
                recipient: user,
                asset: address(tokenA),
                amount: 1000e18,
                message: "test message"
            });

        bytes memory message = abi.encode(params);

        // Call from unauthorized address (not L2ToL2Messenger)
        vm.prank(user);
        vm.expectRevert(IBaseBridgeAdapterErrors.Unauthorized.selector);
        adapterA.relayMessage(message);
    }
}
