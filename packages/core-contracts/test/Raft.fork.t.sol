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
import {FleetCommanderMock} from "./mocks/FleetCommanderMock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "../src/errors/RaftErrors.sol";

contract RaftForkTest is Test, IRaftEvents {
    using PercentageUtils for uint256;

    Raft public raft;
    CompoundV3Ark public ark;
    IProtocolAccessManager public accessManager;
    IConfigurationManager public configurationManager;
    ERC20Mock public underlyingToken;

    address public constant SWAP_PROVIDER =
        0x111111125421cA6dc452d289314280a0f8842A65; // 1inch v6
    address public constant REWARD_TOKEN =
        0xc00e94Cb662C3520282E6f5717214004A7f26888; // COMP Token
    address public constant COMET_ADDRESS =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant COMET_REWARDS =
        0x1B0e765F6224C21223AeA2af16c1C46E38885a40;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public governor = address(1);
    FleetCommanderMock public commander;
    address public keeper = address(8);
    address public tipJar = address(9);

    uint256 public constant SUPPLIED_USDC_AMOUNT = 1990 * 10 ** 6;
    uint256 public constant FORK_BLOCK = 20468960;

    bytes public swapCalldata;

    function setUp() public {
        underlyingToken = new ERC20Mock();
        tipJar = address(0x123);

        // Create and select a fork of the Ethereum mainnet
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        // Setup access management
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(keeper);

        // Deploy Raft
        raft = new Raft(SWAP_PROVIDER, address(accessManager));

        // Setup Configuration Manager
        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: address(raft)
            })
        );

        commander = new FleetCommanderMock(
            USDC,
            address(configurationManager),
            PercentageUtils.fromIntegerPercentage(1)
        );

        // Setup and deploy CompoundV3Ark
        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max
        });
        ark = new CompoundV3Ark(COMET_ADDRESS, COMET_REWARDS, params);
        commander.addArk(address(ark));

        // Grant commander role to the commander address
        vm.prank(governor);
        ark.grantCommanderRole(address(commander));

        // Supply USDC to the Ark
        deal(USDC, address(commander), SUPPLIED_USDC_AMOUNT);
        vm.startPrank(address(commander));
        IERC20(USDC).approve(address(ark), SUPPLIED_USDC_AMOUNT);
        ark.board(SUPPLIED_USDC_AMOUNT);
        vm.stopPrank();

        swapCalldata = hex"07ed23790000000000000000000000005f515f6c524b18ca30f7783fb58dd4be2e9904ec0000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000005f515f6c524b18ca30f7783fb58dd4be2e9904ec0000000000000000000000003c22ec75ea5d745c78fc84762f7f1e6d82a2c5bf0000000000000000000000000000000000000000000000056bc75e2d631000000000000000000000000000000000000000000000000000000000003c9d2626c9000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000f5cd5c95f99994184cc61cd2fbc864729b3cf19d4e2d4a0823c692eb5766c2968fdae37a363d7116632d5aee37c15e57b85885129d80553b344e4c74570497887db000000000000000000000000000000000000000efe000ed0000e86000e6c00a098aed10500000000000000000802000000000000000000000000000000000000000000000000000e3e0004f200a0bdb694217f39c581f595b53c5cb19bd0b3f8da6c935e2ca03c22ec75ea5d745c78fc84762f7f1e6d82a2c5bf0000000000000000000000000000000000000000000000000000000c1fe34b2b00000000000000000000000000000000000000000000000000000000048600a007e5c0d20000000000000000000000000000000000000000000004620003b20001ad00a0c9e75c480000000000000000230f00000000000000000000000000000000000000000000000000017f00004f00a0fbb7cd060032296969ef14eb0c6d29669c550d4a04491302300002000000000000000000807f39c581f595b53c5cb19bd0b3f8da6c935e2ca0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc251204a585e0f7c18e2c414221d6402652d5e0990e5f87f39c581f595b53c5cb19bd0b3f8da6c935e2ca000a4a5dcbcdf0000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000eb1c92f9f5ec9d817968afddb4b46c564cdedbe0000000000000000000000005f515f6c524b18ca30f7783fb58dd4be2e9904ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0c9e75c48000000000000120e09090000000000000000000000000000000000000001d70001880001390000ea00a06f5ec5cedac17f958d2ee523a2206206994597c13d831ec75100d51a44d3fae010294c616388b506acda1bfaae46c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20044394747c5000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022e7bc04e000000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000022e7f3529ee63c1e501c7bbec68d12a0d1830360f8ec58fa599ba1b0e9bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc202a00000000000000000000000000000000000000000000000000000000364f78129ee63c1e5016ca298d2983ab03aa1da7679389d955a4efee15cc02aaa39b223fe8d0a0e5c4f27ead9083c756cc202a0000000000000000000000000000000000000000000000000000000045cc703c4ee63c1e50111b815efb8f581194ae79006d24e0d814b7697f6c02aaa39b223fe8d0a0e5c4f27ead9083c756cc25120c9f93163c99695c6526b799ebca2207fdf7d61addac17f958d2ee523a2206206994597c13d831ec700048dae733300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c1fe34b2b0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000a0bdb694217f39c581f595b53c5cb19bd0b3f8da6c935e2ca03c22ec75ea5d745c78fc84762f7f1e6d82a2c5bf000000000000000000000000000000000000000000000000000000307d42db9d0000000000000000000000000000000000000000000000000000000008e000a007e5c0d20000000000000000000000000000000000000008bc0008a200012000005600a06f5ec5ceae7ab96520de3a18e5e111b5eaab095312d7fe8441207f39c581f595b53c5cb19bd0b3f8da6c935e2ca00004de0e9a3e000000000000000000000000000000000000000000000000000000000000000000a06f5ec5ce00000000000000000000000000000000000000005120dc24316b9ae028f1497c275eb9192a3ea0f67022ae7ab96520de3a18e5e111b5eaab095312d7fe8400443df0212400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000494c9b31184445bcb00a0c9e75c480000000000001a12030300000000000000000000000000000000000000075400030300027600010e00a007e5c0d20000000000000000000000000000000000000000000000000000ea00001a4041c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2d0e30db051007f86bf177dd4f3494b841a37e810a34dd56c829bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20044394747c500000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e9285f03000000000000000000000000000000000000000000000000000000000000000000a007e5c0d200000000000000000000000000000000000000000000000000014400001a4041c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2d0e30db000a06f5ec5cea0b86991c6218b36c1d19d4a2e9eb0ce3606eb485100d17b3c9784510e33cd5b87b490e79253bcd81e2ec02aaa39b223fe8d0a0e5c4f27ead9083c756cc2004458d30ac9000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e9aab4b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005f515f6c524b18ca30f7783fb58dd4be2e9904ec0000000000000000000000000000000000000000000000000000000066b893b800a007e5c0d200000000000000000000000000000000000000000000000000006900001a4041c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2d0e30db002a000000000000000000000000000000000000000000000000000000011777efd3dee63c1e50088e6a0c2ddd26feeb64f039a2c41296fcb3f5640c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200a007e5c0d200000000000000000000000000000000000000000000000000042d00001a4041c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2d0e30db000a06f5ec5cea0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0860a32ec000000000000000000000000000000000000000000000002a59c5c157f9eeb680003d05120ead050515e10fdb3540ccd6f8236c46790508a76c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200c4e525b10b000000000000000000000000000000000000000000000000000000000000002000000000000000000000000022b1a53ac4be63cdc1f47c99572290eff1edd8020000000000000000000000006a32cc044dd6359c27bb66e7b02dce6dd0fda2470000000000000000000000005f515f6c524b18ca30f7783fb58dd4be2e9904ec000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a59c5c157f9eeb680000000000000000000000000000000000000000000000000000001bf88e08600000000000000000000000000000000000000000000000000000000066b1fc91000000000000000000000000000000000000000000000000001b16fdde9f2b6f9c9aa5118cf74b8e9a8b9675157be41d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000026000000000000000000000000067297ee4eb097e072b4ab6f1620268061ae8046400000000000000000000000060cba82ddbf4b5ddcd4398cdd05354c6a790c309000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000000000000000000000000000000000000036000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041764e9a8d61e22116a678b0fbb9258acfdc917505df1872c927384092d2a52ab9796783a7e201ae9502955abc5310f063be82e2ff9acc92236a0bd44a9bc6aa111b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004171daf9e628d1225b7c00c13a3b124c5e002c74464bddf484bee219adc62ecd192bc5676580194e3bbb431eb5deaa5458bc8c0edc87bdf002317f6745d76fdc481b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0f2fa6b66a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000435946d5c3000000000000000000000000004c814e80a06c4eca27a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48111111125421ca6dc452d289314280a0f8842a65000000000709215a";
    }

    function test_Harvest() public {
        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 1000000);

        // Expect the ArkHarvested event to be emitted
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(address(ark), REWARD_TOKEN);

        // Perform the harvest
        raft.harvest(address(ark), REWARD_TOKEN, bytes(""));

        // Assert that rewards were harvested
        uint256 harvestedAmount = IERC20(REWARD_TOKEN).balanceOf(address(raft));
        assertEq(harvestedAmount, 7878000000000000);
    }

    function test_SwapAndBoard() public {
        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 1000000);

        // Perform initial harvest
        address testCompWhale = 0xf7Ba2631166e4f7A22a91Def302d873106f0beD8;
        vm.prank(testCompWhale);
        raft.harvest(address(ark), REWARD_TOKEN, bytes(""));

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
        emit RewardBoarded(address(ark), REWARD_TOKEN, USDC, 0);

        // Perform swapAndBoard
        vm.prank(keeper);
        raft.swapAndBoard(address(ark), REWARD_TOKEN, swapData);

        // Assert that the Ark's balance increased
        uint256 arkBalance = ark.totalAssets();
        assertGt(arkBalance, SUPPLIED_USDC_AMOUNT);
    }

    function test_PartialFill() public {
        address WSTETH_REWARD = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        uint256 HARVESTED_AMOUNT = 1000000000000000000000; // 100 WSTETH
        uint256 SWAPPED_MIN_AMOUNT = 2892000000000;
        uint256 ACTUAL_SWAPPED_AMOUNT = 2800000000000; // Slightly less than the minimum expected

        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 1000000);

        // Mock the harvest call
        vm.mockCall(
            address(ark),
            abi.encodeWithSelector(
                IArk.harvest.selector,
                WSTETH_REWARD,
                bytes("")
            ),
            abi.encode(HARVESTED_AMOUNT)
        );

        // Perform initial harvest
        raft.harvest(address(ark), WSTETH_REWARD, bytes(""));

        // Manually add WSTETH balance to the Raft contract
        deal(WSTETH_REWARD, address(raft), HARVESTED_AMOUNT);

        // Verify the balance
        uint256 rewardAmount = IERC20(WSTETH_REWARD).balanceOf(address(raft));
        assertEq(
            rewardAmount,
            HARVESTED_AMOUNT,
            "WSTETH balance should match harvested amount"
        );

        // Prepare swap data with a high receiveAtLeast value
        SwapData memory swapData = SwapData({
            fromAsset: WSTETH_REWARD,
            amount: HARVESTED_AMOUNT,
            receiveAtLeast: SWAPPED_MIN_AMOUNT,
            withData: swapCalldata // Use the stored calldata
        });

        // Mock the swap call to simulate a successful swap but with less than expected amount
        vm.mockCall(
            SWAP_PROVIDER,
            swapData.withData,
            abi.encode(ACTUAL_SWAPPED_AMOUNT)
        );

        // Manually remove WSTETH and add WBTC to simulate the swap
        deal(WSTETH_REWARD, address(raft), 0);
        deal(USDC, address(raft), ACTUAL_SWAPPED_AMOUNT);

        // Expect the ReceivedLess error
        vm.expectRevert(
            abi.encodeWithSelector(
                ReceivedLess.selector,
                SWAPPED_MIN_AMOUNT,
                ACTUAL_SWAPPED_AMOUNT
            )
        );

        // Attempt to perform swapAndBoard
        vm.prank(keeper);
        raft.swapAndBoard(address(ark), WSTETH_REWARD, swapData);
    }

    function test_SwapFail() public {
        address WSTETH_REWARD = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        uint256 HARVESTED_AMOUNT = 1000000000000000000000; // 100 WSTETH
        uint256 SWAPPED_MIN_AMOUNT = 2892000000000;

        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 1000000);

        // Mock the harvest call
        vm.mockCall(
            address(ark),
            abi.encodeWithSelector(
                IArk.harvest.selector,
                WSTETH_REWARD,
                bytes("")
            ),
            abi.encode(HARVESTED_AMOUNT)
        );

        // Perform initial harvest
        raft.harvest(address(ark), WSTETH_REWARD, bytes(""));

        // Manually add WSTETH balance to the Raft contract
        deal(WSTETH_REWARD, address(raft), HARVESTED_AMOUNT);

        // Verify the balance
        uint256 rewardAmount = IERC20(WSTETH_REWARD).balanceOf(address(raft));
        assertEq(
            rewardAmount,
            HARVESTED_AMOUNT,
            "WSTETH balance should match harvested amount"
        );

        // Prepare swap data with a high receiveAtLeast value
        SwapData memory swapData = SwapData({
            fromAsset: WSTETH_REWARD,
            amount: HARVESTED_AMOUNT,
            receiveAtLeast: SWAPPED_MIN_AMOUNT,
            withData: swapCalldata // Use the stored calldata
        });

        //        // Mock the swap call to simulate a successful swap but with less than expected amount
        //        vm.mockCall(
        //            SWAP_PROVIDER,
        //            swapData.withData,
        //            abi.encode(ACTUAL_SWAPPED_AMOUNT)
        //        );

        // Expect the ReceivedLess error
        vm.expectRevert(
            abi.encodeWithSelector(RewardsSwapFailed.selector, keeper)
        );

        // Attempt to perform swapAndBoard
        vm.prank(keeper);
        raft.swapAndBoard(address(ark), WSTETH_REWARD, swapData);
    }
}
