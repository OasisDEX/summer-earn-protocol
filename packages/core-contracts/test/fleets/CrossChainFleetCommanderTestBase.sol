// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {PercentageUtils, PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";
import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkMock} from "../mocks/ArkMock.sol";

/**
 * @title FleetCommanderWithCooldownTestBase
 * @notice Base test contract for FleetCommander with cooldown protection
 * @dev Extends FleetCommanderTestBase with cooldown specific setup
 */
abstract contract FleetCommanderWithCooldownTestBase is
    Test,
    FleetCommanderTestBase
{
    using PercentageUtils for uint256;

    // FleetCommander with cooldown functionality
    FleetCommander public fleetCommanderWithCooldown;

    // FleetCommander parameters with cooldown
    FleetCommanderParams public fleetCommanderParamsWithCooldown;
    uint256 public constant COOLDOWN_PERIOD = 1 hours; // 1 hour cooldown

    // Test addresses
    address public user1 = address(0x200);
    address public user2 = address(0x300);

    constructor() {}

    /**
     * @notice Initialize FleetCommander with cooldown functionality
     * @param initialTipRate The initial tip rate for the FleetCommander
     */
    function initializeFleetCommanderWithCooldown(
        uint256 initialTipRate
    ) internal {
        // Initialize mock token first
        mockToken = new ERC20Mock();

        // First setup the base contracts
        setupBaseContracts();

        // Setup FleetCommander with cooldown functionality
        setupFleetCommanderWithCooldown(
            address(mockToken),
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );

        // Grant roles for FleetCommander
        vm.startPrank(governor);
        accessManager.grantKeeperRole(
            address(fleetCommanderWithCooldown),
            keeper
        );
        accessManager.grantCuratorRole(
            address(fleetCommanderWithCooldown),
            governor
        );
        accessManager.grantCommanderRole(
            address(bufferArk),
            address(fleetCommanderWithCooldown)
        );
        vm.stopPrank();

        // Setup mock Arks for the FleetCommander
        setupMockArksForFleetCommander();
    }

    /**
     * @notice Setup FleetCommander with cooldown functionality
     * @param underlyingToken The underlying token address
     * @param initialTipRate The initial tip rate
     */
    function setupFleetCommanderWithCooldown(
        address underlyingToken,
        Percentage initialTipRate
    ) internal {
        vm.startPrank(governor);

        // Setup StakingRewardsManager
        if (address(mockGovernor) == address(0)) {
            mockGovernor = new MockSummerGovernor();
        }

        // Deploy reward tokens
        for (uint256 i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Prepare reward token addresses
        address[] memory rewardTokenAddresses = new address[](
            rewardTokens.length
        );
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokenAddresses[i] = address(rewardTokens[i]);
        }

        // Setup FleetCommander parameters with cooldown
        fleetCommanderParamsWithCooldown = FleetCommanderParams({
            name: fleetName,
            details: "Test FleetCommander with Cooldown",
            symbol: "TEST-SUM",
            configurationManager: address(configurationManager),
            accessManager: address(accessManager),
            asset: underlyingToken,
            initialMinimumBufferBalance: 0,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            depositCap: type(uint256).max,
            initialTipRate: initialTipRate,
            initialCooldownPeriod: COOLDOWN_PERIOD
        });

        fleetCommanderWithCooldown = new FleetCommander(
            fleetCommanderParamsWithCooldown
        );

        // Get the bufferArk from the FleetCommander
        bufferArkAddress = fleetCommanderWithCooldown.bufferArk();
        bufferArk = BufferArk(bufferArkAddress);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommanderWithCooldown)
        );
        harborCommand.enlistFleetCommander(address(fleetCommanderWithCooldown));
        vm.stopPrank();
    }

    /**
     * @notice Setup mock Arks for FleetCommander
     */
    function setupMockArksForFleetCommander() internal {
        // Create mock Arks for the FleetCommander
        mockArk1 = createMockArk(
            address(mockToken),
            ARK1_MAX_ALLOCATION,
            false
        );
        mockArk2 = createMockArk(
            address(mockToken),
            ARK2_MAX_ALLOCATION,
            false
        );
        mockArk3 = createMockArk(
            address(mockToken),
            ARK3_MAX_ALLOCATION,
            false
        );
        mockArk4 = createRestictedWithdrawalArkMock(
            address(mockToken),
            ARK4_MAX_ALLOCATION,
            true
        );

        ark1 = address(mockArk1);
        ark2 = address(mockArk2);
        ark3 = address(mockArk3);
        ark4 = address(mockArk4);

        // Grant commander roles for the Arks
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            ark1,
            address(fleetCommanderWithCooldown)
        );
        accessManager.grantCommanderRole(
            ark2,
            address(fleetCommanderWithCooldown)
        );
        accessManager.grantCommanderRole(
            ark3,
            address(fleetCommanderWithCooldown)
        );
        accessManager.grantCommanderRole(
            ark4,
            address(fleetCommanderWithCooldown)
        );
        vm.stopPrank();

        // Add Arks to FleetCommander
        vm.startPrank(governor);
        fleetCommanderWithCooldown.addArk(ark1);
        fleetCommanderWithCooldown.addArk(ark2);
        fleetCommanderWithCooldown.addArk(ark3);
        fleetCommanderWithCooldown.addArk(ark4);
        vm.stopPrank();
    }

    /**
     * @notice Setup user with tokens for cooldown testing
     * @param user The user address
     * @param amount The amount of tokens to mint
     */
    function setupUser(address user, uint256 amount) internal {
        mockToken.mint(user, amount);
        vm.startPrank(user);
        mockToken.approve(address(fleetCommanderWithCooldown), amount);
        vm.stopPrank();
    }

    /**
     * @notice Perform a deposit operation
     * @param user The user address
     * @param amount The amount to deposit
     * @param receiver The receiver address
     * @return shares The number of shares received
     */
    function performDeposit(
        address user,
        uint256 amount,
        address receiver
    ) internal returns (uint256 shares) {
        vm.prank(user);
        shares = fleetCommanderWithCooldown.deposit(amount, receiver);
    }

    /**
     * @notice Perform a withdrawal operation
     * @param user The user address
     * @param amount The amount to withdraw
     * @param receiver The receiver address
     * @param owner The owner address
     * @return shares The number of shares burned
     */
    function performWithdrawal(
        address user,
        uint256 amount,
        address receiver,
        address owner
    ) internal returns (uint256 shares) {
        vm.prank(user);
        shares = fleetCommanderWithCooldown.withdraw(amount, receiver, owner);
    }

    /**
     * @notice Perform a redemption operation
     * @param user The user address
     * @param shares The number of shares to redeem
     * @param receiver The receiver address
     * @param owner The owner address
     * @return assets The number of assets received
     */
    function performRedemption(
        address user,
        uint256 shares,
        address receiver,
        address owner
    ) internal returns (uint256 assets) {
        vm.prank(user);
        assets = fleetCommanderWithCooldown.redeem(shares, receiver, owner);
    }

    /**
     * @notice Get the cooldown period
     * @return period The cooldown period in seconds
     */
    function getCooldownPeriod() internal view returns (uint256 period) {
        return fleetCommanderWithCooldown.getUserCooldownPeriod();
    }

    /**
     * @notice Get the timestamp when a user can next withdraw/redeem
     * @param user The address of the user
     * @return timestamp The timestamp when the user can next withdraw/redeem
     */
    function getNextWithdrawTimestamp(
        address user
    ) internal view returns (uint256 timestamp) {
        return fleetCommanderWithCooldown.getNextUserActionTimestamp(user);
    }

    /**
     * @notice Check if a user can withdraw/redeem (cooldown has passed)
     * @param user The address of the user
     * @return canWithdrawNow True if the user can withdraw/redeem now
     */
    function canWithdraw(
        address user
    ) internal view returns (bool canWithdrawNow) {
        return fleetCommanderWithCooldown.canUserPerformAction(user);
    }

    /**
     * @notice Grant roles for FleetCommander
     * @param arks Array of Ark addresses
     * @param _bufferArkAddress Buffer Ark address
     * @param _keeper Keeper address
     */
    function grantFleetCommanderRoles(
        address[] memory arks,
        address _bufferArkAddress,
        address _keeper
    ) internal {
        vm.startPrank(governor);
        accessManager.grantKeeperRole(
            address(fleetCommanderWithCooldown),
            _keeper
        );
        accessManager.grantCuratorRole(
            address(fleetCommanderWithCooldown),
            governor
        );
        accessManager.grantCommanderRole(
            address(_bufferArkAddress),
            address(fleetCommanderWithCooldown)
        );
        for (uint256 i = 0; i < arks.length; i++) {
            accessManager.grantCommanderRole(
                arks[i],
                address(fleetCommanderWithCooldown)
            );
        }
        vm.stopPrank();
    }
}
