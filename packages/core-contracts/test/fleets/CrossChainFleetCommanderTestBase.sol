// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommander} from "../../src/contracts/CrossChainFleetCommander.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {CrossChainFleetCommanderParams} from "../../src/types/CrossChainFleetCommanderTypes.sol";
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
 * @title CrossChainFleetCommanderTestBase
 * @notice Base test contract for CrossChainFleetCommander with cooldown protection
 * @dev Extends FleetCommanderTestBase with CrossChainFleetCommander specific setup
 */
abstract contract CrossChainFleetCommanderTestBase is
    Test,
    FleetCommanderTestBase
{
    using PercentageUtils for uint256;

    // CrossChainFleetCommander specific contracts
    CrossChainFleetCommander public crossChainFleetCommander;

    // CrossChainFleetCommander specific parameters
    CrossChainFleetCommanderParams public crossChainFleetCommanderParams;
    uint256 public constant COOLDOWN_PERIOD = 1 hours; // 1 hour cooldown

    // Test addresses
    address public user1 = address(0x200);
    address public user2 = address(0x300);

    constructor() {}

    /**
     * @notice Initialize CrossChainFleetCommander with proper setup
     * @param initialTipRate The initial tip rate for the FleetCommander
     */
    function initializeCrossChainFleetCommander(
        uint256 initialTipRate
    ) internal {
        // Initialize mock token first
        mockToken = new ERC20Mock();

        // First setup the base contracts
        setupBaseContracts();

        // Setup CrossChainFleetCommander (which inherits from FleetCommander)
        setupCrossChainFleetCommander(
            address(mockToken),
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );

        // Grant roles for CrossChainFleetCommander
        vm.startPrank(governor);
        accessManager.grantKeeperRole(
            address(crossChainFleetCommander),
            keeper
        );
        accessManager.grantCuratorRole(
            address(crossChainFleetCommander),
            governor
        );
        accessManager.grantCommanderRole(
            address(bufferArk),
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Setup mock Arks for the CrossChainFleetCommander
        setupMockArksForCrossChain();
    }

    /**
     * @notice Setup CrossChainFleetCommander with buffer Ark
     * @param underlyingToken The underlying token address
     * @param initialTipRate The initial tip rate
     */
    function setupCrossChainFleetCommander(
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

        // Setup CrossChainFleetCommander parameters
        crossChainFleetCommanderParams = CrossChainFleetCommanderParams({
            fleetCommanderParams: FleetCommanderParams({
                name: fleetName,
                details: "Test CrossChain FleetCommander",
                symbol: "TEST-SUM",
                configurationManager: address(configurationManager),
                accessManager: address(accessManager),
                asset: underlyingToken,
                initialMinimumBufferBalance: 0,
                initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
                depositCap: type(uint256).max,
                initialTipRate: initialTipRate
            }),
            cooldownPeriod: COOLDOWN_PERIOD
        });

        crossChainFleetCommander = new CrossChainFleetCommander(
            crossChainFleetCommanderParams
        );

        // Get the bufferArk from the CrossChainFleetCommander
        bufferArkAddress = crossChainFleetCommander.bufferArk();
        bufferArk = BufferArk(bufferArkAddress);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(crossChainFleetCommander)
        );
        harborCommand.enlistFleetCommander(address(crossChainFleetCommander));
        vm.stopPrank();
    }

    /**
     * @notice Setup mock Arks for CrossChainFleetCommander
     */
    function setupMockArksForCrossChain() internal {
        // Create mock Arks for the CrossChainFleetCommander
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
            address(crossChainFleetCommander)
        );
        accessManager.grantCommanderRole(
            ark2,
            address(crossChainFleetCommander)
        );
        accessManager.grantCommanderRole(
            ark3,
            address(crossChainFleetCommander)
        );
        accessManager.grantCommanderRole(
            ark4,
            address(crossChainFleetCommander)
        );
        vm.stopPrank();

        // Add Arks to CrossChainFleetCommander
        vm.startPrank(governor);
        crossChainFleetCommander.addArk(ark1);
        crossChainFleetCommander.addArk(ark2);
        crossChainFleetCommander.addArk(ark3);
        crossChainFleetCommander.addArk(ark4);
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
        mockToken.approve(address(crossChainFleetCommander), amount);
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
        shares = crossChainFleetCommander.deposit(amount, receiver);
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
        shares = crossChainFleetCommander.withdraw(amount, receiver, owner);
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
        assets = crossChainFleetCommander.redeem(shares, receiver, owner);
    }

    /**
     * @notice Get the cooldown period
     * @return period The cooldown period in seconds
     */
    function getCooldownPeriod() internal view returns (uint256 period) {
        return crossChainFleetCommander.getCooldownPeriod();
    }

    /**
     * @notice Get the timestamp when a user can next withdraw/redeem
     * @param user The address of the user
     * @return timestamp The timestamp when the user can next withdraw/redeem
     */
    function getNextWithdrawTimestamp(
        address user
    ) internal view returns (uint256 timestamp) {
        return crossChainFleetCommander.getNextWithdrawTimestamp(user);
    }

    /**
     * @notice Check if a user can withdraw/redeem (cooldown has passed)
     * @param user The address of the user
     * @return canWithdrawNow True if the user can withdraw/redeem now
     */
    function canWithdraw(
        address user
    ) internal view returns (bool canWithdrawNow) {
        return crossChainFleetCommander.canWithdraw(user);
    }

    /**
     * @notice Grant roles for CrossChainFleetCommander
     * @param arks Array of Ark addresses
     * @param _bufferArkAddress Buffer Ark address
     * @param _keeper Keeper address
     */
    function grantCrossChainFleetCommanderRoles(
        address[] memory arks,
        address _bufferArkAddress,
        address _keeper
    ) internal {
        vm.startPrank(governor);
        accessManager.grantKeeperRole(
            address(crossChainFleetCommander),
            _keeper
        );
        accessManager.grantCuratorRole(
            address(crossChainFleetCommander),
            governor
        );
        accessManager.grantCommanderRole(
            address(_bufferArkAddress),
            address(crossChainFleetCommander)
        );
        for (uint256 i = 0; i < arks.length; i++) {
            accessManager.grantCommanderRole(
                arks[i],
                address(crossChainFleetCommander)
            );
        }
        vm.stopPrank();
    }
}
