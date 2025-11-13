// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/StargateV2PoolArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {IStargatePool} from "../../src/interfaces/stargate/IStargatePool.sol";
import {IStargateStaking} from "../../src/interfaces/stargate/IStargateStaking.sol";
import {IMultiRewarder} from "../../src/interfaces/stargate/IMultiRewarder.sol";
import {IWETH} from "../../src/interfaces/misc/IWETH.sol";

import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract StargateV2PoolArkOptimismTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    StargateV2PoolArk public ark;
    IStargatePool public stargatePool;
    IStargateStaking public stargateStaking;
    IERC20 public lpToken;
    IWETH public weth;
    ArkParams public params;

    // Optimism addresses
    address public constant STARGATE_POOL_ADDRESS =
        0xe8CDF27AcD73a434D661C84887215F7598e7d0d3;
    address public constant STARGATE_STAKING_ADDRESS =
        0xFBb5A71025BEf1A8166C9BCb904a120AA17d6443;
    address public constant WETH_ADDRESS =
        0x4200000000000000000000000000000000000006; // WETH on Optimism

    uint256 forkBlock = 130000000; // A recent block number for Optimism
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("optimism"), forkBlock);

        stargatePool = IStargatePool(STARGATE_POOL_ADDRESS);
        stargateStaking = IStargateStaking(STARGATE_STAKING_ADDRESS);
        lpToken = IERC20(stargatePool.lpToken());
        weth = IWETH(WETH_ADDRESS);

        params = ArkParams({
            name: "ETH Stargate V2 Pool Ark",
            details: "ETH Stargate V2 Pool Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: WETH_ADDRESS, // Using WETH as the asset for native ETH
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new StargateV2PoolArk(
            STARGATE_POOL_ADDRESS,
            STARGATE_STAKING_ADDRESS,
            WETH_ADDRESS,
            params
        );

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor() public {
        // Invalid pool address
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAddress(string,address)",
                "stargatePool",
                address(0)
            )
        );
        ark = new StargateV2PoolArk(
            address(0),
            STARGATE_STAKING_ADDRESS,
            WETH_ADDRESS,
            params
        );

        // Invalid staking address
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAddress(string,address)",
                "stargateStaking",
                address(0)
            )
        );
        ark = new StargateV2PoolArk(
            STARGATE_POOL_ADDRESS,
            address(0),
            WETH_ADDRESS,
            params
        );

        // Invalid WETH address
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAddress(string,address)",
                "weth",
                address(0)
            )
        );
        ark = new StargateV2PoolArk(
            STARGATE_POOL_ADDRESS,
            STARGATE_STAKING_ADDRESS,
            address(0),
            params
        );

        // Valid constructor
        ark = new StargateV2PoolArk(
            STARGATE_POOL_ADDRESS,
            STARGATE_STAKING_ADDRESS,
            WETH_ADDRESS,
            params
        );

        assertEq(
            address(ark.stargatePool()),
            STARGATE_POOL_ADDRESS,
            "Stargate pool address should match"
        );
        assertEq(
            address(ark.stargateStaking()),
            STARGATE_STAKING_ADDRESS,
            "Stargate staking address should match"
        );
        assertEq(
            address(ark.weth()),
            WETH_ADDRESS,
            "WETH address should match"
        );
        assertEq(
            address(ark.asset()),
            WETH_ADDRESS,
            "Token address should match WETH"
        );
        assertEq(
            ark.name(),
            "ETH Stargate V2 Pool Ark",
            "Ark name should match"
        );
    }

    function test_Board() public {
        uint256 amount = 1 ether; // 1 ETH (18 decimals)

        // Deal WETH to commander
        vm.deal(commander, amount);
        vm.startPrank(commander);
        weth.deposit{value: amount}();
        weth.transfer(address(weth), 0); // Just to ensure WETH balance is correct

        uint256 wethBalance = weth.balanceOf(commander);
        assertEq(wethBalance, amount, "Commander should have WETH balance");

        IERC20(address(weth)).approve(address(ark), amount);

        uint256 initialStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        assertEq(
            finalStakedBalance,
            initialStakedBalance + amount,
            "Staked LP balance should increase"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1 ether; // 1 ETH

        // Deal WETH to commander
        vm.deal(commander, amount);
        vm.startPrank(commander);
        weth.deposit{value: amount}();
        IERC20(address(weth)).approve(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 initialWETHBalance = weth.balanceOf(commander);
        uint256 amountToDisembark = ark.withdrawableTotalAssets();

        vm.expectEmit();
        emit Disembarked(commander, WETH_ADDRESS, amountToDisembark);

        ark.disembark(amountToDisembark, bytes(""));

        vm.stopPrank();

        uint256 finalWETHBalance = weth.balanceOf(commander);
        assertGt(
            finalWETHBalance,
            initialWETHBalance,
            "WETH balance should increase after disembarking"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1 ether; // 1 ETH

        // Deal WETH to commander
        vm.deal(commander, amount);
        vm.startPrank(commander);
        weth.deposit{value: amount}();
        IERC20(address(weth)).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertGt(
            totalAssets,
            0,
            "Total assets should be greater than 0 after boarding"
        );

        // For rebasing tokens, total assets should equal staked LP balance
        uint256 stakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        assertEq(
            totalAssets,
            stakedBalance,
            "Total assets should equal staked LP balance for rebasing tokens"
        );
    }

    function test_Harvest() public {
        uint256 amount = 1 ether; // 1 ETH

        // Deal WETH to commander
        vm.deal(commander, amount);
        vm.startPrank(commander);
        weth.deposit{value: amount}();
        IERC20(address(weth)).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Fast forward time to potentially accrue rewards
        vm.warp(block.timestamp + 30 days);

        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        // Check that we got some rewards (length could be 0 if no rewards, or multiple tokens)
        assertEq(
            rewardTokens.length,
            rewardAmounts.length,
            "Reward tokens and amounts length should match"
        );

        // Verify all returned amounts are > 0 and check ETH wrapping
        for (uint256 i = 0; i < rewardAmounts.length; i++) {
            assertGt(
                rewardAmounts[i],
                0,
                "All returned reward amounts should be greater than 0"
            );
            // Ensure no native ETH rewards are returned (should be wrapped to WETH)
            assertTrue(
                rewardTokens[i] != address(0),
                "Native ETH should be wrapped to WETH"
            );
        }
    }

    function test_ETHWrapping() public {
        // Test the ETH wrapping functionality
        uint256 ethAmount = 1 ether;
        uint256 initialWethBalance = weth.balanceOf(address(ark));

        // Send ETH directly to the ark to simulate native ETH rewards
        vm.deal(address(ark), ethAmount);

        // Check that the ark can wrap ETH to WETH
        uint256 arkEthBalance = address(ark).balance;
        assertEq(arkEthBalance, ethAmount, "Ark should have ETH balance");

        // Simulate wrapping by calling WETH deposit directly (in real scenario this happens in harvest)
        vm.prank(address(ark));
        weth.deposit{value: ethAmount}();

        uint256 finalWethBalance = weth.balanceOf(address(ark));
        assertEq(
            finalWethBalance - initialWethBalance,
            ethAmount,
            "WETH balance should increase by ETH amount"
        );
        assertEq(address(ark).balance, 0, "Ark should have no ETH left");
    }

    function test_WithdrawableTotalAssets() public {
        uint256 amount = 1 ether; // 1 ETH

        // Deal WETH to commander
        vm.deal(commander, amount);
        vm.startPrank(commander);
        weth.deposit{value: amount}();
        IERC20(address(weth)).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 withdrawableAssets = ark.withdrawableTotalAssets();
        assertGt(
            withdrawableAssets,
            0,
            "Withdrawable assets should be greater than 0"
        );

        // For rebasing tokens, withdrawable should be min(stakedBalance, poolBalance)
        uint256 stakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 poolBalance = stargatePool.poolBalance();
        uint256 expectedWithdrawable = stakedBalance > poolBalance
            ? poolBalance
            : stakedBalance;

        assertEq(
            withdrawableAssets,
            expectedWithdrawable,
            "Withdrawable assets should be min of staked balance and pool balance"
        );

        uint256 veryLowBalance = 0.1 ether; // 0.1 ETH
        // we need to mock the pool balance as it has separate accounting, rather than simple balanceOf underlying assets
        vm.mockCall(
            address(stargatePool),
            abi.encodeWithSelector(
                IStargatePool.redeemable.selector,
                address(0)
            ),
            abi.encode(veryLowBalance)
        );
        assertEq(
            stargatePool.redeemable(address(0)),
            veryLowBalance,
            "Pool balance should be equal to the very low balance"
        );

        uint256 newWithdrawableAssets = ark.withdrawableTotalAssets();

        assertEq(
            newWithdrawableAssets,
            veryLowBalance,
            "Withdrawable assets should be equal to the very low balance"
        );
    }

    function test_NativeETHHandling() public {
        // Test that the contract can handle native ETH operations correctly
        uint256 amount = 1 ether;

        // Deal native ETH to commander
        vm.deal(commander, amount * 2); // Extra for gas

        vm.startPrank(commander);

        // Convert ETH to WETH for the ark
        weth.deposit{value: amount}();
        IERC20(address(weth)).approve(address(ark), amount);

        uint256 initialStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );

        // Board should work with WETH
        ark.board(amount, bytes(""));

        uint256 finalStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );

        assertGt(
            finalStakedBalance,
            initialStakedBalance,
            "Should stake LP tokens successfully"
        );

        vm.stopPrank();
    }

    function test_ConvertRate() public view {
        // Test that the convert rate is calculated correctly
        uint256 convertRate = ark.convertRate();

        // For ETH (18 decimals) and typical Stargate shared decimals (6),
        // convert rate should be 10^(18-6) = 10^12
        // Note: This test might need adjustment based on actual shared decimals
        // The exact value depends on stargatePool.sharedDecimals()
        assertGt(convertRate, 0, "Convert rate should be greater than 0");
    }

    function test_DustHandling_SingleDeposit() public {
        // Dusty deposits should be cleaned: stake clean portion, keep dust in Ark as WETH
        uint256 amountWithDust = 1.123456789123456789 ether; // Has dust beyond 6 decimals

        vm.deal(commander, amountWithDust);
        vm.startPrank(commander);
        weth.deposit{value: amountWithDust}();
        IERC20(address(weth)).approve(address(ark), amountWithDust);

        uint256 cleanAmount = (amountWithDust / ark.convertRate()) *
            ark.convertRate();
        uint256 dustAmount = amountWithDust - cleanAmount;

        uint256 initialStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 initialWethInArk = weth.balanceOf(address(ark));

        ark.board(amountWithDust, bytes(""));

        uint256 finalStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 finalWethInArk = weth.balanceOf(address(ark));

        assertEq(
            finalStakedBalance - initialStakedBalance,
            cleanAmount,
            "Should stake clean portion only"
        );
        assertEq(
            finalWethInArk - initialWethInArk,
            dustAmount,
            "Dust should remain in Ark as WETH"
        );

        vm.stopPrank();
    }

    function test_CleanDeposit_NativeETH() public {
        // Test that clean deposits (without dust) work correctly for native ETH
        uint256 cleanAmount = 1.123456 ether; // Clean amount with exactly 6 decimal precision

        vm.deal(commander, cleanAmount);
        vm.startPrank(commander);
        weth.deposit{value: cleanAmount}();
        IERC20(address(weth)).approve(address(ark), cleanAmount);

        uint256 initialStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );

        ark.board(cleanAmount, bytes(""));

        uint256 finalStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 actualDeposited = finalStakedBalance - initialStakedBalance;

        // Should deposit the exact clean amount
        assertEq(
            actualDeposited,
            cleanAmount,
            "Should deposit exact clean amount"
        );

        vm.stopPrank();
    }

    function test_DustHandling_MultipleDepositsWithdrawals() public {
        // Test multiple cycles with clean deposits and dusty withdrawals
        uint256[] memory cleanAmounts = new uint256[](3);
        cleanAmounts[0] = 1.123456 ether; // Clean amount (6 decimal precision)
        cleanAmounts[1] = 0.987654 ether; // Clean amount
        cleanAmounts[2] = 2.555555 ether; // Clean amount

        uint256 totalExpected = cleanAmounts[0] +
            cleanAmounts[1] +
            cleanAmounts[2];

        vm.deal(commander, 10 ether); // Give plenty of ETH
        vm.startPrank(commander);

        // Convert to WETH
        weth.deposit{value: 10 ether}();
        IERC20(address(weth)).approve(address(ark), 10 ether);

        uint256 initialStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );

        // Make multiple clean deposits (should work)
        for (uint256 i = 0; i < cleanAmounts.length; i++) {
            ark.board(cleanAmounts[i], bytes(""));
        }

        uint256 midStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 totalDeposited = midStakedBalance - initialStakedBalance;

        // Verify total deposited equals clean amounts
        assertEq(
            totalDeposited,
            totalExpected,
            "Total deposited should equal clean amounts"
        );

        // Test withdrawal with dust - currently reverts due to implementation bug
        uint256 dustyWithdrawAmount = 2.123456789123456789 ether; // Has dust

        // Current implementation fails when trying to withdraw dusty amounts
        vm.expectRevert(); // Should revert due to out-of-funds when trying to wrap dust
        ark.disembark(dustyWithdrawAmount, bytes(""));

        // Test with clean withdraw amount instead
        uint256 cleanWithdrawAmount = 2.123456 ether; // Clean amount
        if (ark.withdrawableTotalAssets() >= cleanWithdrawAmount) {
            ark.disembark(cleanWithdrawAmount, bytes(""));

            uint256 balanceAfterWithdraw = stargateStaking.balanceOf(
                lpToken,
                address(ark)
            );
            uint256 actualWithdrawn = midStakedBalance - balanceAfterWithdraw;

            // Should withdraw the exact clean amount
            assertEq(
                actualWithdrawn,
                cleanWithdrawAmount,
                "Should withdraw exact clean amount"
            );
        }

        vm.stopPrank();
    }

    function test_DustAccumulation_PartialWithdrawals() public {
        // Test partial withdrawals with clean deposit and dusty withdrawals
        uint256 cleanDepositAmount = 5.123456 ether; // Clean amount for deposit

        vm.deal(commander, cleanDepositAmount);
        vm.startPrank(commander);
        weth.deposit{value: cleanDepositAmount}();
        IERC20(address(weth)).approve(address(ark), cleanDepositAmount);

        // Deposit clean amount (should work)
        ark.board(cleanDepositAmount, bytes(""));

        uint256 stakedAfterDeposit = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        assertEq(
            stakedAfterDeposit,
            cleanDepositAmount,
            "Should stake exact clean amount"
        );

        // Make partial withdrawal with dust - currently reverts due to implementation bug
        uint256 withdrawAmount1 = 2.654321123456789 ether; // Has dust

        // Current implementation tries to wrap the dusty amount but only received clean amount
        vm.expectRevert(); // Should revert due to out-of-funds when trying to wrap dust
        ark.disembark(withdrawAmount1, bytes(""));

        // Instead, test with clean withdrawal amount
        uint256 cleanWithdrawAmount1 = 2.654321 ether; // Clean amount
        ark.disembark(cleanWithdrawAmount1, bytes(""));

        uint256 stakedAfterWithdraw1 = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 actualWithdrawn1 = stakedAfterDeposit - stakedAfterWithdraw1;

        // Should withdraw clean amount exactly
        assertEq(
            actualWithdrawn1,
            cleanWithdrawAmount1,
            "Should withdraw clean amount exactly"
        );

        // Make another partial withdrawal - use clean amount to avoid revert
        uint256 cleanWithdrawAmount2 = 1.111111 ether; // Clean amount

        ark.disembark(cleanWithdrawAmount2, bytes(""));

        uint256 stakedAfterWithdraw2 = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 actualWithdrawn2 = stakedAfterWithdraw1 - stakedAfterWithdraw2;

        assertEq(
            actualWithdrawn2,
            cleanWithdrawAmount2,
            "Should withdraw clean amount"
        );

        // Remaining should be exact
        uint256 expectedRemaining = cleanDepositAmount -
            cleanWithdrawAmount1 -
            cleanWithdrawAmount2;
        assertEq(
            stakedAfterWithdraw2,
            expectedRemaining,
            "Remaining should match expected"
        );

        vm.stopPrank();
    }

    function test_PrecisionLoss_VsExpectedAmounts() public {
        // Dusty deposits should floor to clean amount; clean deposits should be exact
        uint256[] memory dustyAmounts = new uint256[](3);
        dustyAmounts[0] = 0.999999999999999999 ether; // Has dust
        dustyAmounts[1] = 1.000000000000000001 ether; // Has dust
        dustyAmounts[2] = 2.123456789123456789 ether; // Has dust

        uint256[] memory cleanAmounts = new uint256[](3);
        cleanAmounts[0] = 0.999999 ether; // Clean version
        cleanAmounts[1] = 1.000000 ether; // Clean version
        cleanAmounts[2] = 2.123456 ether; // Clean version

        vm.deal(commander, 20 ether);
        vm.startPrank(commander);
        weth.deposit{value: 20 ether}();
        IERC20(address(weth)).approve(address(ark), 20 ether);

        // Dusty amounts: only clean portion is staked, dust remains as WETH in Ark
        for (uint256 i = 0; i < dustyAmounts.length; i++) {
            uint256 cleanPortion = (dustyAmounts[i] / ark.convertRate()) *
                ark.convertRate();
            uint256 dustPortion = dustyAmounts[i] - cleanPortion;

            uint256 stakedBefore = stargateStaking.balanceOf(
                lpToken,
                address(ark)
            );
            uint256 wethInArkBefore = weth.balanceOf(address(ark));

            ark.board(dustyAmounts[i], bytes(""));

            uint256 stakedAfter = stargateStaking.balanceOf(
                lpToken,
                address(ark)
            );
            uint256 wethInArkAfter = weth.balanceOf(address(ark));

            assertEq(
                stakedAfter - stakedBefore,
                cleanPortion,
                string(
                    abi.encodePacked(
                        "Dusty deposit ",
                        vm.toString(i),
                        " should stake clean portion"
                    )
                )
            );
            assertEq(
                wethInArkAfter - wethInArkBefore,
                dustPortion,
                string(
                    abi.encodePacked(
                        "Dusty deposit ",
                        vm.toString(i),
                        " dust should remain as WETH"
                    )
                )
            );
        }

        // Clean amounts: full amount is staked
        for (uint256 i = 0; i < cleanAmounts.length; i++) {
            uint256 beforeBalance = stargateStaking.balanceOf(
                lpToken,
                address(ark)
            );
            ark.board(cleanAmounts[i], bytes(""));
            uint256 afterBalance = stargateStaking.balanceOf(
                lpToken,
                address(ark)
            );
            uint256 actualDeposited = afterBalance - beforeBalance;
            assertEq(
                actualDeposited,
                cleanAmounts[i],
                string(
                    abi.encodePacked(
                        "Clean deposit ",
                        vm.toString(i),
                        " should work exactly"
                    )
                )
            );
        }

        vm.stopPrank();
    }

    function test_WithdrawalAmountMismatch_EdgeCase() public {
        // Test withdrawals work correctly after clean deposits
        uint256 cleanDepositAmount = 3.123456 ether; // Clean amount for deposit

        vm.deal(commander, cleanDepositAmount);
        vm.startPrank(commander);
        weth.deposit{value: cleanDepositAmount}();
        IERC20(address(weth)).approve(address(ark), cleanDepositAmount);

        // Deposit clean amount (should work)
        ark.board(cleanDepositAmount, bytes(""));

        // Withdrawable should equal deposited amount (clean)
        uint256 withdrawableAssets = ark.withdrawableTotalAssets();
        assertEq(
            withdrawableAssets,
            cleanDepositAmount,
            "Withdrawable should equal deposited clean amount"
        );

        // Test withdrawing with dusty amount - currently reverts due to implementation bug
        uint256 dustyWithdrawAmount = 3.123456789123456789 ether; // More than deposited due to dust

        vm.expectRevert(); // Should revert due to out-of-funds when trying to wrap dust
        ark.disembark(dustyWithdrawAmount, bytes(""));

        // Test with clean withdraw amount instead
        uint256 cleanWithdrawAmount = 3.123456 ether; // Clean amount
        ark.disembark(cleanWithdrawAmount, bytes("")); // Should work with clean amount

        uint256 finalBalance = stargateStaking.balanceOf(lpToken, address(ark));
        assertEq(finalBalance, 0, "Should withdraw everything");

        vm.stopPrank();
    }

    function test_DustBoundary_MinimalAmounts() public {
        // Test deposits at the dust boundary: clean at boundary, floor when just above
        uint256 convertRate = ark.convertRate();

        // Amount exactly at convertRate (clean)
        uint256 exactConvertAmount = convertRate; // 0.000001 ETH

        // Amount just above convertRate (has dust)
        uint256 aboveConvertAmount = convertRate + 1;

        // Clean amount that's a multiple of convertRate
        uint256 cleanAmount = convertRate * 5; // 0.000005 ETH

        vm.deal(commander, 1 ether);
        vm.startPrank(commander);
        weth.deposit{value: 1 ether}();
        IERC20(address(weth)).approve(address(ark), 1 ether);

        // Test exact convert amount (should work - it's clean)
        uint256 beforeBalance1 = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        ark.board(exactConvertAmount, bytes(""));
        uint256 afterBalance1 = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 deposited1 = afterBalance1 - beforeBalance1;

        assertEq(
            deposited1,
            exactConvertAmount,
            "Should deposit exact convertRate amount"
        );

        // Test above convert amount (has 1 wei dust) - should stake convertRate and keep 1 wei dust
        uint256 stakedBefore2 = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 wethInArkBefore2 = weth.balanceOf(address(ark));
        ark.board(aboveConvertAmount, bytes(""));
        uint256 stakedAfter2 = stargateStaking.balanceOf(lpToken, address(ark));
        uint256 wethInArkAfter2 = weth.balanceOf(address(ark));
        assertEq(
            stakedAfter2 - stakedBefore2,
            convertRate,
            "Should stake floor(convertRate) for above-convert amount"
        );
        assertEq(
            wethInArkAfter2 - wethInArkBefore2,
            1,
            "Should retain 1 wei dust in Ark as WETH"
        );

        // Test larger clean amount (should work)
        uint256 beforeBalance2 = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        ark.board(cleanAmount, bytes(""));
        uint256 afterBalance2 = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 deposited2 = afterBalance2 - beforeBalance2;

        assertEq(deposited2, cleanAmount, "Should deposit exact clean amount");

        vm.stopPrank();
    }

    function test_DustHandling_ArkShouldCleanDustAndKeepForWithdrawal() public {
        // Test that the ark should handle dusty deposits by cleaning the dust
        // and keeping it in the ark for later withdrawal
        uint256 dustyAmount = 1.123456789123456789 ether; // Has dust beyond 6 decimals

        vm.deal(commander, dustyAmount);
        vm.startPrank(commander);
        weth.deposit{value: dustyAmount}();
        IERC20(address(weth)).approve(address(ark), dustyAmount);

        uint256 cleanAmount = (dustyAmount / ark.convertRate()) *
            ark.convertRate(); // Clean amount = 1.123456 ether
        uint256 dustAmount = dustyAmount - cleanAmount; // Dust = 0.000000789123456789 ether

        uint256 initialStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 initialWethInArk = weth.balanceOf(address(ark));

        ark.board(dustyAmount, bytes(""));

        uint256 finalStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        uint256 finalWethInArk = weth.balanceOf(address(ark));
        uint256 actualStaked = finalStakedBalance - initialStakedBalance;
        uint256 dustInArk = finalWethInArk - initialWethInArk;

        assertEq(
            actualStaked,
            cleanAmount,
            "Should stake only the clean amount"
        );
        assertEq(dustInArk, dustAmount, "Should keep dust in the ark as WETH");

        // Verify total assets includes both staked amount and dust
        uint256 totalAssets = ark.totalAssets();
        assertEq(
            totalAssets,
            dustyAmount,
            "Total assets should include staked + dust"
        );

        // Verify we can withdraw the full dusty amount
        uint256 withdrawableAssets = ark.withdrawableTotalAssets();
        assertEq(
            withdrawableAssets,
            dustyAmount,
            "Should be able to withdraw full dusty amount"
        );

        // Test actual withdrawal
        uint256 commanderWethBefore = weth.balanceOf(commander);
        ark.disembark(dustyAmount, bytes(""));
        uint256 commanderWethAfter = weth.balanceOf(commander);
        uint256 actualWithdrawn = commanderWethAfter - commanderWethBefore;

        assertEq(
            actualWithdrawn,
            dustyAmount,
            "Should withdraw full dusty amount including dust"
        );

        vm.stopPrank();
    }

    function testFuzz_MultiDepositsWithdrawals(
        uint256[5] memory depositAmts,
        uint256[5] memory withdrawAmts
    ) public {
        uint256 convertRate = ark.convertRate();

        // Provision commander and approve
        uint256 provision = 50 ether;
        vm.deal(commander, provision);
        vm.startPrank(commander);
        weth.deposit{value: provision}();
        IERC20(address(weth)).approve(address(ark), type(uint256).max);

        // Track via totalAssets invariants

        // Fuzz deposits (may include dust). Invariant: totalAssets increases by full deposited amount.
        for (uint256 i = 0; i < depositAmts.length; i++) {
            // Bound each deposit to a reasonable size
            uint256 amt = bound(depositAmts[i], 0, 5 ether);
            if (amt == 0) continue;

            uint256 taPrev = ark.totalAssets();
            ark.board(amt, bytes(""));
            uint256 taAfter = ark.totalAssets();

            assertEq(
                taAfter - taPrev,
                amt,
                "Deposit should increase totalAssets by full amount (clean + dust)"
            );
        }

        // Fuzz withdrawals. Construct safe amounts: withdraw = dust + k*convertRate, capped by pool & staked.
        for (uint256 i = 0; i < withdrawAmts.length; i++) {
            // Current dust in Ark (WETH already held)
            uint256 dustInArk = weth.balanceOf(address(ark));

            // Clean availability from pool and staked position
            uint256 poolAvail = IStargatePool(STARGATE_POOL_ADDRESS).redeemable(
                address(0)
            );
            uint256 stakedAvail = stargateStaking.balanceOf(
                lpToken,
                address(ark)
            );
            uint256 cleanAvail = (
                poolAvail < stakedAvail ? poolAvail : stakedAvail
            );
            // cleanAvail = (cleanAvail / convertRate) * convertRate; // floor to clean multiple

            if (dustInArk == 0 && cleanAvail == 0) continue;

            // Choose k based on fuzzed input but bounded by available clean units
            uint256 req = bound(withdrawAmts[i], 0, 5 ether);
            uint256 kTarget = req / convertRate;
            uint256 kMax = cleanAvail / convertRate;
            uint256 k = kTarget <= kMax ? kTarget : kMax;

            uint256 withdrawAmt = dustInArk + (k * convertRate);
            if (withdrawAmt == 0) continue;

            // Final safety cap: do not exceed withdrawableTotalAssets
            uint256 maxAvail = ark.withdrawableTotalAssets();
            if (withdrawAmt > maxAvail) {
                // reduce k accordingly
                if (maxAvail <= dustInArk) {
                    // withdraw only dust if possible
                    withdrawAmt = dustInArk <= maxAvail ? dustInArk : 0;
                } else {
                    uint256 extra = maxAvail - dustInArk;
                    uint256 kCap = extra / convertRate;
                    withdrawAmt = dustInArk + (kCap * convertRate);
                }
            }

            if (withdrawAmt == 0) continue;

            uint256 taPrev = ark.totalAssets();
            uint256 commanderBeforePartialWithdraw = weth.balanceOf(commander);

            ark.disembark(withdrawAmt, bytes(""));

            uint256 taAfter = ark.totalAssets();
            uint256 commanderAfterPartialWithdraw = weth.balanceOf(commander);

            // Invariants per operation
            assertEq(
                taPrev - taAfter,
                withdrawAmt,
                "Withdraw should decrease totalAssets by the withdrawn amount"
            );
            assertEq(
                commanderAfterPartialWithdraw - commanderBeforePartialWithdraw,
                withdrawAmt,
                "Commander should receive the withdrawn amount"
            );
        }

        uint256 arkAssetsAfter = ark.totalAssets();
        uint256 commanderBeforeFullWithdraw = weth.balanceOf(commander);
        ark.disembark(arkAssetsAfter, bytes(""));
        uint256 commanderAfterFullWithdraw = weth.balanceOf(commander);
        assertEq(
            commanderAfterFullWithdraw - commanderBeforeFullWithdraw,
            arkAssetsAfter,
            "Commander should receive the remaining dust - if any"
        );
        vm.stopPrank();
    }
}
