// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {Test, console} from "forge-std/Test.sol";
import {IOAppPreCrimeSimulator, InboundPacket, Origin} from "@layerzerolabs/oapp-evm/contracts/precrime/interfaces/IOAppPreCrimeSimulator.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SummerTokenOAppTest is SummerTokenTestBase {
    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    // Add missing constants from OFTCore
    uint16 public constant SEND_TYPE = 1;
    uint16 public constant SEND_AND_CALL_TYPE = 2;

    // Add missing events
    event EnforcedOptionSet(EnforcedOptionParam[] options);
    event PreCrimeSet(address preCrime);
    event PeerSet(uint32 targetEid, bytes32 newPeer);

    function setUp() public virtual override {
        super.setUp();
    }

    // ===============================================
    // OApp Version Tests
    // ===============================================

    function test_OAppVersion() public view {
        (uint64 senderVersion, uint64 receiverVersion) = aSummerToken
            .oAppVersion();
        assertEq(senderVersion, 1);
        assertEq(receiverVersion, 2);
    }

    // ===============================================
    // Enforced Options Tests
    // ===============================================

    function test_SetEnforcedOptions() public {
        vm.startPrank(owner);

        EnforcedOptionParam[] memory options = new EnforcedOptionParam[](1);
        options[0] = EnforcedOptionParam({
            eid: bEid,
            msgType: SEND_TYPE,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                200000,
                0
            )
        });

        vm.expectEmit(true, true, true, true);
        emit EnforcedOptionSet(options);

        aSummerToken.setEnforcedOptions(options);

        bytes memory storedOptions = aSummerToken.enforcedOptions(
            bEid,
            SEND_TYPE
        );
        assertEq(storedOptions, options[0].options);

        vm.stopPrank();
    }

    function test_CombineOptions() public {
        // Set enforced options first
        vm.startPrank(owner);
        EnforcedOptionParam[]
            memory enforcedOptions = new EnforcedOptionParam[](1);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: bEid,
            msgType: SEND_TYPE,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                200000,
                0
            )
        });
        aSummerToken.setEnforcedOptions(enforcedOptions);
        vm.stopPrank();

        // Test combining with extra options
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(100000, 0);
        bytes memory combined = aSummerToken.combineOptions(
            bEid,
            SEND_TYPE,
            extraOptions
        );

        assertTrue(combined.length > 0);
    }

    // ===============================================
    // PreCrime Tests
    // ===============================================

    function test_SetPreCrime() public {
        vm.startPrank(owner);
        address preCrime = address(0x123);

        aSummerToken.setPreCrime(preCrime);
        assertEq(aSummerToken.preCrime(), preCrime);

        vm.stopPrank();
    }

    function test_PreCrimeSimulation() public {
        vm.startPrank(owner);
        aSummerToken.setPreCrime(address(this));

        InboundPacket[] memory packets = new InboundPacket[](1);
        packets[0] = InboundPacket({
            origin: Origin({
                srcEid: bEid,
                sender: OFTMsgCodec.addressToBytes32(address(bSummerToken)),
                nonce: 1
            }),
            dstEid: aEid,
            receiver: address(aSummerToken),
            guid: bytes32(0),
            value: 0,
            executor: address(0),
            message: abi.encodePacked(
                OFTMsgCodec.addressToBytes32(owner),
                uint64(1000)
            ),
            extraData: ""
        });

        vm.expectRevert();
        aSummerToken.lzReceiveAndRevert(packets);
        vm.stopPrank();
    }

    // ===============================================
    // Cross-Chain Message Tests
    // ===============================================

    function test_Send() public {
        enableTransfers();
        uint256 amount = 1000e18;
        aSummerToken.transfer(user1, amount);

        vm.startPrank(user1);

        SendParam memory sendParam = SendParam({
            dstEid: bEid,
            to: addressToBytes32(user2),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(200000, 0),
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        vm.deal(user1, fee.nativeFee);

        vm.expectEmit(false, true, true, true);
        emit IOFT.OFTSent(bytes32(0), bEid, user1, amount, amount);

        (
            MessagingReceipt memory receipt,
            OFTReceipt memory oftReceipt
        ) = aSummerToken.send{value: fee.nativeFee}(
                sendParam,
                fee,
                payable(user1)
            );

        assertEq(receipt.fee.nativeFee, fee.nativeFee);
        assertEq(oftReceipt.amountSentLD, amount);
        assertEq(oftReceipt.amountReceivedLD, amount);

        verifyPackets(bEid, addressToBytes32(address(bSummerToken)));

        vm.stopPrank();
    }

    function test_LzReceive() public {
        enableTransfers();

        // First transfer some tokens from A to B to reduce A's supply
        vm.startPrank(owner);

        // Set up worker options for the endpoint
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 200000, 0); // gas limit, value // index, gas limit, value

        SendParam memory sendParam = SendParam({
            dstEid: bEid,
            to: bytes32(uint256(uint160(address(0x2)))),
            amountLD: 1e21,
            minAmountLD: 1e21,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        // Get the messaging fee
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        // Send tokens from A to B
        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            owner // refund address
        );
        vm.stopPrank();

        // Now test receiving tokens back
        vm.startPrank(address(endpoints[aEid]));

        vm.expectEmit(true, true, true, true);
        emit IOFT.OFTReceived(bytes32(0), bEid, address(0x2), 1e21);

        aSummerToken.lzReceive(
            Origin({
                srcEid: bEid,
                sender: OFTMsgCodec.addressToBytes32(address(bSummerToken)),
                nonce: 1
            }),
            bytes32(0),
            abi.encodePacked(
                OFTMsgCodec.addressToBytes32(address(0x2)),
                uint64(1e9) // Amount in shared decimals
            ),
            address(0),
            ""
        );
        vm.stopPrank();
    }

    // ===============================================
    // OFT Interface Tests
    // ===============================================

    function test_OFTVersion() public view {
        (bytes4 interfaceId, uint64 version) = aSummerToken.oftVersion();
        assertEq(interfaceId, type(IOFT).interfaceId);
        assertEq(version, 1);
    }

    function test_Token() public view {
        assertEq(aSummerToken.token(), address(aSummerToken));
    }

    function test_ApprovalRequired() public view {
        assertFalse(aSummerToken.approvalRequired());
    }

    function test_SharedDecimals() public view {
        assertEq(aSummerToken.sharedDecimals(), 6);
    }

    // ===============================================
    // OAppOptionsType3 Tests
    // ===============================================

    function test_CombineOptions_NoEnforcedOptions() public view {
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(100000, 0);
        bytes memory combined = aSummerToken.combineOptions(
            bEid,
            SEND_TYPE,
            options
        );
        assertEq(combined, options);
    }

    function test_CombineOptions_NoCallerOptions() public {
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({
            eid: bEid,
            msgType: SEND_TYPE,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                200000,
                0
            )
        });

        vm.prank(owner);
        aSummerToken.setEnforcedOptions(params);

        bytes memory combined = aSummerToken.combineOptions(
            bEid,
            SEND_TYPE,
            ""
        );
        assertEq(combined, params[0].options);
    }

    function test_CombineOptions_BothOptions() public {
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({
            eid: bEid,
            msgType: SEND_TYPE,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                200000,
                0
            )
        });

        vm.prank(owner);
        aSummerToken.setEnforcedOptions(params);

        bytes memory callerOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(100000, 0);
        bytes memory combined = aSummerToken.combineOptions(
            bEid,
            SEND_TYPE,
            callerOptions
        );
        assertTrue(combined.length > params[0].options.length);
    }

    function test_RevertWhen_InvalidOptionsType() public {
        // First set some enforced options so we don't hit the early return
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({
            eid: bEid,
            msgType: SEND_TYPE,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                200000,
                0
            )
        });
        vm.prank(owner);
        aSummerToken.setEnforcedOptions(params);

        // Create invalid options with type 2 instead of type 3
        bytes memory invalidTypeOptions = hex"0002"; // First 2 bytes represent type 2

        vm.expectRevert(
            abi.encodeWithSelector(
                IOAppOptionsType3.InvalidOptions.selector,
                invalidTypeOptions
            )
        );
        aSummerToken.combineOptions(bEid, SEND_TYPE, invalidTypeOptions);
    }

    // ===============================================
    // Message Inspector Tests
    // ===============================================

    function test_SetMsgInspector() public {
        address inspector = address(0x123);
        vm.prank(owner);
        aSummerToken.setMsgInspector(inspector);
        assertEq(aSummerToken.msgInspector(), inspector);
    }

    // ===============================================
    // PreCrime Tests
    // ===============================================

    function test_RevertWhen_NonPreCrimeCallsSimulate() public {
        Origin memory origin = Origin({
            srcEid: bEid,
            sender: bytes32(uint256(uint160(address(bSummerToken)))),
            nonce: 1
        });

        vm.expectRevert(abi.encodeWithSignature("OnlySelf()"));
        aSummerToken.lzReceiveSimulate(origin, bytes32(0), "", address(0), "");
    }

    function test_RevertWhen_NonOwnerSetsPreCrime() public {
        address nonOwner = address(0x1);
        address newPreCrime = address(0x123);

        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        aSummerToken.setPreCrime(newPreCrime);
    }

    // ===============================================
    // Decimal Conversion Tests
    // ===============================================

    function test_DecimalConversions() public view {
        uint256 amount = 1234567890;

        // Test conversion consistency using decimalConversionRate
        uint256 amountInLocalDecimals = amount *
            aSummerToken.decimalConversionRate();
        assertEq(
            amountInLocalDecimals / aSummerToken.decimalConversionRate(),
            amount
        );
    }

    // ===============================================
    // Error Cases
    // ===============================================

    function test_RevertWhen_SlippageExceeded() public {
        enableTransfers();
        uint256 amount = 1000e18;

        // Transfer tokens to user1 first
        vm.startPrank(owner);
        aSummerToken.transfer(user1, amount);
        vm.stopPrank();

        vm.startPrank(user1);

        // First get a quote with valid parameters
        SendParam memory validParam = SendParam({
            dstEid: bEid,
            to: addressToBytes32(user2),
            amountLD: amount,
            minAmountLD: amount, // Set valid minAmount for quote
            extraOptions: OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(50000, 0)
                .addExecutorLzComposeOption(0, 50000, 0),
            composeMsg: "",
            oftCmd: ""
        });

        // Get the messaging fee with valid parameters
        MessagingFee memory fee = aSummerToken.quoteSend(validParam, false);

        // Now create the actual send parameters with high minAmountLD
        SendParam memory sendParam = SendParam({
            dstEid: bEid,
            to: addressToBytes32(user2),
            amountLD: amount,
            minAmountLD: amount + 1, // Set minimum higher than actual amount
            extraOptions: validParam.extraOptions,
            composeMsg: "",
            oftCmd: ""
        });

        // Give user1 more than enough ETH to cover the fee
        vm.deal(user1, fee.nativeFee * 2);

        // This should revert with SlippageExceeded
        vm.expectRevert(
            abi.encodeWithSelector(
                IOFT.SlippageExceeded.selector,
                amount,
                amount + 1
            )
        );
        aSummerToken.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        vm.stopPrank();
    }

    function test_RevertWhen_InvalidLocalDecimals() public {
        vm.startPrank(owner);
        ISummerToken.ConstructorParams memory constructorParams = ISummerToken
            .ConstructorParams({
                name: "Summer Token",
                symbol: "SUMMER",
                lzEndpoint: address(endpoints[aEid]),
                initialOwner: owner,
                accessManager: address(accessManagerA),
                maxSupply: INITIAL_SUPPLY * 10 ** 18,
                transferEnableDate: block.timestamp + 1 days,
                hubChainId: 31337
            });

        // Try to deploy the invalid decimals token - should revert
        vm.expectRevert(IOFT.InvalidLocalDecimals.selector);
        new InvalidDecimalsSummerToken(constructorParams);

        vm.stopPrank();
    }

    // ===============================================
    // Additional Error Cases
    // ===============================================

    function test_RevertWhen_NonOwnerSetsEnforcedOptions() public {
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({
            eid: bEid,
            msgType: SEND_TYPE,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                200000,
                0
            )
        });

        address nonOwner = address(0x1);
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        aSummerToken.setEnforcedOptions(params);
    }

    function test_RevertWhen_EmptyOptionsWithNoEnforced() public view {
        bytes memory empty = "";
        bytes memory result = aSummerToken.combineOptions(
            bEid,
            SEND_TYPE,
            empty
        );
        assertEq(result, empty);
    }

    function test_RevertWhen_InvalidOptionsLength() public {
        // First set some enforced options so we don't hit the early return
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({
            eid: bEid,
            msgType: SEND_TYPE,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                200000,
                0
            )
        });
        vm.prank(owner);
        aSummerToken.setEnforcedOptions(params);

        // Now test with invalid length options
        bytes memory invalidLength = hex"03"; // Only 1 byte
        vm.expectRevert(
            abi.encodeWithSelector(
                IOAppOptionsType3.InvalidOptions.selector,
                invalidLength
            )
        );
        aSummerToken.combineOptions(bEid, SEND_TYPE, invalidLength);
    }

    // ===============================================
    // PreCrime Simulation Tests
    // ===============================================

    function test_RevertWhen_NonPreCrimeCallsLzReceiveAndRevert() public {
        InboundPacket[] memory packets = new InboundPacket[](1);
        packets[0] = InboundPacket({
            origin: Origin({
                srcEid: bEid,
                sender: OFTMsgCodec.addressToBytes32(address(bSummerToken)),
                nonce: 1
            }),
            dstEid: aEid,
            receiver: address(aSummerToken),
            guid: bytes32(0),
            value: 0,
            executor: address(0),
            message: "",
            extraData: ""
        });

        vm.expectRevert();
        aSummerToken.lzReceiveAndRevert(packets);
    }

    function test_RevertWhen_NonTrustedPeerInPreCrime() public {
        address mockPreCrime = address(0x123);
        vm.prank(owner);
        aSummerToken.setPreCrime(mockPreCrime);

        InboundPacket[] memory packets = new InboundPacket[](1);
        packets[0] = InboundPacket({
            origin: Origin({
                srcEid: bEid,
                sender: OFTMsgCodec.addressToBytes32(address(0xdead)), // Non-trusted peer
                nonce: 1
            }),
            dstEid: aEid,
            receiver: address(aSummerToken),
            guid: bytes32(0),
            value: 0,
            executor: address(0),
            message: "",
            extraData: ""
        });

        vm.prank(mockPreCrime);
        vm.expectRevert();
        aSummerToken.lzReceiveAndRevert(packets);
    }

    function test_RevertWhen_DirectLzReceiveSimulateCall() public {
        Origin memory origin = Origin({
            srcEid: bEid,
            sender: bytes32(uint256(uint160(address(bSummerToken)))),
            nonce: 1
        });

        vm.expectRevert(abi.encodeWithSignature("OnlySelf()"));
        aSummerToken.lzReceiveSimulate(origin, bytes32(0), "", address(0), "");
    }

    function test_OAppAddress() public view {
        assertEq(aSummerToken.oApp(), address(aSummerToken));
    }

    function test_PreCrimeSetAndGet() public {
        address newPreCrime = address(0x123);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit PreCrimeSet(newPreCrime);

        aSummerToken.setPreCrime(newPreCrime);
        assertEq(aSummerToken.preCrime(), newPreCrime);
    }

    function test_SetPeer() public {
        bytes32 newPeer = bytes32(uint256(uint160(address(0xBEEF))));
        uint32 targetEid = 123;

        // Only owner can set peer
        address nonOwner = address(0xdead);
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        aSummerToken.setPeer(targetEid, newPeer);

        // Owner can set peer
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit PeerSet(targetEid, newPeer);
        aSummerToken.setPeer(targetEid, newPeer);

        // Verify peer was set correctly
        assertEq(aSummerToken.peers(targetEid), newPeer);

        // Can set peer to zero to remove it
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit PeerSet(targetEid, bytes32(0));
        aSummerToken.setPeer(targetEid, bytes32(0));

        // Verify peer was removed
        assertEq(aSummerToken.peers(targetEid), bytes32(0));
    }

    function test_GetPeerOrRevert() public {
        uint32 targetEid = 123;
        bytes32 newPeer = bytes32(uint256(uint160(address(0xBEEF))));

        // Should revert when peer is not set
        vm.expectRevert(abi.encodeWithSignature("NoPeer(uint32)", targetEid));
        aSummerToken.exposed_getPeerOrRevert(targetEid);

        // Set the peer
        vm.prank(owner);
        aSummerToken.setPeer(targetEid, newPeer);

        // Should return peer when set
        bytes32 retrievedPeer = aSummerToken.exposed_getPeerOrRevert(targetEid);
        assertEq(retrievedPeer, newPeer);

        // Remove the peer
        vm.prank(owner);
        aSummerToken.setPeer(targetEid, bytes32(0));

        // Should revert again after peer is removed
        vm.expectRevert(abi.encodeWithSignature("NoPeer(uint32)", targetEid));
        aSummerToken.exposed_getPeerOrRevert(targetEid);
    }
}

contract InvalidDecimalsSummerToken is SummerToken {
    constructor(
        ISummerToken.ConstructorParams memory params
    ) SummerToken(params) {}

    // Override decimals to return 5 (less than shared decimals of 6)
    function decimals() public pure override returns (uint8) {
        return 5;
    }
}
