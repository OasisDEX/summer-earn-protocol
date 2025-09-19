// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseERC7802Adapter} from "../../src/adapters/BaseERC7802Adapter.sol";
import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {BaseERC7802AdapterSetupTest} from "./BaseERC7802Adapter.setup.t.sol";

/**
 * @title BaseERC7802Adapter Compose Tests
 * @notice Tests LayerZero compose functionality of BaseERC7802Adapter
 */
contract BaseERC7802AdapterComposeTest is BaseERC7802AdapterSetupTest {
    using AddressCast for address;

    /*//////////////////////////////////////////////////////////////
                        LZ COMPOSE AUTHORIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LzCompose_RevertsWhenCallerNotLZEndpoint() public {
        bytes32 guid = keccak256("test_guid");
        bytes memory message = "";
        address caller = address(0x1234);
        bytes memory extraData = "";

        vm.expectRevert(BaseERC7802Adapter.Unauthorized.selector);
        adapterA.lzCompose(address(0), guid, message, caller, extraData);
    }

    function test_LzCompose_AcceptsCallsFromLZEndpoint() public {
        // This test would need a properly formatted OFT compose message
        // to avoid reverting due to message format validation
    }

    /*//////////////////////////////////////////////////////////////
                        OFT COMPOSE DECODING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeOFTCompose_RevertsForShortMessage() public {
        bytes memory shortMessage = new bytes(75); // Less than 76 bytes minimum

        vm.expectRevert(BaseERC7802Adapter.InvalidMessage.selector);
        adapterA._decodeOFTCompose(shortMessage);
    }

    function test_DecodeOFTCompose_RevertsForExactly76Bytes() public {
        bytes memory message76 = new bytes(76);

        vm.expectRevert(BaseERC7802Adapter.InvalidMessage.selector);
        adapterA._decodeOFTCompose(message76);
    }

    function test_DecodeOFTCompose_ReturnsCorrectValuesForValidMessage()
        public
    {
        // Create a valid OFT compose message
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);
        bytes memory composeMsg = abi.encode("test compose message");

        bytes memory validMessage = OFTComposeMsgCodec.encode(
            1, // nonce
            srcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        (
            uint32 decodedSrcEid,
            uint256 decodedAmountLD,
            address decodedComposeFrom,
            bytes memory decodedComposeMsg
        ) = adapterA._decodeOFTCompose(validMessage);

        assertEq(decodedSrcEid, srcEid);
        assertEq(decodedAmountLD, amountLD);
        assertEq(decodedComposeFrom, composeFrom);
        assertEq(decodedComposeMsg.length, composeMsg.length);
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOSE MESSAGE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LzCompose_ValidatesTrustedSourceAdapter() public {
        // Create a valid OFT compose message from untrusted adapter
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address untrustedAdapter = address(0x9999); // Not in registry
        bytes memory composeMsg = abi.encode("test");

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            amountLD,
            untrustedAdapter,
            composeMsg
        );

        vm.prank(lzEndpointA);
        vm.expectRevert(BaseERC7802Adapter.UntrustedSourceAdapter.selector);
        adapterA.lzCompose(
            untrustedAdapter,
            bytes32(0),
            message,
            address(this),
            ""
        );
    }

    function test_LzCompose_ValidatesSourceChainIdMapping() public {
        // Create message with unmapped source EID
        uint32 unmappedSrcEid = 9999;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);
        bytes memory composeMsg = abi.encode("test");

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            unmappedSrcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        vm.prank(lzEndpointA);
        vm.expectRevert(BaseERC7802Adapter.InvalidSourceChainId.selector);
        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");
    }

    function test_LzCompose_ValidatesSupportedAsset() public {
        // Create message for unsupported asset
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);

        // Encode transfer params with unsupported asset
        ERC20Mock unsupportedToken = new ERC20Mock();
        BridgeTypes.RelayedTransferParams memory transferParams = BridgeTypes
            .RelayedTransferParams({
                operationId: keccak256("test"),
                originator: user,
                sourceChainId: CHAIN_ID_B,
                recipient: recipient,
                asset: address(unsupportedToken), // Unsupported asset
                amount: amountLD,
                message: ""
            });

        bytes memory composeMsg = abi.encode(transferParams);

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        vm.prank(lzEndpointA);
        vm.expectRevert(BaseERC7802Adapter.UnsupportedAsset.selector);
        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOSE TOKEN HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LzCompose_RevertsForInsufficientTokenBalance() public {
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);

        // Create valid transfer params
        BridgeTypes.RelayedTransferParams memory transferParams = BridgeTypes
            .RelayedTransferParams({
                operationId: keccak256("test"),
                originator: user,
                sourceChainId: CHAIN_ID_B,
                recipient: recipient,
                asset: address(tokenA),
                amount: amountLD,
                message: ""
            });

        bytes memory composeMsg = abi.encode(transferParams);

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        // Ensure adapter has insufficient balance
        uint256 adapterBalance = tokenA.balanceOf(address(adapterA));
        assertLt(adapterBalance, amountLD);

        vm.prank(lzEndpointA);
        vm.expectRevert(BaseERC7802Adapter.InsufficientBalance.selector);
        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");
    }

    function test_LzCompose_UsesOFTAmountAsAuthoritative() public {
        uint32 srcEid = LZ_EID_B;
        uint256 oftAmount = 100e18;
        uint256 payloadAmount = 50e18; // Different from OFT amount
        address composeFrom = address(adapterB);

        // Give adapter tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), oftAmount);

        // Create transfer params with different amount
        BridgeTypes.RelayedTransferParams memory transferParams = BridgeTypes
            .RelayedTransferParams({
                operationId: keccak256("test"),
                originator: user,
                sourceChainId: CHAIN_ID_B,
                recipient: recipient,
                asset: address(tokenA),
                amount: payloadAmount, // Different from OFT amount
                message: ""
            });

        bytes memory composeMsg = abi.encode(transferParams);

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            oftAmount, // OFT amount should be used
            composeFrom,
            composeMsg
        );

        uint256 routerBalanceBefore = tokenA.balanceOf(address(routerA));

        vm.prank(lzEndpointA);
        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");

        uint256 routerBalanceAfter = tokenA.balanceOf(address(routerA));

        // Verify OFT amount was used, not payload amount
        assertEq(routerBalanceAfter, routerBalanceBefore + oftAmount);
    }

    function test_LzCompose_TransfersTokensToRouter() public {
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);

        // Give adapter tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), amountLD);

        // Create valid transfer params
        BridgeTypes.RelayedTransferParams memory transferParams = BridgeTypes
            .RelayedTransferParams({
                operationId: keccak256("test"),
                originator: user,
                sourceChainId: CHAIN_ID_B,
                recipient: recipient,
                asset: address(tokenA),
                amount: amountLD,
                message: ""
            });

        bytes memory composeMsg = abi.encode(transferParams);

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        uint256 adapterBalanceBefore = tokenA.balanceOf(address(adapterA));
        uint256 routerBalanceBefore = tokenA.balanceOf(address(routerA));

        vm.prank(lzEndpointA);
        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");

        uint256 adapterBalanceAfter = tokenA.balanceOf(address(adapterA));
        uint256 routerBalanceAfter = tokenA.balanceOf(address(routerA));

        // Verify tokens were transferred from adapter to router
        assertEq(adapterBalanceAfter, adapterBalanceBefore - amountLD);
        assertEq(routerBalanceAfter, routerBalanceBefore + amountLD);
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOSE PAYLOAD DELIVERY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LzCompose_DeliversCorrectPayloadToRouter() public {
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);
        bytes32 operationId = keccak256("test_operation");

        // Give adapter tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), amountLD);

        // Create transfer params
        BridgeTypes.RelayedTransferParams memory transferParams = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: user,
                sourceChainId: CHAIN_ID_B,
                recipient: recipient,
                asset: address(tokenA),
                amount: amountLD,
                message: "test message"
            });

        bytes memory composeMsg = abi.encode(transferParams);

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        // Expected relayed params (with OFT amount overriding payload amount)
        BridgeTypes.RelayedTransferParams
            memory expectedRelayedParams = BridgeTypes.RelayedTransferParams({
                operationId: operationId,
                originator: user,
                sourceChainId: CHAIN_ID_B,
                recipient: recipient,
                asset: address(tokenA),
                amount: amountLD, // OFT amount used
                message: "test message"
            });

        vm.prank(lzEndpointA);

        // Mock the router.deliver call to verify it's called correctly
        vm.expectCall(
            address(routerA),
            abi.encodeCall(
                routerA.deliver,
                (
                    BridgeTypes.OperationType.TRANSFER_ASSET,
                    abi.encode(expectedRelayedParams)
                )
            )
        );

        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOSE HELPER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EncodeComposeTransferParams_ReturnsCorrectEncoding() public {
        bytes32 operationId = keccak256("test");
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "test message",
                refundAddress: user
            });

        bytes memory encoded = adapterA._encodeComposeTransferParams(
            operationId,
            params
        );

        BridgeTypes.RelayedTransferParams memory decoded = abi.decode(
            encoded,
            (BridgeTypes.RelayedTransferParams)
        );

        assertEq(decoded.operationId, operationId);
        assertEq(decoded.originator, user);
        assertEq(decoded.sourceChainId, CHAIN_ID_A); // Current chain
        assertEq(decoded.recipient, recipient);
        assertEq(decoded.asset, address(tokenA));
        assertEq(decoded.amount, 100e18);
        assertEq(decoded.message, "test message");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LzCompose_HandlesEmptyComposeMessage() public {
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);

        // Give adapter tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), amountLD);

        // Empty compose message
        bytes memory composeMsg = "";

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        vm.prank(lzEndpointA);
        vm.expectRevert(); // Should revert due to empty compose message
        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");
    }

    function test_LzCompose_HandlesLargeComposeMessage() public {
        uint32 srcEid = LZ_EID_B;
        uint256 amountLD = 100e18;
        address composeFrom = address(adapterB);

        // Give adapter tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), amountLD);

        // Large compose message
        bytes memory largeMessage = new bytes(10000);
        for (uint256 i = 0; i < 10000; i++) {
            largeMessage[i] = bytes1(uint8(i % 256));
        }

        BridgeTypes.RelayedTransferParams memory transferParams = BridgeTypes
            .RelayedTransferParams({
                operationId: keccak256("test"),
                originator: user,
                sourceChainId: CHAIN_ID_B,
                recipient: recipient,
                asset: address(tokenA),
                amount: amountLD,
                message: largeMessage
            });

        bytes memory composeMsg = abi.encode(transferParams);

        bytes memory message = OFTComposeMsgCodec.encode(
            1,
            srcEid,
            amountLD,
            composeFrom,
            composeMsg
        );

        vm.prank(lzEndpointA);
        adapterA.lzCompose(composeFrom, bytes32(0), message, address(this), "");
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
