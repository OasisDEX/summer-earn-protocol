// SPDX-License-Identifier: BUSL-1.1
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
import {IAdmiralsQuarters} from "../../src/interfaces/IAdmiralsQuarters.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";
import {ISummerRewardsRedeemer} from "@summerfi/rewards-contracts/interfaces/ISummerRewardsRedeemer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

contract MockGovernanceRewardsManager {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct RewardData {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 rewardsDuration;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    EnumerableSet.AddressSet internal _rewardTokensList;
    mapping(IERC20 => RewardData) public rewardData;
    mapping(IERC20 => mapping(address => uint256)) public rewards;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address _rewardToken) {}

    function notifyRewardAmount(
        IERC20 rewardToken,
        uint256 reward,
        uint256 newRewardsDuration
    ) external {
        RewardData storage rewardTokenData = rewardData[rewardToken];

        // Add reward token if it doesn't exist
        if (!_rewardTokensList.contains(address(rewardToken))) {
            require(newRewardsDuration > 0, "Duration must be > 0");
            _rewardTokensList.add(address(rewardToken));
            rewardTokenData.rewardsDuration = newRewardsDuration;
        }

        // Transfer rewards
        rewardToken.safeTransferFrom(msg.sender, address(this), reward);

        // Update reward data
        rewardTokenData.rewardRate =
            (reward * Constants.WAD) /
            rewardTokenData.rewardsDuration;
        rewardTokenData.lastUpdateTime = block.timestamp;
        rewardTokenData.periodFinish =
            block.timestamp +
            rewardTokenData.rewardsDuration;
    }

    // Mock function to simulate taking a position
    function stake(uint256 amount) external {
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
    }

    // Add a helper function to simulate rewards
    function simulateRewardsEarned(
        address account,
        address rewardToken,
        uint256 amount
    ) external {
        rewards[IERC20(rewardToken)][account] = amount;
    }

    function getRewardFor(address account, address rewardToken) external {
        require(
            _rewardTokensList.contains(rewardToken),
            "Reward token does not exist"
        );

        IERC20 token = IERC20(rewardToken);
        uint256 reward = rewards[token][account];
        if (reward > 0) {
            rewards[token][account] = 0;
            token.safeTransfer(account, reward);
        }
    }
}

contract MockSummerRewardsRedeemer is ISummerRewardsRedeemer {
    IERC20 public immutable rewardsToken;
    uint256 public deployedAt;

    constructor(address _rewardsToken) {
        rewardsToken = IERC20(_rewardsToken);
        deployedAt = block.timestamp;
    }

    function claimMultiple(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata
    ) external {
        // Sum up all amounts
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
            emit Claimed(user, indices[i], amounts[i]);
        }

        // Transfer total rewards
        rewardsToken.transfer(user, total);
    }

    function claimMultiple(
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        this.claimMultiple(msg.sender, indices, amounts, proofs);
    }

    // Other required interface functions
    function addRoot(uint256 index, bytes32 root) external {}
    function removeRoot(uint256 index) external {}
    function getRoot(uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
    function claim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof
    ) external {}
    function canClaim(
        address,
        uint256,
        uint256,
        bytes32[] memory
    ) external pure returns (bool) {
        return true;
    }
    function hasClaimed(address, uint256) external pure returns (bool) {
        return false;
    }
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external {}
}

contract AdmiralsQuartersRewardsTest is FleetCommanderTestBase {
    AdmiralsQuarters public admiralsQuarters;
    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable ETH_PSEUDO_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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

        // Verify fleet commander is enlisted
        require(
            harborCommand.activeFleetCommanders(address(usdcFleet)),
            "Fleet commander not enlisted"
        );

        // Deploy AdmiralsQuarters
        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager),
            WETH
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
            address(rewardTokens[0]),
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

    function test_ClaimMerkleRewards() public {
        vm.startPrank(governor);
        // Setup merkle rewards
        deal(address(rewardTokens[0]), address(mockRewardsRedeemer), 1000e6);
        vm.stopPrank();

        vm.startPrank(user1);
        // Setup claim parameters - updated to use separate arrays
        uint256[] memory indices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        indices[0] = 0;
        amounts[0] = 100e6;
        proofs[0] = new bytes32[](0);

        uint256 initialRewardBalance = rewardTokens[0].balanceOf(user1);

        bytes[] memory claimCalls = new bytes[](1);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimMerkleRewards,
            (user1, indices, amounts, proofs, address(mockRewardsRedeemer))
        );
        admiralsQuarters.multicall(claimCalls);

        uint256 finalRewardBalance = rewardTokens[0].balanceOf(user1);
        assertGt(
            finalRewardBalance,
            initialRewardBalance,
            "Should have received merkle rewards"
        );
        vm.stopPrank();
    }

    function test_ClaimGovernanceRewards() public {
        // First stake some tokens
        vm.startPrank(user1);
        mockGovRewardsManager.stake(1e18);
        vm.stopPrank();

        // Then notify rewards
        vm.startPrank(governor);
        deal(address(rewardTokens[0]), governor, 1e9);
        rewardTokens[0].approve(address(mockGovRewardsManager), 1e9);
        mockGovRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            1e9,
            864000
        );
        vm.stopPrank();

        // Wait some time for rewards to accrue and simulate rewards
        vm.warp(block.timestamp + 1 days);
        mockGovRewardsManager.simulateRewardsEarned(
            user1,
            address(rewardTokens[0]),
            1e8 // Simulate 100M tokens earned
        );

        // Now try to claim - using multicall
        vm.startPrank(user1);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.claimGovernanceRewards,
            (address(mockGovRewardsManager), address(rewardTokens[0]))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // Verify rewards were received
        assertGt(
            rewardTokens[0].balanceOf(user1),
            0,
            "Should have received rewards"
        );
    }

    function test_ClaimFleetRewards() public {
        // Note: Rewards are already setup in setUp()
        // Setup: Deposit and enter fleet
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;

        // Ensure user has USDC and approvals
        deal(USDC_ADDRESS, user1, depositAmount);
        IERC20(USDC_ADDRESS).approve(address(admiralsQuarters), depositAmount);

        // Execute deposit, enter fleet, and stake
        bytes[] memory depositAndEnterCalls = new bytes[](3);
        depositAndEnterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        depositAndEnterCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        depositAndEnterCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0) // stake all shares
        );
        admiralsQuarters.multicall(depositAndEnterCalls);

        // Warp time to accumulate rewards
        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 1000);

        // Claim rewards
        address[] memory fleetCommanders = new address[](1);
        fleetCommanders[0] = address(usdcFleet);

        uint256 initialRewardBalance = rewardTokens[0].balanceOf(user1);

        bytes[] memory claimCalls = new bytes[](1);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimFleetRewards,
            (fleetCommanders, address(rewardTokens[0]))
        );
        admiralsQuarters.multicall(claimCalls);

        uint256 finalRewardBalance = rewardTokens[0].balanceOf(user1);
        assertGt(
            finalRewardBalance,
            initialRewardBalance,
            "Should have received fleet rewards"
        );

        assertEq(
            rewardTokens[0].balanceOf(address(admiralsQuarters)),
            0,
            "Should have no tokens leftover in AdmiralsQuarters"
        );
        vm.stopPrank();
    }

    function test_ClaimAllRewardsViaBundledMulticall() public {
        // Setup fleet rewards (already done in setUp())

        // Setup governance rewards
        vm.startPrank(user1);
        mockGovRewardsManager.stake(1e18);
        vm.stopPrank();

        vm.startPrank(governor);
        deal(address(rewardTokens[0]), governor, 1e9);
        rewardTokens[0].approve(address(mockGovRewardsManager), 1e9);
        mockGovRewardsManager.notifyRewardAmount(
            IERC20(address(rewardTokens[0])),
            1e9,
            864000
        );
        vm.stopPrank();

        // Simulate governance rewards earned
        mockGovRewardsManager.simulateRewardsEarned(
            user1,
            address(rewardTokens[0]),
            1e8
        );

        // Setup merkle rewards
        vm.startPrank(governor);
        deal(address(rewardTokens[0]), address(mockRewardsRedeemer), 1000e6);
        vm.stopPrank();

        // Setup fleet position
        vm.startPrank(user1);
        uint256 depositAmount = 100e6;
        deal(USDC_ADDRESS, user1, depositAmount);

        // Enter fleet and stake
        bytes[] memory setupCalls = new bytes[](3);
        setupCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), depositAmount)
        );
        setupCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), depositAmount, address(admiralsQuarters))
        );
        setupCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0) // stake all shares
        );
        admiralsQuarters.multicall(setupCalls);

        // Warp time to accumulate rewards
        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 1000);

        // Setup claim parameters - updated to use separate arrays
        uint256[] memory indices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        indices[0] = 0;
        amounts[0] = 100e6;
        proofs[0] = new bytes32[](0);

        address[] memory fleetCommanders = new address[](1);
        fleetCommanders[0] = address(usdcFleet);

        uint256 initialRewardBalance = rewardTokens[0].balanceOf(user1);

        // Bundle all claims in a single multicall
        bytes[] memory claimCalls = new bytes[](3);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimMerkleRewards,
            (user1, indices, amounts, proofs, address(mockRewardsRedeemer))
        );
        claimCalls[1] = abi.encodeCall(
            admiralsQuarters.claimGovernanceRewards,
            (address(mockGovRewardsManager), address(rewardTokens[0]))
        );
        claimCalls[2] = abi.encodeCall(
            admiralsQuarters.claimFleetRewards,
            (fleetCommanders, address(rewardTokens[0]))
        );
        admiralsQuarters.multicall(claimCalls);

        uint256 finalRewardBalance = rewardTokens[0].balanceOf(user1);
        assertGt(
            finalRewardBalance,
            initialRewardBalance,
            "Should have received all rewards"
        );
        vm.stopPrank();
    }

    function test_ClaimFleetRewards_InvalidFleetCommander() public {
        vm.startPrank(user1);
        address[] memory fleetCommanders = new address[](1);
        fleetCommanders[0] = address(0x123); // Invalid address

        bytes[] memory claimCalls = new bytes[](1);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimFleetRewards,
            (fleetCommanders, address(rewardTokens[0]))
        );

        vm.expectRevert(IAdmiralsQuartersErrors.InvalidFleetCommander.selector);
        admiralsQuarters.multicall(claimCalls);
        vm.stopPrank();
    }
}
