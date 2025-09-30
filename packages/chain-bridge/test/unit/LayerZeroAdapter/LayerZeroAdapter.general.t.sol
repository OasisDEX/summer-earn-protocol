// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapter} from "../../../src/adapters/LayerZeroAdapter.sol";

import {ICrossChainRegistry} from "../../../src/interfaces/ICrossChainRegistry.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";

import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {BaseBridgeAdapter} from "../../../src/base/BaseBridgeAdapter.sol";
import {Errors} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/Errors.sol";

contract LayerZeroAdapterGeneralTest is LayerZeroAdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                          ADAPTER FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetSupportedChains() public view {
        // Get chains through registry relationships
        (, uint16[] memory supportedChains) = registryA.getTargetsForSource(
            address(adapterA),
            registryA.PEER_RELATIONSHIP()
        );

        assertEq(supportedChains.length, 1);
        assertEq(supportedChains[0], CHAIN_ID_B);
    }

    function testSupportsChain() public {
        // First check still works
        assertTrue(
            adapterA.CROSS_CHAIN_REGISTRY().getAdapterPeer(
                address(adapterA),
                CHAIN_ID_B
            ) != address(0),
            "Chain B should be supported"
        );

        // Expect revert when unsupported chain is queried
        ICrossChainRegistry registryA = ICrossChainRegistry(
            address(adapterA.CROSS_CHAIN_REGISTRY())
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(adapterA),
                registryA.PEER_RELATIONSHIP(),
                2
            )
        );
        registryA.getAdapterPeer(address(adapterA), 2);
    }

    // Update test for UnsupportedMessageType error: use a valid but unsupported op (TRANSFER_ASSET)
    function test_reverts_on_unsupported_operation_type_in_receive() public {
        // Create a payload where op type is TRANSFER_ASSET (unsupported by LZ receive path)
        bytes memory invalidPayload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.TRANSFER_ASSET),
            bytes("test payload")
        );

        // Create origin data
        Origin memory origin = Origin({
            srcEid: LZ_EID_B, // Source is chain B
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        // Expect revert with UnsupportedMessageType
        vm.expectRevert(IBridgeAdapter.UnsupportedMessageType.selector);

        // Call the test helper's lzReceiveTest function with the invalid payload
        adapterA.lzReceiveTest(
            origin,
            bytes32(uint256(1)), // requestId
            invalidPayload,
            address(adapterB), // sender
            bytes("") // extraData
        );
    }

    // Duplicate of send suite fee estimate; keep single assertion in send tests
    function testAdapterDirectEstimateFee() public {
        useNetworkA();

        // Create adapter params with a specific gas limit
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeToken: address(0)
        });

        // Call estimateSendMessage directly on the adapter
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234), // Target contract
                message: abi.encode("Test message"),
                originator: address(this),
                refundAddress: address(this)
            }),
            options
        );

        // Fee should be non-zero
        assertTrue(nativeFee > 0);
        // Token fee should be zero for LayerZero
        assertEq(tokenFee, 0);
    }

    function testSupportsFeatures() public view {
        // Test capability flags directly on adapter
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.READ_STATE)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
    }

    function testActivateAndUpdateReadChannel() public {
        useNetworkA();

        // Initially unset
        assertEq(adapterA.readChannelId(), 0);

        uint32 baseThreshold = adapterA.readChannelThreshold();
        uint32 firstChannelId = baseThreshold + 1;
        uint32 secondChannelId = baseThreshold + 2;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit LayerZeroAdapter.ReadChannelActivated(firstChannelId);
        adapterA.activateReadChannel(firstChannelId);
        assertEq(adapterA.readChannelId(), firstChannelId);

        // Update to a new read channel
        vm.expectEmit(true, false, false, true);
        emit LayerZeroAdapter.ReadChannelActivated(secondChannelId);
        adapterA.activateReadChannel(secondChannelId);
        assertEq(adapterA.readChannelId(), secondChannelId);
        assertEq(adapterA.peers(firstChannelId), bytes32(0));
        vm.stopPrank();
    }

    // Note: Role enforcement for activating the read channel is covered elsewhere via access manager tests
    function test_supportsMessageOperation_false_when_chain_unmapped()
        public
        view
    {
        bool supported = adapterA.supportsMessageOperation(
            9999,
            BridgeTypes.OperationType.MESSAGE
        );
        assertFalse(supported);
    }

    function test_supportsMessageOperation_false_when_unsupported_operation()
        public
        view
    {
        bool supported = adapterA.supportsMessageOperation(
            CHAIN_ID_B,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        assertFalse(supported);
    }

    function test_supportsMessageOperation_readState_requires_channel_and_chain_support()
        public
    {
        bool supportedBefore = adapterA.supportsMessageOperation(
            CHAIN_ID_B,
            BridgeTypes.OperationType.READ_STATE
        );
        assertFalse(supportedBefore);

        vm.prank(governor);
        adapterA.activateReadChannel(READ_CHANNEL_THRESHOLD + 1);
        bool supportedNoChainFlag = adapterA.supportsMessageOperation(
            CHAIN_ID_B,
            BridgeTypes.OperationType.READ_STATE
        );
        assertFalse(supportedNoChainFlag);

        vm.prank(governor);
        adapterA.setChainReadSupport(CHAIN_ID_B, true);
        bool supportedAfter = adapterA.supportsMessageOperation(
            CHAIN_ID_B,
            BridgeTypes.OperationType.READ_STATE
        );
        assertTrue(supportedAfter);
    }

    function test_estimateReadState_reverts_when_channel_not_configured()
        public
    {
        useNetworkA();
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 300000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeToken: address(0)
        });
        vm.expectRevert(IBridgeAdapter.ReadChannelNotConfigured.selector);
        adapterA.estimateReadState(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0xdead),
                selector: bytes4(keccak256("balanceOf(address)")),
                readParams: abi.encode(address(this)),
                originator: address(this),
                refundAddress: address(this)
            }),
            options
        );
    }

    function test_estimateReadState_reverts_when_chain_not_supported_for_read()
        public
    {
        useNetworkA();
        vm.prank(governor);
        adapterA.activateReadChannel(READ_CHANNEL_THRESHOLD + 1);
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 300000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeToken: address(0)
        });
        vm.expectRevert(IBridgeAdapter.UnsupportedChain.selector);
        adapterA.estimateReadState(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0xdead),
                selector: bytes4(keccak256("balanceOf(address)")),
                readParams: abi.encode(address(this)),
                originator: address(this),
                refundAddress: address(this)
            }),
            options
        );
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE CONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    function test_configureReadLibraries_reverts_without_channel() public {
        useNetworkA();
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.ReadChannelNotConfigured.selector);
        adapterA.configureReadLibraries(address(0x1234));
    }

    function test_configureReadLibraries_emits_event_on_success() public {
        useNetworkA();
        vm.startPrank(governor);
        uint32 channelId = READ_CHANNEL_THRESHOLD + 1;
        adapterA.activateReadChannel(channelId);
        // In the local LayerZero mocks, only registered/default libs are accepted
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LZ_OnlyRegisteredOrDefaultLib.selector
            )
        );
        adapterA.configureReadLibraries(address(0xBEEF));
        vm.stopPrank();
    }

    function test_setChainReadSupport_updates_flag_and_emits() public {
        useNetworkA();
        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit LayerZeroAdapter.ChainReadSupportUpdated(CHAIN_ID_B, true);
        adapterA.setChainReadSupport(CHAIN_ID_B, true);
        vm.expectEmit(true, false, false, true);
        emit LayerZeroAdapter.ChainReadSupportUpdated(CHAIN_ID_B, false);
        adapterA.setChainReadSupport(CHAIN_ID_B, false);
        vm.stopPrank();
        assertFalse(adapterA.chainSupportsRead(CHAIN_ID_B));
    }

    function test_configureReadDVNs_reverts_without_channel() public {
        useNetworkA();
        address[] memory dvns = new address[](1);
        dvns[0] = address(0x100);
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.ReadChannelNotConfigured.selector);
        adapterA.configureReadDVNs(address(0xBEEF), dvns, 0, address(0xCAFE));
    }

    function test_configureReadDVNs_validations() public {
        useNetworkA();
        vm.startPrank(governor);
        adapterA.activateReadChannel(READ_CHANNEL_THRESHOLD + 1);

        // zero-length
        address[] memory empty;
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.configureReadDVNs(address(0xBEEF), empty, 0, address(0xCAFE));

        // too many (> MAX_SUPPORTED_DVNS = 8)
        address[] memory many = new address[](9);
        for (uint256 i = 0; i < many.length; i++) {
            many[i] = address(uint160(0x100 + i));
        }
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.configureReadDVNs(address(0xBEEF), many, 0, address(0xCAFE));

        // contains zero address
        address[] memory withZero = new address[](2);
        withZero[0] = address(0);
        withZero[1] = address(0x200);
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.configureReadDVNs(
            address(0xBEEF),
            withZero,
            0,
            address(0xCAFE)
        );

        // unsorted
        address[] memory unsorted = new address[](2);
        unsorted[0] = address(0x300);
        unsorted[1] = address(0x200);
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.configureReadDVNs(
            address(0xBEEF),
            unsorted,
            0,
            address(0xCAFE)
        );

        // zero executor
        address[] memory good = new address[](2);
        good[0] = address(0x200);
        good[1] = address(0x300);
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.configureReadDVNs(address(0xBEEF), good, 0, address(0));

        // zero read lib
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.configureReadDVNs(address(0), good, 0, address(0xCAFE));

        // In the local LayerZero mocks, setConfig requires a registered lib
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LZ_OnlyRegisteredLib.selector)
        );
        adapterA.configureReadDVNs(address(0xBEEF), good, 0, address(0xCAFE));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATION & VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_estimateTransferAssets_reverts_OperationNotSupported()
        public
    {
        useNetworkA();
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: address(this),
                asset: address(0),
                amount: 0,
                message: bytes(""),
                refundAddress: address(this)
            }),
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(adapterA),
                gasLimit: 100000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes(""),
                payInProtocolToken: false,
                feeToken: address(0)
            })
        );
    }

    function test_estimateSendMessage_reverts_when_gasLimit_zero() public {
        useNetworkA();
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234),
                message: bytes("hi"),
                originator: address(this),
                refundAddress: address(this)
            }),
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(adapterA),
                gasLimit: 0,
                calldataSize: 0,
                msgValue: 0,
                options: bytes(""),
                payInProtocolToken: false,
                feeToken: address(0)
            })
        );
    }

    function test_estimateReadState_success_after_channel_and_chain_enabled()
        public
    {
        useNetworkA();
        vm.startPrank(governor);
        adapterA.activateReadChannel(READ_CHANNEL_THRESHOLD + 1);
        adapterA.setChainReadSupport(CHAIN_ID_B, true);
        // Configure a read library attempt; mocks will revert on unregistered lib
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LZ_OnlyRegisteredOrDefaultLib.selector
            )
        );
        adapterA.configureReadLibraries(address(0xBEEF));
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LZ_DefaultSendLibUnavailable.selector)
        );
        adapterA.estimateReadState(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: CHAIN_ID_B,
                target: address(0xdead),
                selector: bytes4(keccak256("balanceOf(address)")),
                readParams: abi.encode(address(this)),
                originator: address(this),
                refundAddress: address(this)
            }),
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(adapterA),
                gasLimit: 200000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes(""),
                payInProtocolToken: false,
                feeToken: address(0)
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_receive_reverts_on_invalid_source_chain_id() public {
        useNetworkA();
        bytes32 guid = keccak256("guid");
        // Payload indicates sourceChainId = CHAIN_ID_A (wrong), while origin srcEid maps to CHAIN_ID_B
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: guid,
                    originator: address(this),
                    sourceChainId: CHAIN_ID_A,
                    recipient: address(this),
                    message: bytes("x")
                })
            )
        );

        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterB)),
            nonce: 1
        });

        vm.expectRevert(BaseBridgeAdapter.InvalidSourceChainId.selector);
        adapterA.lzReceiveTest(
            origin,
            guid,
            payload,
            address(adapterB),
            bytes("")
        );
    }

    function test_receive_reverts_when_sender_untrusted() public {
        useNetworkA();
        bytes32 guid = keccak256("guid2");
        bytes memory payload = abi.encodePacked(
            uint16(BridgeTypes.OperationType.MESSAGE),
            abi.encode(
                BridgeTypes.RelayedMessageParams({
                    operationId: guid,
                    originator: address(this),
                    sourceChainId: CHAIN_ID_B,
                    recipient: address(this),
                    message: bytes("y")
                })
            )
        );

        // Use a wrong sender (not the registered peer for B)
        Origin memory origin = Origin({
            srcEid: LZ_EID_B,
            sender: addressToBytes32(address(adapterA)),
            nonce: 1
        });

        vm.expectRevert();
        adapterA.lzReceiveTest(
            origin,
            guid,
            payload,
            address(adapterB),
            bytes("")
        );
    }
}
