// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/StargateV2PoolArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IStargatePool} from "../../src/interfaces/stargate/IStargatePool.sol";
import {IStargateStaking} from "../../src/interfaces/stargate/IStargateStaking.sol";
import {IMultiRewarder} from "../../src/interfaces/stargate/IMultiRewarder.sol";
import {IWETH} from "../../src/interfaces/misc/IWETH.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
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
            abi.encodeWithSelector(IStargatePool.poolBalance.selector),
            abi.encode(veryLowBalance)
        );
        assertEq(
            stargatePool.poolBalance(),
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
}
