// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import {IRaftEvents} from "../src/interfaces/IRaftEvents.sol";
import {Raft} from "../src/contracts/Raft.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SwapData} from "../src/types/RaftTypes.sol";
import {CompoundV3Ark, ArkParams} from "../src/contracts/arks/CompoundV3Ark.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";

contract RaftForkTest is Test, IRaftEvents {
    Raft public raft;
    CompoundV3Ark public ark;
    IProtocolAccessManager public accessManager;
    IConfigurationManager public configurationManager;

    address public constant SWAP_PROVIDER = 0x111111125421cA6dc452d289314280a0f8842A65; // 1inch v6
    address public constant REWARD_TOKEN = 0xc00e94Cb662C3520282E6f5717214004A7f26888; // COMP Token
    address public constant COMET_ADDRESS = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant COMET_REWARDS = 0x1B0e765F6224C21223AeA2af16c1C46E38885a40;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public governor = address(1);
    address public commander = address(4);
    address public keeper = address(8);

    uint256 public constant SUPPLIED_USDC_AMOUNT = 1990 * 10 ** 6;
    uint256 public constant FORK_BLOCK = 20276596;

    function setUp() public {
        // Create and select a fork of the Ethereum mainnet
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        // Setup access management
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);

        // Deploy Raft
        raft = new Raft(SWAP_PROVIDER, address(accessManager));

        // Setup Configuration Manager
        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: address(raft)
            })
        );

        // Setup and deploy CompoundV3Ark
        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: USDC
        });
        ark = new CompoundV3Ark(COMET_ADDRESS, COMET_REWARDS, params);

        // Grant commander role to the commander address
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        // Supply USDC to the Ark
        deal(USDC, commander, SUPPLIED_USDC_AMOUNT);
        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), SUPPLIED_USDC_AMOUNT);
        ark.board(SUPPLIED_USDC_AMOUNT);
        vm.stopPrank();
    }

    function test_Harvest() public {
        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 1000000);

        // Expect the ArkHarvested event to be emitted
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(ark), REWARD_TOKEN);

        // Perform the harvest
        raft.harvest(address(ark), REWARD_TOKEN);

        // Assert that rewards were harvested
        uint256 harvestedAmount = IERC20(REWARD_TOKEN).balanceOf(address(raft));
        assertEq(harvestedAmount, 6195000000000000);
    }

    function test_SwapAndReboard() public {
        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 1000000);

        // Perform initial harvest
        address testCompWhale = 0xf7Ba2631166e4f7A22a91Def302d873106f0beD8;
        vm.prank(testCompWhale);
        raft.harvest(address(ark), REWARD_TOKEN);

        uint256 rewardAmount = IERC20(REWARD_TOKEN).balanceOf(address(raft));

        // Prepare swap data
        SwapData memory swapData = SwapData({
            fromAsset: REWARD_TOKEN,
            amount: rewardAmount,
            receiveAtLeast: 0,
            withData: bytes("")
        });

        // Expect events to be emitted
        vm.expectEmit(true, true, true, true);
        emit RewardSwapped(REWARD_TOKEN, USDC, rewardAmount, 0);

        vm.expectEmit(true, true, true, true);
        emit RewardReboarded(address(ark), REWARD_TOKEN, rewardAmount, 0);

        // Perform swapAndReboard
        vm.prank(keeper);
        raft.swapAndReboard(address(ark), REWARD_TOKEN, swapData);

        // Assert that harvested rewards were reset
        assertEq(raft.getHarvestedRewards(address(ark), REWARD_TOKEN), 0);

        // Assert that the Ark's balance increased
        uint256 arkBalance = ark.totalAssets();
        assertGt(arkBalance, SUPPLIED_USDC_AMOUNT);
    }
}