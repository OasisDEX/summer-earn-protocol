// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {ISummerToken, IERC20} from "../../src/interfaces/ISummerToken.sol";
import {IGovernanceRewardsManager} from "../../src/interfaces/IGovernanceRewardsManager.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
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
    }

    function test_InitialSupply() public view {
        assertEq(aSummerToken.totalSupply(), INITIAL_SUPPLY * 10 ** 18);
        assertEq(bSummerToken.totalSupply(), 0); // bSummerToken is initialized with 0 supply
    }

    function test_OwnerBalance() public view {
        assertEq(aSummerToken.balanceOf(owner), INITIAL_SUPPLY * 10 ** 18);
        assertEq(bSummerToken.balanceOf(owner), 0); // bSummerToken is initialized with 0 supply
    }

    function test_TokenNameAndSymbol() public view {
        assertEq(aSummerToken.name(), "SummerToken A");
        assertEq(aSummerToken.symbol(), "SUMMERA");
        assertEq(bSummerToken.name(), "SummerToken B");
        assertEq(bSummerToken.symbol(), "SUMMERB");
    }

    function test_Transfer() public {
        enableTransfers();
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.transfer(user1, amount);
        assertEq(aSummerToken.balanceOf(user1), amount);
        assertEq(
            aSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );

        bSummerToken.mint(owner, amount * 2); // bSummerToken is initialized with 0 supply, so we need to mint to test transfer
        bSummerToken.transfer(user2, amount);
        assertEq(bSummerToken.balanceOf(user2), amount);
        assertEq(bSummerToken.balanceOf(owner), amount);
    }

    function test_TransfersBlockedByDefault() public {
        uint256 amount = 1000 * 10 ** 18;
        vm.expectRevert(ISummerToken.TransferNotAllowed.selector);
        aSummerToken.transfer(user1, amount);
    }

    function testFail_TransferInsufficientBalance() public {
        enableTransfers();
        uint256 amount = (INITIAL_SUPPLY + 1) * 10 ** 18;
        aSummerToken.transfer(user1, amount);
        bSummerToken.transfer(user2, amount);
    }

    function test_ApproveAndTransferFrom() public {
        enableTransfers();
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount);
        assertEq(aSummerToken.allowance(owner, user1), amount);

        vm.prank(user1);
        aSummerToken.transferFrom(owner, user2, amount);
        assertEq(aSummerToken.balanceOf(user2), amount);
        assertEq(aSummerToken.allowance(owner, user1), 0);

        bSummerToken.approve(user1, amount);
        assertEq(bSummerToken.allowance(owner, user1), amount);

        // bSummerToken is initialized with 0 supply, so we need to mint to test transferFrom
        bSummerToken.mint(owner, amount);

        vm.prank(user1);
        bSummerToken.transferFrom(owner, user2, amount);
        assertEq(bSummerToken.balanceOf(user2), amount);
        assertEq(bSummerToken.allowance(owner, user1), 0);
    }

    function testFail_TransferFromInsufficientAllowance() public {
        enableTransfers();
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        aSummerToken.transferFrom(owner, user2, amount);

        bSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        bSummerToken.transferFrom(owner, user2, amount);
    }

    function test_Burn() public {
        enableTransfers();
        uint256 amount = 1000 * 10 ** 18;
        uint256 initialSupplyA = aSummerToken.totalSupply();

        bSummerToken.mint(owner, amount); // bSummerToken is initialized with 0 supply, so we need to mint to test burn
        uint256 initialSupplyB = bSummerToken.totalSupply();

        aSummerToken.burn(amount);
        assertEq(aSummerToken.balanceOf(owner), initialSupplyA - amount);
        assertEq(aSummerToken.totalSupply(), initialSupplyA - amount);

        bSummerToken.burn(amount);
        assertEq(bSummerToken.balanceOf(owner), initialSupplyB - amount);
        assertEq(bSummerToken.totalSupply(), initialSupplyB - amount);
    }

    function testFail_BurnInsufficientBalance() public {
        enableTransfers();
        uint256 amount = (INITIAL_SUPPLY + 1) * 10 ** 18;
        aSummerToken.burn(amount);
        bSummerToken.burn(amount);
    }

    function test_BurnFrom() public {
        enableTransfers();
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

        bSummerToken.mint(owner, amount * 2); // bSummerToken is initialized with 0 supply, so we need to mint to test burnFrom
        bSummerToken.approve(user1, amount);

        vm.prank(user1);
        bSummerToken.burnFrom(owner, amount);

        assertEq(bSummerToken.balanceOf(owner), amount);
        assertEq(bSummerToken.totalSupply(), amount);
        assertEq(bSummerToken.allowance(owner, user1), 0);
    }

    function testFail_BurnFromInsufficientAllowance() public {
        enableTransfers();
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        aSummerToken.burnFrom(owner, amount);

        bSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        bSummerToken.burnFrom(owner, amount);
    }

    function test_VotingUnitsAfterUnstake() public {
        enableTransfers();

        uint256 amount = 100 ether;
        uint256 partialStakeAmount = 40 ether;
        uint256 unstakeAmount = 60 ether;

        // Setup: Transfer tokens to user1
        aSummerToken.transfer(user1, amount);

        // Initialize voting decay for user2
        vm.prank(user2);
        aSummerToken.delegate(address(0));

        vm.startPrank(user1);

        // 1. Delegate to user2 first
        aSummerToken.delegate(user2);
        assertEq(
            aSummerToken.getVotes(user2),
            amount,
            "Initial voting power should match full amount"
        );

        // 2. Approve and partial stake
        aSummerToken.approve(aSummerToken.rewardsManager(), amount);
        IGovernanceRewardsManager(aSummerToken.rewardsManager()).stake(
            partialStakeAmount
        );

        // Verify state after partial stake
        assertEq(
            IGovernanceRewardsManager(aSummerToken.rewardsManager()).balanceOf(
                user1
            ),
            partialStakeAmount,
            "Partial amount should be staked"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            amount - partialStakeAmount,
            "Remaining tokens should be in wallet"
        );
        assertEq(
            aSummerToken.getVotes(user2),
            amount,
            "Voting power should remain unchanged after partial stake"
        );

        // 3. Stake remaining amount
        IGovernanceRewardsManager(aSummerToken.rewardsManager()).stake(
            amount - partialStakeAmount
        );

        // Verify state after full stake
        assertEq(
            IGovernanceRewardsManager(aSummerToken.rewardsManager()).balanceOf(
                user1
            ),
            amount,
            "All tokens should be staked"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            0,
            "Wallet should be empty after full stake"
        );
        assertEq(
            aSummerToken.getVotes(user2),
            amount,
            "Voting power should remain unchanged after full stake"
        );

        // 4. Unstake partial amount
        IGovernanceRewardsManager(aSummerToken.rewardsManager()).unstake(
            unstakeAmount
        );

        // Verify final state
        assertEq(
            IGovernanceRewardsManager(aSummerToken.rewardsManager()).balanceOf(
                user1
            ),
            amount - unstakeAmount,
            "Staked balance should reflect unstaking"
        );
        assertEq(
            aSummerToken.balanceOf(user1),
            unstakeAmount,
            "Wallet balance should contain unstaked amount"
        );
        assertEq(
            aSummerToken.getVotes(user2),
            amount,
            "Voting power should remain unchanged after unstake"
        );
        assertEq(
            aSummerToken.delegates(user1),
            user2,
            "Delegation should remain unchanged"
        );

        vm.stopPrank();
    }

    function test_VotingDecayWithGetVotes() public {
        enableTransfers();

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
        uint256 decayPeriod = aSummerToken.getDecayFreeWindow() + 30 days;
        vm.warp(block.timestamp + decayPeriod);
        vm.roll(block.number + 1000);

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

    function test_WhitelistTransfers() public {
        uint256 amount = 1000 * 10 ** 18;

        // Add user1 to whitelist
        aSummerToken.addToWhitelist(user1);

        // Transfer should succeed to whitelisted address
        aSummerToken.transfer(user1, amount);
        assertEq(aSummerToken.balanceOf(user1), amount);

        // Transfer from whitelisted address should also succeed
        vm.prank(user1);
        aSummerToken.transfer(user2, amount / 2);
        assertEq(aSummerToken.balanceOf(user2), amount / 2);
    }

    function test_RemoveFromWhitelist() public {
        uint256 amount = 1000 * 10 ** 18;

        // Add and then remove user1 from whitelist
        aSummerToken.addToWhitelist(user1);
        aSummerToken.removeFromWhitelist(user1);

        // Transfer should fail after removal from whitelist
        vm.expectRevert(ISummerToken.TransferNotAllowed.selector);
        aSummerToken.transfer(user1, amount);
    }

    function test_OnlyGovernorCanManageWhitelist() public {
        // Try to add to whitelist as non-owner
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", user1)
        );
        aSummerToken.addToWhitelist(user2);

        // Try to remove from whitelist as non-owner
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", user1)
        );
        aSummerToken.removeFromWhitelist(user2);
    }

    function test_WhitelistEvents() public {
        // Test whitelist addition event
        vm.expectEmit(true, false, false, false);
        emit ISummerToken.AddressWhitelisted(user1);
        aSummerToken.addToWhitelist(user1);

        // Test whitelist removal event
        vm.expectEmit(true, false, false, false);
        emit ISummerToken.AddressRemovedFromWhitelist(user1);
        aSummerToken.removeFromWhitelist(user1);
    }

    // Update existing transfer tests to use whitelist instead of enableTransfers
    function test_Transfer_WithWhitelist() public {
        aSummerToken.addToWhitelist(user1);
        aSummerToken.addToWhitelist(user2);

        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.transfer(user1, amount);
        assertEq(aSummerToken.balanceOf(user1), amount);
        assertEq(
            aSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );

        bSummerToken.mint(owner, amount * 2); // bSummerToken is initialized with 0 supply, so we need to mint to test transfer
        bSummerToken.addToWhitelist(user2);
        bSummerToken.transfer(user2, amount);
        assertEq(bSummerToken.balanceOf(user2), amount);
        assertEq(bSummerToken.balanceOf(owner), amount);
    }

    function test_DelegationChainLength() public {
        enableTransfers();

        // Setup initial tokens
        uint256 amount = 100 ether;
        aSummerToken.transfer(user1, amount);
        aSummerToken.transfer(user2, amount);

        // Test case 1: Self-delegation (length should be 0)
        vm.prank(user1);
        aSummerToken.delegate(user1);
        assertEq(
            aSummerToken.getDelegationChainLength(user1),
            0,
            "Self-delegation should have length 0"
        );

        // Test case 2: Single delegation (length should be 1)
        vm.prank(user1);
        aSummerToken.delegate(user2);
        assertEq(
            aSummerToken.getDelegationChainLength(user1),
            1,
            "Single delegation should have length 1"
        );

        // Test case 3: Chain delegation (length should be 2)
        address user3 = address(0x3);
        vm.prank(user2);
        aSummerToken.delegate(user3);
        assertEq(
            aSummerToken.getDelegationChainLength(user1),
            2,
            "Two-step delegation should have length 2"
        );

        // Test case 5: Zero address delegation
        vm.prank(user1);
        aSummerToken.delegate(address(0));
        assertEq(
            aSummerToken.getDelegationChainLength(user1),
            0,
            "Zero address delegation should have length 0"
        );
    }

    function test_DelegateOnlyAllowedOnHubChain() public {
        // Setup: Give user1 some tokens using deal
        deal(address(aSummerToken), user1, 100 ether);

        // Switch to a non-hub chain
        vm.chainId(999);

        // Get the hubChainId from the token contract
        uint256 hubChainId = aSummerToken.hubChainId();

        // Attempt to delegate on wrong chain - should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerToken.NotHubChain.selector,
                999,
                hubChainId
            )
        );
        vm.prank(user1);
        aSummerToken.delegate(user2);

        // Restore original chain ID
        vm.chainId(hubChainId);

        // Verify delegation works on hub chain
        vm.prank(user1);
        aSummerToken.delegate(user2);
        assertEq(
            aSummerToken.delegates(user1),
            user2,
            "Delegation should succeed on hub chain"
        );
    }
}
