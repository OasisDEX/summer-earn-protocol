// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Bridge contracts
import "../../src/adapters/StargateAdapter.sol";
import "../../src/libraries/BridgeTypes.sol";
import "../mocks/MockStargate.sol";
import "../mocks/MockLayerZeroEndpoint.sol";

// Core contracts - Real FleetCommander and related contracts
import "@summerfi/core-contracts/src/contracts/FleetCommander.sol";
import "@summerfi/core-contracts/src/contracts/arks/BufferArk.sol";
import "@summerfi/core-contracts/src/contracts/ConfigurationManager.sol";
import "@summerfi/core-contracts/src/contracts/HarborCommand.sol";
import "@summerfi/core-contracts/src/contracts/FleetCommanderRewardsManagerFactory.sol";
import "@summerfi/core-contracts/src/types/FleetCommanderTypes.sol";
import "@summerfi/core-contracts/src/types/ConfigurationManagerTypes.sol";
import "@summerfi/core-contracts/src/types/ArkTypes.sol";

// Access contracts
import "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

// Percentage utilities
import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title Stargate Adapter Fleet Integration Test
 * @dev Integration test using real FleetCommander contracts to test cross-chain deposits end-to-end
 */
contract StargateAdapterFleetIntegrationTest is Test {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    // Bridge contracts
    StargateAdapter public adapter;
    MockLayerZeroEndpoint public lzEndpoint;
    MockStargate public stargate;

    // Real core contracts
    FleetCommander public fleetCommander;
    BufferArk public bufferArk;
    ConfigurationManager public configurationManager;
    HarborCommand public harborCommand;
    FleetCommanderRewardsManagerFactory public rewardsManagerFactory;
    ProtocolAccessManager public accessManager;

    // Test token
    ERC20Mock public usdc;

    // Test addresses
    address public constant BRIDGE_ROUTER = address(0x1234);
    address public constant OWNER = address(0x5678);
    address public constant USER = address(0x9ABC);
    address public constant SHARE_RECIPIENT = address(0xDEF0);
    address public constant GOVERNOR = address(0x1111);
    address public constant KEEPER = address(0x2222);
    address public constant TREASURY = address(0x3333);
    address public constant TIP_JAR = address(0x4444);
    address public constant RAFT = address(0x5555);

    uint16 public constant SOURCE_CHAIN_ID = 1;
    uint16 public constant DEST_CHAIN_ID = 2;
    uint32 public constant DEST_ENDPOINT_ID = 30102;

    // Constants
    uint256 constant INITIAL_USDC_BALANCE = 100000 * 10 ** 6; // 100k USDC
    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6; // 1k USDC
    uint256 constant FLEET_DEPOSIT_CAP = 50000 * 10 ** 6; // 50k USDC
    uint256 constant BUFFER_MIN_BALANCE = 100 * 10 ** 6; // 100 USDC

    // Events from the real contracts
    event CrossChainFleetDepositInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed user,
        address fleetCommander,
        address asset,
        uint256 amount,
        address shareRecipient
    );

    event CrossChainFleetDepositCompleted(
        bytes32 indexed operationId,
        address indexed fleetCommander,
        address indexed shareRecipient,
        address asset,
        uint256 amount,
        uint256 shares,
        uint16 sourceChainId
    );

    function setUp() public {
        // Deploy test USDC token
        usdc = new ERC20Mock("USD Coin", "USDC", 6);

        // Deploy bridge infrastructure
        lzEndpoint = new MockLayerZeroEndpoint();
        stargate = new MockStargate(address(usdc));

        // Deploy access manager
        accessManager = new ProtocolAccessManager(GOVERNOR);

        // Deploy core contracts
        harborCommand = new HarborCommand(address(accessManager));
        rewardsManagerFactory = new FleetCommanderRewardsManagerFactory();
        configurationManager = new ConfigurationManager(address(accessManager));

        // Initialize configuration manager
        vm.prank(GOVERNOR);
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                raft: RAFT,
                tipJar: TIP_JAR,
                treasury: TREASURY,
                harborCommand: address(harborCommand),
                fleetCommanderRewardsManagerFactory: address(
                    rewardsManagerFactory
                )
            })
        );

        // Deploy real FleetCommander
        FleetCommanderParams memory fleetParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: BUFFER_MIN_BALANCE,
            initialRebalanceCooldown: 1 hours,
            asset: address(usdc),
            name: "Summer USDC Fleet",
            symbol: "sumUSDC",
            details: "Integration test fleet for USDC",
            initialTipRate: PercentageUtils.fromIntegerPercentage(1), // 1%
            depositCap: FLEET_DEPOSIT_CAP
        });

        vm.prank(GOVERNOR);
        fleetCommander = new FleetCommander(fleetParams);

        // Get buffer ark reference
        bufferArk = BufferArk(fleetCommander.bufferArk());

        // Setup access control
        vm.startPrank(GOVERNOR);
        accessManager.grantKeeperRole(address(fleetCommander), KEEPER);
        accessManager.grantCommanderRole(
            address(bufferArk),
            address(fleetCommander)
        );
        harborCommand.enlistFleetCommander(address(fleetCommander));
        vm.stopPrank();

        // Deploy Stargate adapter
        adapter = new StargateAdapter(
            BRIDGE_ROUTER,
            OWNER,
            address(lzEndpoint)
        );

        // Setup adapter configuration
        vm.startPrank(OWNER);
        adapter.addSupportedChain(
            DEST_CHAIN_ID,
            DEST_ENDPOINT_ID,
            address(adapter)
        );
        adapter.addSupportedAsset(address(usdc), address(stargate));
        vm.stopPrank();

        // Setup stargate mock
        stargate.setToken(address(usdc));
        stargate.setQuoteFee(0.01 ether);

        // Mint initial tokens
        usdc.mint(USER, INITIAL_USDC_BALANCE);

        // Labels for debugging
        vm.label(address(fleetCommander), "FleetCommander");
        vm.label(address(bufferArk), "BufferArk");
        vm.label(address(adapter), "StargateAdapter");
        vm.label(address(usdc), "USDC");
        vm.label(USER, "User");
        vm.label(SHARE_RECIPIENT, "ShareRecipient");
    }

    function test_CrossChainDepositToRealFleet_Success() public {
        // User approves adapter
        vm.prank(USER);
        usdc.approve(address(adapter), DEPOSIT_AMOUNT);

        // Get initial state
        uint256 userUsdcBefore = usdc.balanceOf(USER);
        uint256 fleetSharesBefore = fleetCommander.balanceOf(SHARE_RECIPIENT);
        uint256 bufferAssetsBefore = bufferArk.totalAssets();

        // Execute cross-chain deposit
        vm.prank(USER);
        vm.deal(USER, 1 ether);

        vm.expectEmit(true, true, true, false);
        emit CrossChainFleetDepositInitiated(
            bytes32(0), // Will be generated
            DEST_CHAIN_ID,
            USER,
            address(fleetCommander),
            address(usdc),
            DEPOSIT_AMOUNT,
            SHARE_RECIPIENT
        );

        bytes32 operationId = adapter.crossChainDepositToFleet{
            value: 0.01 ether
        }(
            DEST_CHAIN_ID,
            address(usdc),
            DEPOSIT_AMOUNT,
            address(fleetCommander),
            SHARE_RECIPIENT,
            "SUMMER2024",
            BridgeTypes.AdapterParams(bytes(""))
        );

        // Verify tokens were transferred from user to adapter
        assertEq(usdc.balanceOf(USER), userUsdcBefore - DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(address(adapter)), DEPOSIT_AMOUNT);

        // Verify operation ID was generated
        assertTrue(operationId != bytes32(0));

        // Simulate the compose message handling on destination chain
        _simulateDestinationCompose(operationId, DEPOSIT_AMOUNT);

        // Verify fleet deposit completed
        uint256 expectedShares = fleetCommander.previewDeposit(DEPOSIT_AMOUNT);
        assertEq(
            fleetCommander.balanceOf(SHARE_RECIPIENT),
            fleetSharesBefore + expectedShares
        );
        assertEq(bufferArk.totalAssets(), bufferAssetsBefore + DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(address(adapter)), 0); // Should be empty after successful deposit
    }

    function test_CrossChainDepositToRealFleet_WithReferralCode() public {
        bytes memory referralCode = "INTEGRATION_TEST_2024";

        vm.prank(USER);
        usdc.approve(address(adapter), DEPOSIT_AMOUNT);

        vm.prank(USER);
        vm.deal(USER, 1 ether);

        bytes32 operationId = adapter.crossChainDepositToFleet{
            value: 0.01 ether
        }(
            DEST_CHAIN_ID,
            address(usdc),
            DEPOSIT_AMOUNT,
            address(fleetCommander),
            SHARE_RECIPIENT,
            referralCode,
            BridgeTypes.AdapterParams(bytes(""))
        );

        // Simulate destination handling with referral code
        _simulateDestinationComposeWithReferral(
            operationId,
            DEPOSIT_AMOUNT,
            referralCode
        );

        // Verify successful deposit
        uint256 expectedShares = fleetCommander.previewDeposit(DEPOSIT_AMOUNT);
        assertEq(fleetCommander.balanceOf(SHARE_RECIPIENT), expectedShares);
    }

    function test_CrossChainDepositToRealFleet_ExceedsDepositCap() public {
        uint256 excessiveAmount = FLEET_DEPOSIT_CAP + 1;

        // Mint additional tokens
        usdc.mint(USER, excessiveAmount);

        vm.prank(USER);
        usdc.approve(address(adapter), excessiveAmount);

        vm.prank(USER);
        vm.deal(USER, 1 ether);

        bytes32 operationId = adapter.crossChainDepositToFleet{
            value: 0.01 ether
        }(
            DEST_CHAIN_ID,
            address(usdc),
            excessiveAmount,
            address(fleetCommander),
            SHARE_RECIPIENT,
            bytes(""),
            BridgeTypes.AdapterParams(bytes(""))
        );

        // This should fail on destination when trying to deposit to fleet
        _simulateDestinationComposeExpectingFailure(
            operationId,
            excessiveAmount
        );

        // Verify tokens are held by adapter for recovery
        assertEq(usdc.balanceOf(address(adapter)), excessiveAmount);

        // Check failed compose was recorded
        (
            address failedAsset,
            uint256 failedAmount,
            address intendedRecipient,
            ,
            ,
            ,
            ,
            bool isDeposit
        ) = adapter.failedComposes(operationId);

        assertEq(failedAsset, address(usdc));
        assertEq(failedAmount, excessiveAmount);
        assertEq(intendedRecipient, address(fleetCommander));
        assertTrue(isDeposit);
    }

    function test_FeeEstimationForRealFleet() public {
        // Create compose message for fleet deposit
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(fleetCommander),
            address(this), // share recipient
            address(usdc),
            depositAmount,
            block.chainid,
            bytes32(0), // operation ID
            address(this), // original user
            bytes("") // no referral code
        );

        (uint256 nativeFee, uint256 tokenFee) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(usdc),
            depositAmount,
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: composeMsg
            }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        assertEq(nativeFee, 0.01 ether);
        assertEq(tokenFee, 0);
    }

    function test_FleetCommanderSupportsExpectedAsset() public {
        assertEq(fleetCommander.asset(), address(usdc));
        assertGt(fleetCommander.maxDeposit(address(adapter)), DEPOSIT_AMOUNT);
    }

    function test_ManualRecoveryWithRealFleet() public {
        // First create a failed deposit scenario
        uint256 amount = DEPOSIT_AMOUNT;

        // Manually create a failed compose scenario
        bytes32 operationId = keccak256("manual-recovery-test");

        // Fund adapter as if from a failed bridge operation
        usdc.mint(address(adapter), amount);

        // Simulate failed compose recording
        vm.store(
            address(adapter),
            keccak256(abi.encode(operationId, uint256(0))), // failedComposes mapping slot
            bytes32(uint256(uint160(address(usdc)))) // asset
        );

        // Manual recovery by governance
        vm.prank(OWNER);
        adapter.manualRecovery(
            address(usdc),
            amount,
            SHARE_RECIPIENT,
            operationId,
            false, // Don't try receive call
            bytes("")
        );

        // Verify tokens were recovered
        assertEq(usdc.balanceOf(SHARE_RECIPIENT), amount);
        assertEq(usdc.balanceOf(address(adapter)), 0);
    }

    // Helper function to simulate compose message handling on destination
    function _simulateDestinationCompose(
        bytes32 operationId,
        uint256 amount
    ) internal {
        // Create fleet deposit compose message
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(usdc),
            amount,
            uint256(SOURCE_CHAIN_ID),
            operationId,
            USER,
            bytes("") // no referral code
        );

        // Mock OFT compose message encoding
        bytes memory oftMessage = abi.encodePacked(
            uint64(1), // nonce
            uint32(SOURCE_CHAIN_ID), // srcEid
            amount, // amountLD
            composeMsg
        );

        // Fund adapter with tokens (as if received from Stargate)
        usdc.mint(address(adapter), amount);

        // Simulate the endpoint call
        vm.expectEmit(true, true, true, true);
        emit CrossChainFleetDepositCompleted(
            operationId,
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(usdc),
            amount,
            amount, // 1:1 share ratio in this case
            SOURCE_CHAIN_ID
        );

        vm.prank(address(lzEndpoint));
        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );
    }

    // Helper function to simulate compose with referral code
    function _simulateDestinationComposeWithReferral(
        bytes32 operationId,
        uint256 amount,
        bytes memory referralCode
    ) internal {
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(usdc),
            amount,
            uint256(SOURCE_CHAIN_ID),
            operationId,
            USER,
            referralCode
        );

        bytes memory oftMessage = abi.encodePacked(
            uint64(1),
            uint32(SOURCE_CHAIN_ID),
            amount,
            composeMsg
        );

        usdc.mint(address(adapter), amount);

        vm.prank(address(lzEndpoint));
        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );
    }

    // Helper function to simulate failed compose
    function _simulateDestinationComposeExpectingFailure(
        bytes32 operationId,
        uint256 amount
    ) internal {
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(usdc),
            amount,
            uint256(SOURCE_CHAIN_ID),
            operationId,
            USER,
            bytes("")
        );

        bytes memory oftMessage = abi.encodePacked(
            uint64(1),
            uint32(SOURCE_CHAIN_ID),
            amount,
            composeMsg
        );

        usdc.mint(address(adapter), amount);

        // This should not revert but should record a failed compose
        vm.prank(address(lzEndpoint));
        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );
    }
}
