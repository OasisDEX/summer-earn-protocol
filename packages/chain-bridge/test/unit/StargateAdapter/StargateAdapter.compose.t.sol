// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {MockStargateV2Pool} from "../../mocks/MockStargateV2.sol";
import {console} from "forge-std/Test.sol";
import {StargateOFTHelpers} from "../../helpers/StargateOFT.t.sol";
import {MockFleetProxy} from "../../mocks/MockFleetProxy.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../../helpers/BridgeRouterTestHelper.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {BaseBridgeAdapter} from "../../../src/base/BaseBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {StargateAdapter} from "../../../src/adapters/StargateAdapter.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LayerZeroComposeHelper} from "../../../src/helpers/LayerZeroComposeHelper.sol";

contract StargateAdapterComposeTest is
    StargateAdapterSetupTest,
    StargateOFTHelpers
{
    MockFleetProxy public fleetProxyA;
    MockFleetProxy public fleetProxyB;

    function setUp() public override {
        super.setUp();

        // Deploy fleet proxies
        useNetworkA();
        vm.startPrank(governor);
        fleetProxyA = new MockFleetProxy(address(tokenA));
        vm.stopPrank();

        useNetworkB();
        vm.startPrank(governor);
        fleetProxyB = new MockFleetProxy(address(tokenB));
        vm.stopPrank();

        useNetworkA();
    }

    function testLzCompose_Reverts_WhenCallerNotEndpoint() public {
        useNetworkB();

        // Create proper RelayedTransferParams
        bytes memory customComposeMessage = createRelayedTransferParams(
            user,
            address(tokenB),
            1 ether,
            uint256(CHAIN_ID_A),
            bytes32("test-operation"),
            user
        );

        // Create OFT compose message
        bytes memory oftMessage = encodeOFTCompose(
            1, // nonce
            ENDPOINT_ID_A, // srcEid corresponding to CHAIN_ID_A
            1 ether, // amountLD minted on destination
            address(adapterA), // composeFrom (source adapter)
            customComposeMessage // properly encoded RelayedTransferParams
        );

        // Should revert when called by non-endpoint
        vm.expectRevert(IBaseBridgeAdapterErrors.Unauthorized.selector);
        adapterB.lzCompose(
            address(adapterA),
            bytes32("test-guid"),
            oftMessage,
            address(0),
            ""
        );
    }

    function testLzCompose_Reverts_WhenUnknownStargatePool() public {
        useNetworkB();
        // Build valid OFT message
        bytes memory customComposeMessage = createRelayedTransferParams(
            user,
            address(tokenB),
            1 ether,
            uint256(CHAIN_ID_A),
            bytes32("test-operation"),
            user
        );
        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_A,
            1 ether,
            address(adapterA),
            customComposeMessage
        );
        // Call from authorised endpoint but with unregistered pool → Untrusted
        vm.prank(lzEndpointB);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.Untrusted.selector,
                "Stargate pool",
                address(0xBEEF),
                address(0)
            )
        );
        adapterB.lzCompose(
            address(0xBEEF),
            bytes32("guid"),
            oftMessage,
            address(0),
            ""
        );
    }

    function testLzCompose_Reverts_WhenSourceAdapterUntrusted() public {
        useNetworkB();
        // Register a valid pool first
        MockStargateV2Pool pool = new MockStargateV2Pool(address(tokenB));
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(pool));

        // Build message where composeFrom is NOT a registered peer
        bytes memory customComposeMessage = createRelayedTransferParams(
            user,
            address(tokenB),
            1 ether,
            uint256(CHAIN_ID_A),
            bytes32("test-operation-2"),
            user
        );
        address untrustedAdapter = address(0xCAFE);
        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_A,
            1 ether,
            untrustedAdapter,
            customComposeMessage
        );

        vm.prank(lzEndpointB);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedSourceAdapter.selector,
                untrustedAdapter,
                CHAIN_ID_A
            )
        );
        adapterB.lzCompose(
            address(pool),
            bytes32("guid2"),
            oftMessage,
            address(0),
            ""
        );
    }

    function testLzCompose_Reverts_WhenSrcEidChainMismatch() public {
        useNetworkB();
        // Register a valid pool first
        MockStargateV2Pool pool = new MockStargateV2Pool(address(tokenB));
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(pool));

        // Build message with composeFrom set to a valid peer but wrong srcEid mapping
        // Ensure peer adapter relationship exists for adapterA↔adapterB already from setup
        bytes memory customComposeMessage = createRelayedTransferParams(
            user,
            address(tokenB),
            1 ether,
            uint256(CHAIN_ID_A),
            bytes32("test-operation-3"),
            user
        );
        // Use an incorrect srcEid that maps to a different chain (ENDPOINT_ID_B)
        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_B,
            1 ether,
            address(adapterA),
            customComposeMessage
        );

        vm.prank(lzEndpointB);
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidSourceChainId.selector);
        adapterB.lzCompose(
            address(pool),
            bytes32("guid3"),
            oftMessage,
            address(0),
            ""
        );
    }

    function testTransferAsset_WithCompose_Succeeds() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Estimate fee
        (uint256 nativeFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: address(0x1234), // Target contract
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        // Transfer tokens to router and approve
        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));

        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Calculate operation ID
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                address(fleetProxyB), // recipient is fleet proxy
                block.timestamp,
                block.number
            )
        );

        // Mock Stargate to expect the proper RelayedTransferParams
        bytes memory expectedComposeMsg = createRelayedTransferParams(
            address(fleetProxyB), // recipient
            address(tokenA), // asset
            1 ether, // amount
            uint256(CHAIN_ID_A), // sourceChainId
            expectedOperationId, // operationId
            user // originator
        );

        stargateA.setExpectedComposeMsg(expectedComposeMsg);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: CHAIN_ID_B,
                asset: address(tokenA),
                amount: 1 ether,
                target: address(fleetProxyB),
                originator: user,
                message: "",
                refundAddress: user
            });
        // Execute transfer
        vm.prank(address(routerA));
        adapterA.transferAsset{value: nativeFee}(
            expectedOperationId,
            params,
            options
        );

        // Verify compose message was set correctly
        assertTrue(stargateA.composeMsgWasSet());
    }

    function testLzCompose_Reverts_OnInvalidComposeMessage() public {
        useNetworkB();

        // Invalid composeMsg (wrong encoding - not RelayedTransferParams struct)
        bytes memory invalidMessage = abi.encode(
            address(fleetProxyB),
            address(tokenB)
        );
        // Missing required fields

        // Wrap in OFT compose envelope
        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_A,
            1 ether,
            address(adapterA),
            invalidMessage
        );

        // Create a mock Stargate pool first so it passes pool validation
        MockStargateV2Pool mockStargateFrom = new MockStargateV2Pool(
            address(tokenB)
        );

        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(mockStargateFrom));

        vm.expectRevert(); // Reverts on decode - no specific revert reason
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(mockStargateFrom),
            bytes32("test-guid"),
            oftMessage,
            address(0),
            hex""
        );
    }

    function testLzCompose_Reverts_WhenAdapterInsufficientBalance() public {
        useNetworkB();

        uint256 testAmount = 1 ether;

        // Create proper RelayedTransferParams
        bytes memory customComposeMessage = createRelayedTransferParams(
            address(fleetProxyB),
            address(tokenB),
            testAmount,
            uint256(CHAIN_ID_A),
            bytes32("test-op"),
            user
        );

        // Register a valid Stargate pool and build OFT message
        MockStargateV2Pool mockStargateFrom = new MockStargateV2Pool(
            address(tokenB)
        );
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(mockStargateFrom));

        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_A,
            testAmount,
            address(adapterA),
            customComposeMessage
        );

        // Don't mint tokens to adapter - should cause insufficient balance
        assertEq(tokenB.balanceOf(address(adapterB)), 0);

        // Should revert with InsufficientBalance - but contract emits event first
        vm.prank(lzEndpointB);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(adapterB),
                0,
                testAmount
            )
        );
        adapterB.lzCompose(
            address(mockStargateFrom),
            bytes32("test-guid"),
            oftMessage,
            address(0),
            hex""
        );
    }

    function testLzCompose_RecordsFailure_WhenDecodedParamsInvalid() public {
        useNetworkB();

        uint256 testAmount = 1 ether;

        // Create RelayedTransferParams with invalid parameters (zero address for recipient)
        bytes memory customComposeMessage = createRelayedTransferParams(
            address(0), // recipient - INVALID
            address(tokenB),
            testAmount,
            uint256(CHAIN_ID_A),
            bytes32("test-op"),
            user
        );

        // Register a valid Stargate pool and build OFT message
        MockStargateV2Pool mockStargateFrom = new MockStargateV2Pool(
            address(tokenB)
        );
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(mockStargateFrom));

        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_A,
            testAmount,
            address(adapterA),
            customComposeMessage
        );

        // Mint tokens to adapter
        tokenB.mint(address(adapterB), testAmount);

        // Balances before
        uint256 adapterBefore = tokenB.balanceOf(address(adapterB));
        uint256 routerBefore = tokenB.balanceOf(address(routerB));

        // Call lzCompose – now Router records failure instead of reverting
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(mockStargateFrom),
            bytes32("test-guid"),
            oftMessage,
            address(0),
            hex""
        );

        // Failure is recorded on the router for the provided operationId
        (
            BridgeTypes.OperationType opType,
            address failingAdapter,
            uint16 srcChain,
            ,
            uint256 failedAt
        ) = routerB.getFailedDeliveryRecord(bytes32("test-op"));

        assertEq(
            uint8(opType),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(failingAdapter, address(adapterB));
        assertEq(srcChain, CHAIN_ID_A);
        assertGt(failedAt, 0);

        // Tokens were moved from adapter to router; router's transfer to recipient failed
        assertEq(
            tokenB.balanceOf(address(adapterB)),
            adapterBefore - testAmount
        );
        assertEq(tokenB.balanceOf(address(routerB)), routerBefore + testAmount);
    }

    function testLzCompose_Reverts_WhenMessageHeaderTooShort() public {
        useNetworkB();

        // Create a mock Stargate pool first so it passes pool validation
        MockStargateV2Pool mockStargateFrom = new MockStargateV2Pool(
            address(tokenB)
        );
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(mockStargateFrom));

        // Create an OFT message that is too short (< 96 bytes)
        bytes memory invalidOFTMessage = hex"01"; // too short

        // Should revert with InvalidMessage due to header length
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidMessage.selector);
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(mockStargateFrom),
            bytes32("test-guid"),
            invalidOFTMessage,
            address(0),
            hex""
        );
    }

    function testLzCompose_Reverts_WhenMessageHeaderMalformed() public {
        useNetworkB();

        // Create a mock Stargate pool first so it passes pool validation
        MockStargateV2Pool mockStargateFrom = new MockStargateV2Pool(
            address(tokenB)
        );
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(mockStargateFrom));

        // Construct an OFT header with missing composeFrom and payload (length = 44)
        bytes memory malformedOFTMessage = abi.encodePacked(
            uint64(1),
            ENDPOINT_ID_A,
            uint256(1 ether)
        );

        // Should revert with InvalidMessage during OFT header decoding
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidMessage.selector);
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(mockStargateFrom),
            bytes32("test-guid"),
            malformedOFTMessage,
            address(0),
            hex""
        );
    }

    function testLzCompose_FailurePath_RouterRetainsTokens() public {
        useNetworkB();

        uint256 testAmount = 1 ether;
        address testUser = makeAddr("testUser");
        bytes32 testOperationId = keccak256("system-operation");

        // ───────────────────  failing recipient & mocked Stargate  ───────────────────
        MockFleetProxy mockFleetCommander = new MockFleetProxy(address(tokenB));
        mockFleetCommander.setShouldRevert(true);

        MockStargateV2Pool mockStargateFrom = new MockStargateV2Pool(
            address(tokenB)
        );
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(mockStargateFrom));

        // Create proper RelayedTransferParams struct
        bytes memory customComposeMessage = createRelayedTransferParams(
            address(mockFleetCommander),
            address(tokenB),
            testAmount,
            uint256(CHAIN_ID_A),
            testOperationId,
            testUser
        );

        // Create OFT message directly
        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_A,
            testAmount,
            address(adapterA),
            customComposeMessage
        );

        // Provide the adapter with the funds it will forward
        tokenB.mint(address(adapterB), testAmount);

        // ───────────────────────────  balances before  ───────────────────────────────
        uint256 routerBalanceBefore = tokenB.balanceOf(address(routerB));
        uint256 fleetCommanderBalanceBefore = tokenB.balanceOf(
            address(mockFleetCommander)
        );

        // Call lzCompose – Router records failure instead of reverting
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(mockStargateFrom),
            bytes32("test-guid"),
            oftMessage,
            address(0),
            hex""
        );

        // ───────────────────────────  post-conditions  ───────────────────────────────
        // Router retains tokens because token transfer is rolled back with the self-call revert; adapter retains none
        assertEq(
            tokenB.balanceOf(address(adapterB)),
            0,
            "adapter should hold no tokens after failure"
        );
        assertEq(
            tokenB.balanceOf(address(routerB)),
            routerBalanceBefore + testAmount,
            "router should retain tokens after failure"
        );
        assertEq(
            tokenB.balanceOf(address(mockFleetCommander)),
            fleetCommanderBalanceBefore,
            "recipient should not receive tokens on failure"
        );

        // Failure recorded on router with provided operationId
        (
            BridgeTypes.OperationType opType2,
            address failingAdapter2,
            uint16 srcChain2,
            ,
            uint256 failedAt2
        ) = routerB.getFailedDeliveryRecord(testOperationId);
        assertEq(
            uint8(opType2),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(failingAdapter2, address(adapterB));
        assertEq(srcChain2, CHAIN_ID_A);
        assertGt(failedAt2, 0);
    }

    function testLzCompose_SuccessPath_TokensDelivered() public {
        useNetworkB();

        uint256 testAmount = 1 ether;
        address testUser = makeAddr("testUser");
        bytes32 testOperationId = keccak256("system-operation-success");

        // ───────────────────  healthy recipient & mocked Stargate  ───────────────────
        MockFleetProxy fleetProxy = new MockFleetProxy(address(tokenB));
        // NOTE: do NOT setShouldRevert(true) → default is false (happy path)

        MockStargateV2Pool mockStargateFrom = new MockStargateV2Pool(
            address(tokenB)
        );
        vm.prank(governor);
        adapterB.addSupportedAsset(address(tokenB), address(mockStargateFrom));

        // Proper RelayedTransferParams struct
        bytes memory composeMsg = createRelayedTransferParams(
            address(fleetProxy),
            address(tokenB),
            testAmount,
            uint256(CHAIN_ID_A),
            testOperationId,
            testUser
        );

        // OFT-encoded message
        bytes memory oftMessage = encodeOFTCompose(
            1,
            ENDPOINT_ID_A,
            testAmount,
            address(adapterA),
            composeMsg
        );

        // Fund the destination adapter with the tokens it should forward
        tokenB.mint(address(adapterB), testAmount);

        // ───────────────────────────  balances before  ───────────────────────────────
        uint256 routerBalanceBefore = tokenB.balanceOf(address(routerB));
        uint256 fleetBalanceBefore = tokenB.balanceOf(address(fleetProxy));

        // Call lzCompose from the authorised endpoint – should NOT revert
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(mockStargateFrom),
            bytes32("test-guid-success"),
            oftMessage,
            address(0),
            hex""
        );

        // ───────────────────────────  post-conditions  ───────────────────────────────
        // 1. Adapter no longer holds the funds
        assertEq(
            tokenB.balanceOf(address(adapterB)),
            0,
            "adapter should have forwarded all tokens"
        );

        // 2. Router is left with no balance (immediately forwarded to recipient)
        assertEq(
            tokenB.balanceOf(address(routerB)),
            routerBalanceBefore,
            "router should not retain tokens"
        );

        // 3. Recipient now owns the funds and callback executed
        assertEq(
            tokenB.balanceOf(address(fleetProxy)),
            fleetBalanceBefore + testAmount,
            "fleet proxy did not receive the expected amount"
        );
        assertTrue(fleetProxy.receivedAssets(), "callback not triggered");
        assertEq(fleetProxy.lastAsset(), address(tokenB), "asset mismatch");
        assertEq(fleetProxy.lastAmount(), testAmount, "amount mismatch");
        assertEq(
            fleetProxy.lastSourceChainId(),
            CHAIN_ID_A,
            "sourceChainId mismatch"
        );
    }

    function testLzCompose_TenderlyCalldata_DoesNotRevert() public {
        useNetworkB();

        // Tenderly-captured call args
        address fromPool = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26;
        bytes32 guid = 0xa829f5340dc60da5b39500b92d93c8f6b0801460b29e0393e60d18b77ad714b5;
        bytes
            memory realMessage = hex"0000000000074f420000759f00000000000000000000000000000000000000000000000000000000000f3c630000000000000000000000007bfe141b1d6fed49cd2e49e4403736e95c041cee0000000000000000000000000000000000000000000000000000000000000020f77e3005a8aab79d691ed12d82afda98d29ac6bf504ff1ec147cebf9f58d03830000000000000000000000004b757b7bfaf539f16764bedb606be66bccbec214000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000fa92fe0dfea6ae882492e41095b49ba80f0b2e8d0000000000000000000000000b2c639c533813f4aa9d7837caf62653d097ff8500000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000";
        address caller = 0xb0f758323D3798a6A567C1601d84f30d1BCAAA0b;
        bytes memory extraData = hex"";

        // Parse OFT header and inner compose message
        uint256 amountLD = this.oftAmountLD(realMessage);
        bytes memory composeMsg = this.oftComposeMsg(realMessage);

        BridgeTypes.RelayedTransferParams memory decoded = abi.decode(
            composeMsg,
            (BridgeTypes.RelayedTransferParams)
        );

        // Extract srcEid and composeFrom from OFT header to satisfy adapter checks
        uint32 srcEid = this.oftSrcEid(realMessage);
        address composeFrom = this.oftComposeFrom(realMessage);

        // Deploy a mock Stargate pool and place its code at the real fromPool address
        MockStargateV2Pool mockPool = new MockStargateV2Pool(decoded.asset);
        vm.etch(fromPool, address(mockPool).code);

        // Register the pool so lzCompose validates it
        vm.prank(governor);
        adapterB.addSupportedAsset(decoded.asset, fromPool);

        // Ensure the endpoint mapping matches the Tenderly packet's srcEid → maps to actual source chain from payload
        vm.prank(governor);
        adapterB.mapExternalId(decoded.sourceChainId, srcEid);

        // Allow the composeFrom OApp (source) as a valid peer for the real source chain from payload
        vm.prank(governor);
        registryB.registerAdapterPeerPair(
            composeFrom,
            address(adapterB),
            decoded.sourceChainId,
            CHAIN_ID_B
        );

        // Ensure the recipient is a contract that can receive the callback
        MockFleetProxy fleet = new MockFleetProxy(decoded.asset);
        vm.etch(decoded.recipient, address(fleet).code);
        fleet = MockFleetProxy(decoded.recipient);

        // Mock ERC20 transfers to succeed for both adapter->router and router->recipient legs
        vm.mockCall(
            decoded.asset,
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                address(routerB),
                amountLD
            ),
            abi.encode(true)
        );
        vm.mockCall(
            decoded.asset,
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                decoded.recipient,
                amountLD
            ),
            abi.encode(true)
        );

        // Call as the authorised LZ endpoint – should NOT revert
        vm.prank(lzEndpointB);
        adapterB.lzCompose(fromPool, guid, realMessage, caller, extraData);
    }
}
