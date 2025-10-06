// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommander} from "../../src/contracts/CrossChainFleetCommander.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {CrossChainFleetCommanderParams, AsyncOperation} from "../../src/types/CrossChainFleetCommanderTypes.sol";
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
 * @notice Base test contract for CrossChainFleetCommander with async operations
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
    uint256 public constant MIN_QUEUE_AMOUNT = 1000 * 10 ** 6; // 1000 USDC

    // Mock Arks with sync status
    SyncedArkMock public syncedArkMock;
    UnsyncedArkMock public unsyncedArkMock;

    // Test addresses
    address public superkeeper = address(0x100);
    address public asyncUser = address(0x200);
    address public asyncUser2 = address(0x300);

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

        // Grant superkeeper role
        vm.startPrank(governor);
        accessManager.grantKeeperRole(
            address(crossChainFleetCommander),
            superkeeper
        );
        vm.stopPrank();

        // Setup mock Arks for the CrossChainFleetCommander
        setupMockArksForCrossChain();

        // Setup additional mock Arks for sync testing
        setupSyncTestArks();
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
            name: fleetName,
            details: "Test CrossChain FleetCommander",
            symbol: "TEST-SUM",
            configurationManager: address(configurationManager),
            accessManager: address(accessManager),
            asset: underlyingToken,
            initialMinimumBufferBalance: 0,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            depositCap: type(uint256).max,
            initialTipRate: initialTipRate,
            minQueueAmount: MIN_QUEUE_AMOUNT
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
     * @notice Setup mock Arks for sync testing
     */
    function setupSyncTestArks() internal {
        syncedArkMock = new SyncedArkMock(
            ArkParams({
                name: "SyncedArk",
                details: "SyncedArk details",
                accessManager: address(accessManager),
                asset: address(mockToken),
                configurationManager: address(configurationManager),
                depositCap: 100000 * 10 ** 6,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                requiresKeeperData: false,
                maxDepositPercentageOfTVL: PERCENTAGE_100
            })
        );

        unsyncedArkMock = new UnsyncedArkMock(
            ArkParams({
                name: "UnsyncedArk",
                details: "UnsyncedArk details",
                accessManager: address(accessManager),
                asset: address(mockToken),
                configurationManager: address(configurationManager),
                depositCap: 100000 * 10 ** 6,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                requiresKeeperData: false,
                maxDepositPercentageOfTVL: PERCENTAGE_100
            })
        );
    }

    /**
     * @notice Setup user with tokens for async operations
     * @param user The user address
     * @param amount The amount of tokens to mint
     */
    function setupAsyncUser(address user, uint256 amount) internal {
        mockToken.mint(user, amount);
        vm.startPrank(user);
        mockToken.approve(address(crossChainFleetCommander), amount);
        vm.stopPrank();
    }

    /**
     * @notice Queue a deposit operation
     * @param user The user address
     * @param amount The amount to deposit
     * @param receiver The receiver address
     * @return operationId The operation ID
     */
    function queueDeposit(
        address user,
        uint256 amount,
        address receiver
    ) internal returns (uint256 operationId) {
        vm.prank(user);
        operationId = crossChainFleetCommander.queueDeposit(amount, receiver);
    }

    /**
     * @notice Queue a withdrawal operation
     * @param user The user address
     * @param amount The amount to withdraw
     * @param receiver The receiver address
     * @param owner The owner address
     * @return operationId The operation ID
     */
    function queueWithdrawal(
        address user,
        uint256 amount,
        address receiver,
        address owner
    ) internal returns (uint256 operationId) {
        vm.prank(user);
        operationId = crossChainFleetCommander.queueWithdrawal(
            amount,
            receiver,
            owner
        );
    }

    /**
     * @notice Queue a redemption operation
     * @param user The user address
     * @param shares The number of shares to redeem
     * @param receiver The receiver address
     * @param owner The owner address
     * @return operationId The operation ID
     */
    function queueRedemption(
        address user,
        uint256 shares,
        address receiver,
        address owner
    ) internal returns (uint256 operationId) {
        vm.prank(user);
        operationId = crossChainFleetCommander.queueRedemption(
            shares,
            receiver,
            owner
        );
    }

    /**
     * @notice Process async operations as superkeeper
     * @param maxOperations Maximum number of operations to process
     * @return processedCount Number of operations processed
     * @return failedCount Number of operations that failed
     */
    function processAsyncOperations(
        uint256 maxOperations
    ) internal returns (uint256 processedCount, uint256 failedCount) {
        vm.prank(superkeeper);
        (processedCount, failedCount) = crossChainFleetCommander
            .processAsyncOperations(maxOperations);
    }

    /**
     * @notice Cancel an operation
     * @param operationId The operation ID to cancel
     */
    function cancelOperation(uint256 operationId) internal {
        vm.prank(asyncUser);
        crossChainFleetCommander.cancelOperation(operationId);
    }

    /**
     * @notice Check if all Arks are synced
     * @return synced True if all Arks are synced
     */
    function areAllArksSynced() internal view returns (bool synced) {
        return crossChainFleetCommander.areAllArksSynced();
    }

    /**
     * @notice Get async operation details
     * @param operationId The operation ID
     * @return operation The operation details
     */
    function getAsyncOperation(
        uint256 operationId
    ) internal view returns (AsyncOperation memory operation) {
        return crossChainFleetCommander.getAsyncOperation(operationId);
    }

    /**
     * @notice Get queued operations count
     * @return count The number of queued operations
     */
    function getQueuedOperationsCount() internal view returns (uint256 count) {
        return crossChainFleetCommander.getQueuedOperationsCount();
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

/**
 * @title SyncedArkMock
 * @notice Mock Ark that always reports as synced
 */
contract SyncedArkMock is ArkMock {
    constructor(ArkParams memory _params) ArkMock(_params) {}

    function isSynced() public view override returns (bool) {
        return true;
    }
}

/**
 * @title UnsyncedArkMock
 * @notice Mock Ark that always reports as unsynced
 */
contract UnsyncedArkMock is ArkMock {
    constructor(ArkParams memory _params) ArkMock(_params) {}

    function isSynced() public view override returns (bool) {
        return false;
    }
}
