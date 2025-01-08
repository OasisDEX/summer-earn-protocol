// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AdmiralsQuarters} from "../../src/contracts/AdmiralsQuarters.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {IAdmiralsQuartersErrors} from "../../src/errors/IAdmiralsQuartersErrors.sol";
import {IAdmiralsQuarters} from "../../src/interfaces/IAdmiralsQuarters.sol";
import {IFleetCommanderRewardsManager} from "../../src/interfaces/IFleetCommanderRewardsManager.sol";
import {FleetCommanderTestBase} from "../fleets/FleetCommanderTestBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Test, console} from "forge-std/Test.sol";

contract MockGovernanceRewardsManager {
    IERC20 public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    function getReward() external {
        rewardToken.transfer(msg.sender, 100e6);
    }
}

contract MockSummerRewardsRedeemer {
    IERC20 public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    function claimMultipleOnBehalf(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        rewardToken.transfer(user, 100e6);
    }
}

contract AdmiralsQuartersRewardsTest is FleetCommanderTestBase {
    AdmiralsQuarters public admiralsQuarters;
    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public user1 = address(0x1111);
    FleetCommander public usdcFleet;
    MockGovernanceRewardsManager public mockGovRewardsManager;
    MockSummerRewardsRedeemer public mockRewardsRedeemer;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 20576616);

        // Initialize fleet commander
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, 0);
        usdcFleet = fleetCommander;

        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(bufferArk),
            address(fleetCommander)
        );

        // Deploy AdmiralsQuarters
        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager)
        );
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // Deploy mock contracts
        mockGovRewardsManager = new MockGovernanceRewardsManager(
            address(rewardTokens[0])
        );
        mockRewardsRedeemer = new MockSummerRewardsRedeemer(
            address(rewardTokens[0])
        );

        // Setup initial rewards
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        deal(address(rewardTokens[0]), governor, 1000e6);
        rewardTokens[0].approve(address(rewardsManager), 1000e6);
        IFleetCommanderRewardsManager(rewardsManager).notifyRewardAmount(
            IERC20(rewardTokens[0]),
            1000e6,
            10 days
        );
        vm.stopPrank();

        // Setup user
        deal(USDC_ADDRESS, user1, 1000e6);
        vm.startPrank(user1);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();
    }

    function test_ClaimAllRewards() public {
        vm.startPrank(governor);

        // Setup fleet rewards
        uint256 fleetRewardAmount = 1000e6;
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;

        // Deal tokens to governor for notification
        deal(address(rewardTokens[0]), governor, fleetRewardAmount);
        rewardTokens[0].approve(address(rewardsManager), fleetRewardAmount);
        IFleetCommanderRewardsManager(rewardsManager).notifyRewardAmount(
            IERC20(rewardTokens[0]),
            fleetRewardAmount,
            10 days
        );

        // Deal tokens to rewards manager for distribution
        deal(address(rewardTokens[0]), rewardsManager, fleetRewardAmount);

        // Setup governance and merkle rewards
        deal(
            address(rewardTokens[0]),
            address(mockGovRewardsManager),
            fleetRewardAmount
        );
        deal(
            address(rewardTokens[0]),
            address(mockRewardsRedeemer),
            fleetRewardAmount
        );
        vm.stopPrank();

        // User stakes in fleet
        vm.startPrank(user1);
        uint256 stakeAmount = 100e6;
        deal(USDC_ADDRESS, user1, stakeAmount);
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), stakeAmount);

        bytes[] memory stakeCalls = new bytes[](3);
        stakeCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), stakeAmount)
        );
        stakeCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), stakeAmount, address(admiralsQuarters))
        );
        stakeCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(stakeCalls);

        vm.warp(block.timestamp + 5 days);

        // Setup claim parameters
        IAdmiralsQuarters.MerkleClaimData[]
            memory merkleData = new IAdmiralsQuarters.MerkleClaimData[](1);
        merkleData[0] = IAdmiralsQuarters.MerkleClaimData({
            index: 0,
            amount: 100e6,
            proof: new bytes32[](0)
        });

        address[] memory fleetCommanders = new address[](1);
        fleetCommanders[0] = address(usdcFleet);

        IAdmiralsQuarters.RewardClaimParams memory params = IAdmiralsQuarters
            .RewardClaimParams({
                merkleData: merkleData,
                rewardsRedeemer: address(mockRewardsRedeemer),
                govRewardsManager: address(mockGovRewardsManager),
                fleetCommanders: fleetCommanders,
                rewardToken: address(rewardTokens[0])
            });

        uint256 initialRewardBalance = rewardTokens[0].balanceOf(user1);

        bytes[] memory claimCalls = new bytes[](1);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimAllRewards,
            (user1, params)
        );
        admiralsQuarters.multicall(claimCalls);

        uint256 finalRewardBalance = rewardTokens[0].balanceOf(user1);
        assertGt(
            finalRewardBalance,
            initialRewardBalance,
            "Should have received rewards"
        );

        vm.stopPrank();
    }

    function test_ClaimAllRewards_EmptyMerkleData() public {
        vm.startPrank(governor);
        // Setup fleet rewards
        uint256 fleetRewardAmount = 1000e6;
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;

        // Deal tokens to governor for notification
        deal(address(rewardTokens[0]), governor, fleetRewardAmount);
        rewardTokens[0].approve(address(rewardsManager), fleetRewardAmount);
        IFleetCommanderRewardsManager(rewardsManager).notifyRewardAmount(
            IERC20(rewardTokens[0]),
            fleetRewardAmount,
            10 days
        );

        // Deal tokens to rewards manager for distribution
        deal(address(rewardTokens[0]), rewardsManager, fleetRewardAmount);
        vm.stopPrank();

        // User stakes in fleet
        vm.startPrank(user1);
        uint256 stakeAmount = 100e6;
        deal(USDC_ADDRESS, user1, stakeAmount);
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), stakeAmount);

        bytes[] memory stakeCalls = new bytes[](3);
        stakeCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), stakeAmount)
        );
        stakeCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), stakeAmount, address(admiralsQuarters))
        );
        stakeCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );
        admiralsQuarters.multicall(stakeCalls);

        // Wait for rewards to accrue
        vm.warp(block.timestamp + 5 days);

        // Setup claim parameters
        address[] memory fleetCommanders = new address[](1);
        fleetCommanders[0] = address(usdcFleet);

        IAdmiralsQuarters.RewardClaimParams memory params = IAdmiralsQuarters
            .RewardClaimParams({
                fleetCommanders: fleetCommanders,
                rewardToken: address(rewardTokens[0]),
                merkleData: new IAdmiralsQuarters.MerkleClaimData[](0),
                rewardsRedeemer: address(0),
                govRewardsManager: address(0)
            });

        // Wrap the claim in a multicall
        bytes[] memory claimCalls = new bytes[](1);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimAllRewards,
            (user1, params)
        );
        admiralsQuarters.multicall(claimCalls);

        vm.stopPrank();
    }

    function test_ClaimAllRewards_InvalidFleetCommander() public {
        vm.startPrank(user1);

        // Setup claim parameters with invalid fleet commander
        address[] memory fleetCommanders = new address[](1);
        fleetCommanders[0] = address(0x123); // Invalid address

        IAdmiralsQuarters.RewardClaimParams memory params = IAdmiralsQuarters
            .RewardClaimParams({
                merkleData: new IAdmiralsQuarters.MerkleClaimData[](0),
                rewardsRedeemer: address(0),
                govRewardsManager: address(0),
                fleetCommanders: fleetCommanders,
                rewardToken: address(rewardTokens[0])
            });

        // Attempt to claim rewards
        bytes[] memory claimCalls = new bytes[](1);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimAllRewards,
            (user1, params)
        );

        vm.expectRevert(IAdmiralsQuartersErrors.InvalidFleetCommander.selector);
        admiralsQuarters.multicall(claimCalls);

        vm.stopPrank();
    }
}
