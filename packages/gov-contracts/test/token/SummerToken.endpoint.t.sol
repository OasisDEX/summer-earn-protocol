// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";

contract SummerTokenEndpointTest is SummerTokenTestBase {
    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes;

    address public delegate;
    bytes32 public guid;
    bytes public message;
    bytes32 public payloadHash;

    function setUp() public virtual override {
        super.setUp();
        delegate = makeAddr("delegate");
        message = "test message";
        guid = keccak256("guid");
        payloadHash = keccak256(abi.encodePacked(guid, message));
    }

    function test_SetDelegate() public {
        address nonOwner = address(0xdead);

        // Only owner can set delegate
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                nonOwner
            )
        );
        aSummerToken.setDelegate(delegate);

        // Owner can set delegate
        vm.prank(owner);
        aSummerToken.setDelegate(delegate);

        // Can set delegate to zero address
        vm.prank(owner);
        aSummerToken.setDelegate(address(0));
    }

    function test_Send() public {
        enableTransfers();

        uint256 amount = 100 ether;
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam(
            bEid,
            OFTMsgCodec.addressToBytes32(address(bSummerToken)),
            amount,
            (amount * 9900) / 10000, // 1% slippage
            options,
            "",
            ""
        );

        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        vm.deal(address(this), fee.nativeFee);
        (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        ) = aSummerToken.send{value: fee.nativeFee}(
                sendParam,
                fee,
                payable(address(this))
            );

        assertEq(msgReceipt.fee.nativeFee, fee.nativeFee);
        assertEq(msgReceipt.fee.lzTokenFee, 0);
        assertEq(oftReceipt.amountSentLD, amount);
    }
}
