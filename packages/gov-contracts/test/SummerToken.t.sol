// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../src/contracts/SummerToken.sol";
import {ISummerToken} from "../src/interfaces/ISummerToken.sol";

import {EnforcedOptionParam, IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {OFTComposerMock, SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Test, console} from "forge-std/Test.sol";

contract SummerTokenTest is SummerTokenTestBase {
    using OptionsBuilder for bytes;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public virtual override {
        super.setUp();
        mintTokens();
    }

    function mintTokens() public {
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        aSummerToken.mint(address(this), INITIAL_SUPPLY * 10 ** 18);
        bSummerToken.mint(address(this), INITIAL_SUPPLY * 10 ** 18);
    }

    // ===============================================
    // Cross-Chain Tests
    // ===============================================

    function test_OFTSendNoCompose() public {
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

    // ===============================================
    // Token Tests
    // ===============================================

    function test_InitialSupply() public view {
        assertEq(aSummerToken.totalSupply(), INITIAL_SUPPLY * 10 ** 18);
        assertEq(bSummerToken.totalSupply(), INITIAL_SUPPLY * 10 ** 18);
    }

    function test_OwnerBalance() public view {
        assertEq(aSummerToken.balanceOf(owner), INITIAL_SUPPLY * 10 ** 18);
        assertEq(bSummerToken.balanceOf(owner), INITIAL_SUPPLY * 10 ** 18);
    }

    function test_TokenNameAndSymbol() public view {
        assertEq(aSummerToken.name(), "SummerToken A");
        assertEq(aSummerToken.symbol(), "SUMMERA");
        assertEq(bSummerToken.name(), "SummerToken B");
        assertEq(bSummerToken.symbol(), "SUMMERB");
    }

    function test_Transfer() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.transfer(user1, amount);
        assertEq(aSummerToken.balanceOf(user1), amount);
        assertEq(
            aSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );

        bSummerToken.transfer(user2, amount);
        assertEq(bSummerToken.balanceOf(user2), amount);
        assertEq(
            bSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
    }

    function testFail_TransferInsufficientBalance() public {
        uint256 amount = (INITIAL_SUPPLY + 1) * 10 ** 18;
        aSummerToken.transfer(user1, amount);
        bSummerToken.transfer(user2, amount);
    }

    function test_ApproveAndTransferFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount);
        assertEq(aSummerToken.allowance(owner, user1), amount);

        vm.prank(user1);
        aSummerToken.transferFrom(owner, user2, amount);
        assertEq(aSummerToken.balanceOf(user2), amount);
        assertEq(aSummerToken.allowance(owner, user1), 0);

        bSummerToken.approve(user1, amount);
        assertEq(bSummerToken.allowance(owner, user1), amount);

        vm.prank(user1);
        bSummerToken.transferFrom(owner, user2, amount);
        assertEq(bSummerToken.balanceOf(user2), amount);
        assertEq(bSummerToken.allowance(owner, user1), 0);
    }

    function testFail_TransferFromInsufficientAllowance() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        aSummerToken.transferFrom(owner, user2, amount);

        bSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        bSummerToken.transferFrom(owner, user2, amount);
    }

    function test_Burn() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 initialSupplyA = aSummerToken.totalSupply();
        uint256 initialSupplyB = bSummerToken.totalSupply();

        aSummerToken.burn(amount);
        assertEq(aSummerToken.balanceOf(owner), initialSupplyA - amount);
        assertEq(aSummerToken.totalSupply(), initialSupplyA - amount);

        bSummerToken.burn(amount);
        assertEq(bSummerToken.balanceOf(owner), initialSupplyB - amount);
        assertEq(bSummerToken.totalSupply(), initialSupplyB - amount);
    }

    function testFail_BurnInsufficientBalance() public {
        uint256 amount = (INITIAL_SUPPLY + 1) * 10 ** 18;
        aSummerToken.burn(amount);
        bSummerToken.burn(amount);
    }

    function test_BurnFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount);

        vm.prank(user1);
        aSummerToken.burnFrom(owner, amount);

        assertEq(
            aSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(
            aSummerToken.totalSupply(),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(aSummerToken.allowance(owner, user1), 0);

        bSummerToken.approve(user1, amount);

        vm.prank(user1);
        bSummerToken.burnFrom(owner, amount);

        assertEq(
            bSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(
            bSummerToken.totalSupply(),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(bSummerToken.allowance(owner, user1), 0);
    }

    function testFail_BurnFromInsufficientAllowance() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        aSummerToken.burnFrom(owner, amount);

        bSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        bSummerToken.burnFrom(owner, amount);
    }

    function test_VotingUnitsAfterUnstake() public {
        uint256 amount = 100 ether;
        uint256 unstakeAmount = 60 ether;

        // Setup: Transfer tokens to user1
        aSummerToken.transfer(user1, amount);

        // Initialise voting decay for user2
        vm.prank(user2);
        aSummerToken.delegate(address(0));

        // 1. delegate and stake
        vm.startPrank(user1);
        aSummerToken.approve(address(aSummerToken.rewardsManager()), amount);
        aSummerToken.delegate(user2);
        aSummerToken.rewardsManager().stake(amount);

        // Verify initial state after stake
        assertEq(
            aSummerToken.rewardsManager().balanceOf(user1),
            amount,
            "All tokens should be staked initially"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            0,
            "Wallet should be empty after full stake"
        );

        // 2. Direct unstake of partial amount
        aSummerToken.rewardsManager().unstake(unstakeAmount);
        vm.stopPrank();

        // 3. Verify voting units includes both staked and wallet balance
        uint256 expectedVotingUnits = amount; // Total voting power should remain the same
        assertEq(
            aSummerToken.getVotes(user2),
            expectedVotingUnits,
            "Voting units should include both staked and unstaked balances"
        );

        // Verify individual components
        assertEq(
            aSummerToken.rewardsManager().balanceOf(user1),
            amount - unstakeAmount,
            "Staked balance should reflect unstaking"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            unstakeAmount,
            "Wallet balance should contain unstaked amount"
        );
        assertEq(
            aSummerToken.delegates(user1),
            user2,
            "Delegation should remain unchanged"
        );
    }

    function test_VotingDecayWithGetVotes() public {
        // Setup initial tokens and delegation
        uint256 initialAmount = 100 ether;
        aSummerToken.transfer(user1, initialAmount);

        vm.startPrank(user1);
        aSummerToken.delegate(user1);
        vm.stopPrank();

        // Move forward one block to ensure delegation is active
        vm.roll(block.number + 1);

        // Check initial voting power
        uint256 initialVotes = aSummerToken.getVotes(user1);

        assertEq(
            initialVotes,
            initialAmount,
            "Initial getVotes should match amount"
        );

        // Move time beyond decay window
        uint256 decayPeriod = aSummerToken.decayFreeWindow() + 30 days;
        vm.warp(block.timestamp + decayPeriod);
        vm.roll(block.number + 1000);

        // // Force decay update
        // vm.prank(address(mockGovernor));
        // aSummerToken.updateDecayFactor(user1);

        // Check current votes (should be decayed)
        uint256 currentVotes = aSummerToken.getVotes(user1);
        assertLt(
            currentVotes,
            initialAmount,
            "Current votes should be decayed"
        );

        // Log values for clarity
        console.log("Initial votes:", initialVotes);
        console.log("Current votes (decayed):", currentVotes);

        // Move time further to check continued decay
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1);

        uint256 furtherDecayedVotes = aSummerToken.getVotes(user1);
        assertLt(
            furtherDecayedVotes,
            currentVotes,
            "Votes should continue to decay over time"
        );

        // Force another decay update to halt further decay for the decay free window
        vm.prank(address(mockGovernor));
        aSummerToken.updateDecayFactor(user1);

        // Move time forward but not beyond the decay free window
        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 1);

        uint256 noDecayVotes = aSummerToken.getVotes(user1);
        assertEq(
            noDecayVotes,
            furtherDecayedVotes,
            "Votes should not decay during the decay free window"
        );
    }
}
