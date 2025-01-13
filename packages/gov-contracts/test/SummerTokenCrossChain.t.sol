// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../src/interfaces/ISummerToken.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {OFTComposerMock, SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Test, console} from "forge-std/Test.sol";

contract SummerTokenCrossChainTest is SummerTokenTestBase {
    using OptionsBuilder for bytes;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public virtual override {
        super.setUp();
    }

    function test_OFTSendNoCompose() public {
        enableTransfers();
        uint256 tokensToSend = 1 ether;
        aSummerToken.transfer(user1, tokensToSend);
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(user2),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        console.log(
            "aSummerToken.balanceOf(user1)",
            aSummerToken.balanceOf(user1)
        );
        assertEq(aSummerToken.balanceOf(user1), tokensToSend);
        assertEq(bSummerToken.balanceOf(user2), 0);

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(bSummerToken)));

        assertEq(aSummerToken.balanceOf(user1), 0);
        assertEq(bSummerToken.balanceOf(user2), tokensToSend);
    }

    function test_OFTSendWithCompose() public {
        enableTransfers();
        uint256 tokensToSend = 1 ether;
        aSummerToken.transfer(user1, tokensToSend);

        // Deploy a mock composer contract
        OFTComposerMock composer = new OFTComposerMock();

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 500000, 0);
        bytes memory composeMsg = hex"1234";
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(address(composer)),
            tokensToSend,
            tokensToSend,
            options,
            composeMsg,
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        assertEq(aSummerToken.balanceOf(user1), tokensToSend);
        assertEq(bSummerToken.balanceOf(address(composer)), 0);

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        ) = aSummerToken.send{value: fee.nativeFee}(
                sendParam,
                fee,
                payable(address(this))
            );
        verifyPackets(bEid, addressToBytes32(address(bSummerToken)));

        // lzCompose params
        uint32 dstEid_ = bEid;
        address from_ = address(bSummerToken);
        bytes memory options_ = options;
        bytes32 guid_ = msgReceipt.guid;
        address to_ = address(composer);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            msgReceipt.nonce,
            aEid,
            oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(user1), composeMsg)
        );
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertEq(aSummerToken.balanceOf(user1), 0);
        assertEq(bSummerToken.balanceOf(address(composer)), tokensToSend);

        assertEq(composer.from(), from_);
        assertEq(composer.guid(), guid_);
        assertEq(composer.message(), composerMsg_);
        assertEq(composer.executor(), address(this));
        assertEq(composer.extraData(), composerMsg_);
    }

    function test_VotingPowerAfterTeleport() public {
        enableTransfers();
        vm.deal(user1, 100 ether);

        // Transfer tokens to user1
        uint256 tokensToSend = 100 ether;
        aSummerToken.transfer(user1, tokensToSend);

        // Check initial voting power
        vm.prank(user1);
        aSummerToken.delegate(user1);

        vm.warp(block.timestamp + 100000);
        vm.roll(block.number + 100000);

        uint256 initialVotingPower = aSummerToken.getVotes(user1);
        assertEq(
            initialVotingPower,
            tokensToSend,
            "Initial voting power should match transferred tokens"
        );

        // Prepare for teleport
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(user2),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        // Teleport tokens
        vm.prank(user1);
        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(bSummerToken)));

        // Check voting power after teleport
        uint256 finalVotingPower = aSummerToken.getVotes(user1);
        assertEq(
            finalVotingPower,
            0,
            "Voting power should be zero after teleport"
        );

        // Verify tokens arrived at destination
        assertEq(
            bSummerToken.balanceOf(user2),
            tokensToSend,
            "Tokens should have arrived at destination"
        );
    }

    function test_CrossChainWhitelist() public {
        uint256 tokensToSend = 1 ether;
        deal(address(aSummerToken), user1, tokensToSend);

        // Add user2 to the whitelist
        aSummerToken.addToWhitelist(user2);

        // Prepare SendParam for a whitelisted address
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(user2),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        // Attempt to send tokens to a whitelisted address
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );

        // Verify tokens were sent (only on source chain for testing convenience)
        assertEq(aSummerToken.balanceOf(user1), 0);

        // Remove user2 from the whitelist
        aSummerToken.removeFromWhitelist(user2);

        // Attempt to send tokens to a non-whitelisted address should revert
        vm.prank(user1);
        vm.expectRevert(ISummerToken.TransferNotAllowed.selector);
        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );
    }

    function test_CrossChainTransfer_InsufficientBalance() public {
        uint256 tokensToSend = 2 ether; // More than what user has
        deal(address(aSummerToken), user1, 1 ether);

        aSummerToken.addToWhitelist(user2);

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(user2),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        vm.deal(user1, 1 ether);
        vm.prank(user1);

        // Expect the specific ERC20InsufficientBalance error with correct parameters
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                user1, // account
                1 ether, // balance
                2 ether
            )
        );

        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );
    }

    function test_CrossChainTransfer_InsufficientFee() public {
        uint256 tokensToSend = 1 ether;
        deal(address(aSummerToken), user1, tokensToSend);

        aSummerToken.addToWhitelist(user2);

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(user2),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        vm.deal(user1, fee.nativeFee / 2); // Only half the required fee
        vm.prank(user1);
        vm.expectRevert(); // Should revert due to insufficient fee
        aSummerToken.send{value: fee.nativeFee / 2}(
            sendParam,
            fee,
            payable(address(this))
        );
    }

    function test_CrossChainTransfer_InvalidDestination() public {
        uint256 tokensToSend = 1 ether;
        deal(address(aSummerToken), user1, tokensToSend);

        aSummerToken.addToWhitelist(user2);

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            999, // Invalid EID
            addressToBytes32(user2),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(); // Should revert due to invalid destination
        aSummerToken.send{value: 1 ether}(
            sendParam,
            MessagingFee(1 ether, 0),
            payable(address(this))
        );
    }
}
