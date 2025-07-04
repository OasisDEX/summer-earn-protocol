// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FleetDepositManager} from "../../src/contracts/FleetDepositManager.sol";
import {StargateAdapter} from "@summerfi/chain-bridge/adapters/StargateAdapter.sol";
import {BridgeRouter} from "@summerfi/chain-bridge/router/BridgeRouter.sol";
import {BridgeQueue} from "@summerfi/chain-bridge/router/BridgeQueue.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockStargateV2} from "@summerfi/chain-bridge-test/mocks/MockStargateV2.sol";
import {MockHarborCommand} from "../mocks/MockHarborCommand.sol";
import {FleetCommanderTestMock} from "../mocks/FleetCommanderTestMock.sol";

/**
 * @title FleetDepositManagerIntegrationForkTest
 * @notice Integration tests for FleetDepositManager using real adapters and mainnet forks
 * @dev Tests the direct flow: FleetDepositManager -> StargateAdapter
 * @dev BridgeRouter is only used for adapter validation, not for the actual deposit flow
 */
contract FleetDepositManagerIntegrationForkTest is Test {
    // Mainnet contract addresses
    address constant LAYERZERO_ENDPOINT_MAINNET =
        0x1a44076050125825900e736c501f859c50fE728c;
    address constant LAYERZERO_ENDPOINT_BASE =
        0x1a44076050125825900e736c501f859c50fE728c;

    // USDC addresses
    address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // LayerZero endpoint IDs
    uint32 constant LZ_EID_MAINNET = 30101;
    uint32 constant LZ_EID_BASE = 30184;

    // Chain IDs
    uint16 constant CHAIN_ID_MAINNET = 1;
    uint16 constant CHAIN_ID_BASE = 8453;

    // Test accounts
    address user = address(0x123);
    address governor = address(0x456);
    address shareRecipient = address(0x789);

    // Contracts
    FleetDepositManager public manager;
    StargateAdapter public adapterMainnet;
    StargateAdapter public adapterBase;
    BridgeRouter public bridgeRouter; // Only used for adapter validation
    MockHarborCommand public mockHarborCommand;
    FleetCommanderTestMock public mockFleetCommander;
    MockStargateV2 public mockStargateMainnet;
    MockStargateV2 public mockStargateBase;

    // Test constants
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 6; // 1000 USDC
    uint256 public constant FORK_BLOCK = 22_145_762;

    event FleetDepositToTargetChainInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed user,
        address bridgeAdapter,
        address fleetCommander,
        address asset,
        uint256 amount,
        address shareRecipient
    );

    function setUp() public {
        // Skip if no RPC URL is available
        try vm.rpcUrl("mainnet") returns (string memory) {
            // Fork mainnet
            vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
            vm.selectFork(0);
        } catch {
            // Skip test if mainnet RPC is not available
            vm.skip(true);
            return;
        }

        // Deploy mainnet contracts
        _setupMainnet();

        // Create second fork for Base
        try vm.rpcUrl("base") returns (string memory baseUrl) {
            vm.createFork(baseUrl);
        } catch {
            // Use mainnet fork as placeholder if Base RPC not available
            vm.createFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        }
        vm.selectFork(1);

        // Deploy Base contracts
        _setupBase();

        // Configure cross-chain connections
        _configureCrossChain();
    }

    function _setupMainnet() internal {
        vm.startPrank(governor);

        // Deploy access manager
        ProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        // Deploy harbor command mock
        mockHarborCommand = new MockHarborCommand();

        // Deploy BridgeRouter and Queue for adapter validation only
        BridgeQueue bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Router set later
            governor
        );
        bridgeRouter = new BridgeRouter(
            address(accessManager),
            address(bridgeQueue)
        );
        bridgeQueue.setBridgeRouter(address(bridgeRouter));

        // Deploy Stargate adapter
        adapterMainnet = new StargateAdapter(
            address(bridgeRouter), // For interface compatibility, but not used in deposit flow
            governor,
            LAYERZERO_ENDPOINT_MAINNET,
            address(mockHarborCommand)
        );

        // Deploy mock Stargate contract for mainnet USDC
        mockStargateMainnet = new MockStargateV2(
            USDC_MAINNET,
            MockStargateV2.StargateType.Pool
        );

        // Configure adapter
        adapterMainnet.addSupportedChain(
            CHAIN_ID_MAINNET,
            LZ_EID_MAINNET,
            address(adapterMainnet)
        );
        adapterMainnet.addSupportedAsset(
            USDC_MAINNET,
            address(mockStargateMainnet)
        );

        // Register adapter with BridgeRouter for validation purposes only
        bridgeRouter.registerAdapter(address(adapterMainnet));

        // Deploy FleetDepositManager
        manager = new FleetDepositManager(
            address(bridgeRouter), // Only used for adapter validation
            address(accessManager)
        );

        // Create mock fleet commander
        mockFleetCommander = new FleetCommanderTestMock(USDC_MAINNET);

        vm.stopPrank();
    }

    function _setupBase() internal {
        vm.startPrank(governor);

        // Deploy access manager
        ProtocolAccessManager accessManagerBase = new ProtocolAccessManager(
            governor
        );

        // Deploy harbor command mock
        MockHarborCommand mockHarborCommandBase = new MockHarborCommand();

        // Deploy minimal BridgeRouter for adapter interface compatibility
        BridgeQueue bridgeQueueBase = new BridgeQueue(
            address(accessManagerBase),
            address(0),
            governor
        );
        BridgeRouter bridgeRouterBase = new BridgeRouter(
            address(accessManagerBase),
            address(bridgeQueueBase)
        );
        bridgeQueueBase.setBridgeRouter(address(bridgeRouterBase));

        // Deploy Stargate adapter on Base
        adapterBase = new StargateAdapter(
            address(bridgeRouterBase),
            governor,
            LAYERZERO_ENDPOINT_BASE,
            address(mockHarborCommandBase)
        );

        // Deploy mock Stargate contract for Base USDC
        mockStargateBase = new MockStargateV2(
            USDC_BASE,
            MockStargateV2.StargateType.Pool
        );

        // Configure adapter
        adapterBase.addSupportedChain(
            CHAIN_ID_MAINNET,
            LZ_EID_MAINNET,
            address(adapterMainnet)
        );
        adapterBase.addSupportedChain(
            CHAIN_ID_BASE,
            LZ_EID_BASE,
            address(adapterBase)
        );
        adapterBase.addSupportedAsset(USDC_BASE, address(mockStargateBase));

        vm.stopPrank();
    }

    function _configureCrossChain() internal {
        // Switch back to mainnet and add Base chain support
        vm.selectFork(0);
        vm.prank(governor);
        adapterMainnet.addSupportedChain(
            CHAIN_ID_BASE,
            LZ_EID_BASE,
            address(adapterBase)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FleetDepositIntegration_DirectFlow() public {
        vm.selectFork(0); // Mainnet

        // Setup: Give user USDC and ETH
        deal(USDC_MAINNET, user, DEPOSIT_AMOUNT);
        vm.deal(user, 1 ether);

        // Estimate fee directly from adapter
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0.01 ether,
                options: bytes("")
            });

        (uint256 estimatedFee, ) = adapterMainnet.estimateFee(
            CHAIN_ID_BASE,
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // User initiates fleet deposit
        vm.startPrank(user);
        IERC20(USDC_MAINNET).approve(address(manager), DEPOSIT_AMOUNT);

        // Expect event emission
        vm.expectEmit(false, true, true, false);
        emit FleetDepositToTargetChainInitiated(
            bytes32(0), // operationId will be different
            CHAIN_ID_BASE,
            user,
            address(adapterMainnet),
            address(mockFleetCommander),
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            shareRecipient
        );

        // FleetDepositManager calls StargateAdapter directly via IFleetDepositAdapter
        bytes32 operationId = manager.initiateDepositToTargetChainFleet{
            value: estimatedFee
        }(
            address(adapterMainnet), // Adapter called directly
            CHAIN_ID_BASE,
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            address(mockFleetCommander),
            shareRecipient,
            bytes("INTEGRATION_TEST"),
            adapterParams
        );

        vm.stopPrank();

        // Verify operation was initiated
        assertNotEq(operationId, bytes32(0), "Operation ID should not be zero");

        // Verify tokens were transferred from user to FleetDepositManager, then to adapter
        assertEq(
            IERC20(USDC_MAINNET).balanceOf(user),
            0,
            "User should have no USDC left"
        );

        // Verify tokens reached the mock Stargate contract (final destination)
        assertEq(
            IERC20(USDC_MAINNET).balanceOf(address(mockStargateMainnet)),
            DEPOSIT_AMOUNT,
            "Mock Stargate should have received USDC from adapter"
        );

        // Verify the compose message was created correctly
        bytes memory lastComposeMessage = mockStargateMainnet.lastComposeMsg();
        assertGt(
            lastComposeMessage.length,
            0,
            "Compose message should not be empty"
        );
    }

    function test_FleetDepositIntegration_WithReferralCode() public {
        vm.selectFork(0); // Mainnet

        bytes memory referralCode = bytes("SUMMER2024");

        // Setup
        deal(USDC_MAINNET, user, DEPOSIT_AMOUNT);
        vm.deal(user, 1 ether);

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0.01 ether,
                options: bytes("")
            });

        (uint256 estimatedFee, ) = adapterMainnet.estimateFee(
            CHAIN_ID_BASE,
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        vm.startPrank(user);
        IERC20(USDC_MAINNET).approve(address(manager), DEPOSIT_AMOUNT);

        bytes32 operationId = manager.initiateDepositToTargetChainFleet{
            value: estimatedFee
        }(
            address(adapterMainnet),
            CHAIN_ID_BASE,
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            address(mockFleetCommander),
            shareRecipient,
            referralCode,
            adapterParams
        );

        vm.stopPrank();

        // Verify the compose message contains the referral code
        bytes memory lastComposeMessage = mockStargateMainnet.lastComposeMsg();
        assertGt(
            lastComposeMessage.length,
            0,
            "Compose message should not be empty"
        );

        // Decode the fleet deposit message correctly using the struct
        (
            bytes32 messageType,
            BridgeTypes.FleetDepositMessageData memory messageData
        ) = abi.decode(
                lastComposeMessage,
                (bytes32, BridgeTypes.FleetDepositMessageData)
            );

        // Verify all fields
        assertEq(
            messageType,
            BridgeTypes.USER_FLEET_DEPOSIT_TYPE,
            "Message type should match"
        );
        assertEq(
            messageData.fleetCommander,
            address(mockFleetCommander),
            "Fleet commander should match"
        );
        assertEq(
            messageData.shareRecipient,
            shareRecipient,
            "Share recipient should match"
        );
        assertEq(messageData.asset, USDC_MAINNET, "Asset should match");
        assertEq(messageData.amount, DEPOSIT_AMOUNT, "Amount should match");
        assertEq(
            messageData.sourceChainId,
            CHAIN_ID_MAINNET,
            "Source chain ID should match"
        );
        assertEq(
            messageData.operationId,
            operationId,
            "Operation ID should match"
        );
        assertEq(messageData.originalUser, user, "Original user should match");
        assertEq(
            messageData.referralCode,
            referralCode,
            "Referral code should match"
        );
    }

    function test_FleetDepositIntegration_UnsupportedAdapter() public {
        vm.selectFork(0); // Mainnet

        // Deploy a second adapter that's not registered with BridgeRouter
        vm.prank(governor);
        StargateAdapter unregisteredAdapter = new StargateAdapter(
            address(bridgeRouter),
            governor,
            LAYERZERO_ENDPOINT_MAINNET,
            address(mockHarborCommand)
        );

        deal(USDC_MAINNET, user, DEPOSIT_AMOUNT);
        vm.deal(user, 1 ether);

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0.01 ether,
                options: bytes("")
            });

        vm.startPrank(user);
        IERC20(USDC_MAINNET).approve(address(manager), DEPOSIT_AMOUNT);

        // Should fail because adapter is not registered with BridgeRouter
        vm.expectRevert(FleetDepositManager.UnsupportedBridgeAdapter.selector);
        manager.initiateDepositToTargetChainFleet{value: 0.01 ether}(
            address(unregisteredAdapter), // Unregistered adapter
            CHAIN_ID_BASE,
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            address(mockFleetCommander),
            shareRecipient,
            bytes(""),
            adapterParams
        );

        vm.stopPrank();
    }

    function test_FleetDepositIntegration_AdapterValidation() public {
        vm.selectFork(0); // Mainnet

        // Test that FleetDepositManager validates adapter through BridgeRouter
        assertTrue(
            manager.isAdapterSupported(address(adapterMainnet)),
            "Stargate adapter should be supported by FleetDepositManager"
        );

        // Test direct adapter capabilities
        assertTrue(
            adapterMainnet.supportsChain(CHAIN_ID_BASE),
            "Adapter should support Base chain"
        );

        assertTrue(
            adapterMainnet.supportsOperation(
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            "Adapter should support asset transfers"
        );

        // Test fleet deposit specific support
        assertTrue(
            adapterMainnet.supportsUserInitiatedFleetDeposits(),
            "Adapter should support user-initiated fleet deposits"
        );
    }

    function test_FleetDepositIntegration_FeeEstimation() public {
        vm.selectFork(0); // Mainnet

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            });

        // Test fee estimation consistency directly from adapter
        (uint256 fee1, ) = adapterMainnet.estimateFee(
            CHAIN_ID_BASE,
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        (uint256 fee2, ) = adapterMainnet.estimateFee(
            CHAIN_ID_BASE,
            USDC_MAINNET,
            DEPOSIT_AMOUNT,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        assertEq(fee1, fee2, "Fee estimation should be consistent");
        assertGt(fee1, 0, "Fee should be greater than zero");
    }
}
