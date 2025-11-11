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

contract StargateV2PoolArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    StargateV2PoolArk public ark;
    IStargatePool public stargatePool;
    IStargateStaking public stargateStaking;
    IERC20 public usdt;
    IERC20 public lpToken;
    IWETH public weth;
    ArkParams public params;

    // Arbitrum addresses
    address public constant STARGATE_POOL_ADDRESS =
        0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0;
    address public constant STARGATE_STAKING_ADDRESS =
        0x3da4f8E456AC648c489c286B99Ca37B666be7C4C;
    address public constant USDT_ADDRESS =
        0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT on Arbitrum
    address public constant WETH_ADDRESS =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum

    uint256 forkBlock = 300000000; // A recent block number for Arbitrum
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("arbitrum"), forkBlock);

        usdt = IERC20(USDT_ADDRESS);
        stargatePool = IStargatePool(STARGATE_POOL_ADDRESS);
        stargateStaking = IStargateStaking(STARGATE_STAKING_ADDRESS);
        lpToken = IERC20(stargatePool.lpToken());
        weth = IWETH(WETH_ADDRESS);

        params = ArkParams({
            name: "USDT Stargate V2 Pool Ark",
            details: "USDT Stargate V2 Pool Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDT_ADDRESS,
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
            USDT_ADDRESS,
            "Token address should match USDT"
        );
        assertEq(
            ark.name(),
            "USDT Stargate V2 Pool Ark",
            "Ark name should match"
        );
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT (6 decimals on Arbitrum)
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);

        uint256 initialStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDT_ADDRESS, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalStakedBalance = stargateStaking.balanceOf(
            lpToken,
            address(ark)
        );
        assertGt(
            finalStakedBalance,
            initialStakedBalance,
            "Staked LP balance should increase"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 initialUSDTBalance = usdt.balanceOf(commander);
        uint256 amountToDisembark = ark.withdrawableTotalAssets();

        vm.expectEmit();
        emit Disembarked(commander, USDT_ADDRESS, amountToDisembark);

        ark.disembark(amountToDisembark, bytes(""));
        vm.stopPrank();

        uint256 finalUSDTBalance = usdt.balanceOf(commander);
        assertGt(
            finalUSDTBalance,
            initialUSDTBalance,
            "USDT balance should increase after disembarking"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
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
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
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
        uint256 amount = 1000 * 1e6; // 1000 USDT
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
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

        uint256 veryLowBalance = 1 * 1e6;
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
}
