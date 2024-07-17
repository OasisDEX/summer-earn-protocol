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

contract RaftTest is Test, IRaftEvents {
    Raft public raft;
    address public swapProvider = 0x111111125421cA6dc452d289314280a0f8842A65; // 1inch v6
    CompoundV3Ark public ark;
    address public governor = address(1);
    address public commander = address(4);
    address public keeper = address(8);

    address public rewardToken = 0xc00e94Cb662C3520282E6f5717214004A7f26888; // COMP Token
    address public constant cometAddress =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public cometRewards = 0x1B0e765F6224C21223AeA2af16c1C46E38885a40;
    IERC20 public usdc;

    uint256 public suppliedUsdcAmount = 1990 * 10 ** 6;

    uint256 forkBlock = 20276596;
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);

        raft = new Raft(swapProvider, address(accessManager));

        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: address(raft)
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(usdc)
        });

        ark = new CompoundV3Ark(cometAddress, cometRewards, params);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
        vm.stopPrank();

        deal(address(usdc), commander, suppliedUsdcAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), suppliedUsdcAmount);
        ark.board(suppliedUsdcAmount);
        vm.stopPrank();
    }

    function test_Harvest() public {
        // Arrange
        vm.warp(block.timestamp + 1000000);
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(ark), rewardToken);

        // Act
        raft.harvest(address(ark), rewardToken);

        // Assert
        assertEq(
            IERC20(rewardToken).balanceOf(address(raft)),
            6195000000000000
        );
    }

    function test_HarvestAndReboard() public {
        // Arrange
        vm.warp(block.timestamp + 1000000);

        address testCompWhale = 0xf7Ba2631166e4f7A22a91Def302d873106f0beD8;
        vm.prank(testCompWhale);
        raft.harvest(address(ark), rewardToken);
        uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(raft));

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit RewardSwapped(rewardToken, address(usdc), rewardAmount, 0);

        vm.expectEmit();
        emit RewardReboarded(address(ark), rewardToken, rewardAmount, 0);

        // Act
        vm.prank(keeper);
        raft.swapAndReboard(
            address(ark),
            rewardToken,
            SwapData({
                fromAsset: rewardToken,
                amount: rewardAmount,
                receiveAtLeast: 0,
                withData: bytes("")
            })
        );
    }
}
