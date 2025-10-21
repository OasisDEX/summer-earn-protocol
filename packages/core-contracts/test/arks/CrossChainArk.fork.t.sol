// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {ICrossChainArk} from "@summerfi/chain-bridge/interfaces/ICrossChainArk.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {BridgeRouter, IBridgeRouter} from "@summerfi/chain-bridge/router/BridgeRouter.sol";
import {LayerZeroAdapter} from "@summerfi/chain-bridge/adapters/LayerZeroAdapter.sol";
import {StargateAdapter} from "@summerfi/chain-bridge/adapters/StargateAdapter.sol";
import {IStargateV2} from "@summerfi/chain-bridge/interfaces/IStargateV2.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MockStargateV2Pool} from "@summerfi/chain-bridge-test/mocks/MockStargateV2.sol";
import {CrossChainRegistry} from "@summerfi/chain-bridge/contracts/CrossChainRegistry.sol";
import {ConfigurationManager, ConfigurationManagerParams} from "../../src/contracts/ConfigurationManager.sol";
import {ICrossChainConfigManaged} from "@summerfi/chain-bridge/interfaces/ICrossChainConfigManaged.sol";

contract CrossChainArkForkTest is Test, ArkTestBase {
    event InflightCleared(bytes32 operationId, uint256 amount);
    CrossChainArk public ark;
    BridgeRouter public bridgeRouter;

    LayerZeroAdapter public layerZeroAdapter;
    StargateAdapter public stargateAdapter;
    IERC20 public usdc;
    MockStargateV2Pool public mockStargate;
    CrossChainRegistry public registry;

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Wraps a uint256 in BridgeTypes.RelayedMessageParams so that
    ///      CrossChainArk.receiveMessage can decode it.
    function _encodeMessage(
        bytes32 operationId,
        address originator,
        address arkAddress,
        uint256 balance,
        uint16 sourceChainId,
        bytes32 latestOutgoingTransferId
    ) internal view returns (BridgeTypes.RelayedMessageParams memory) {
        return
            BridgeTypes.RelayedMessageParams({
                operationId: operationId,
                originator: originator,
                sourceChainId: sourceChainId,
                recipient: arkAddress,
                message: abi.encode(
                    balance,
                    latestOutgoingTransferId,
                    block.timestamp
                )
            });
    }

    // LayerZero specific constants
    address public constant LZ_ENDPOINT_MAINNET =
        0x1a44076050125825900e736c501f859c50fE728c;
    uint16 public constant SOURCE_CHAIN_ID = 1; // Mainnet (where the test runs)
    uint16 public constant DEST_CHAIN_ID = 42161; // Arbitrum
    uint32 public constant ARB_LZ_EID = 30110; // LayerZero v2 EID for Arbitrum One
    address public constant ARB_STARGATE_PROXY = address(0x999); // Mock Stargate proxy address on Arbitrum
    address public constant ARB_LAYERZERO_PROXY = address(0x888); // Mock LayerZero proxy address on Arbitrum
    address public constant ARK_PROXY = address(0x777); // Different proxy address for ark

    uint256 public constant FORK_BLOCK = 22_145_762;

    event Boarded(address indexed commander, address token, uint256 amount);

    function setUp() public {
        // Create a mainnet fork
        vm.createSelectFork("mainnet", FORK_BLOCK);

        // First create access manager
        accessManager = new ProtocolAccessManager(governor);

        // Configure roles
        vm.startPrank(governor);
        accessManager.grantGuardianRole(guardian);

        // Deploy CrossChainRegistry first with CURRENT chain ID (mainnet = 1)
        registry = new CrossChainRegistry(address(accessManager));

        // Create router
        bridgeRouter = new BridgeRouter(
            address(accessManager),
            address(registry)
        );

        // Now that both contracts are deployed, initialize the bridge configuration
        registry.setBridgeRouter(address(bridgeRouter));

        // Register the BridgeRouter as an executor
        registry.registerExecutor(address(bridgeRouter));

        vm.stopPrank();

        // ------------------------------------------------------------------
        // Core-protocol configuration manager (needed by ArkConfigProvider)
        // ------------------------------------------------------------------
        configurationManager = new ConfigurationManager(address(accessManager));
        vm.startPrank(governor);
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                tipJar: address(0xdead),
                raft: address(0xbeef), // any non-zero address is fine for the test
                treasury: address(0xcafe),
                harborCommand: address(0xface)
            })
        );
        vm.stopPrank();

        // Setup LayerZero adapter
        uint16[] memory supportedChains = new uint16[](1);
        uint32[] memory lzEids = new uint32[](1);
        supportedChains[0] = DEST_CHAIN_ID;
        lzEids[0] = ARB_LZ_EID;

        layerZeroAdapter = new LayerZeroAdapter(
            LZ_ENDPOINT_MAINNET,
            address(registry),
            address(accessManager),
            supportedChains,
            lzEids,
            governor
        );

        // Setup Stargate adapter
        uint16[] memory stgSupportedChains = new uint16[](1);
        uint32[] memory stgLzEids = new uint32[](1);
        stgSupportedChains[0] = DEST_CHAIN_ID;
        stgLzEids[0] = ARB_LZ_EID;

        stargateAdapter = new StargateAdapter(
            address(registry), // _crossChainRegistry
            address(accessManager), // _accessManager
            LZ_ENDPOINT_MAINNET
        );

        // Register adapters with router
        vm.startPrank(governor);
        bridgeRouter.registerAdapter(address(layerZeroAdapter));
        bridgeRouter.registerAdapter(address(stargateAdapter));

        // Configure Stargate adapter endpoints and relationships
        stargateAdapter.mapExternalId(DEST_CHAIN_ID, ARB_LZ_EID);
        stargateAdapter.mapExternalId(uint16(block.chainid), ARB_LZ_EID);

        // Initialize USDC
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        // Deploy mock Stargate contract
        mockStargate = new MockStargateV2Pool(address(usdc));

        // Add USDC as supported asset for Stargate adapter
        stargateAdapter.addSupportedAsset(address(usdc), address(mockStargate));

        // Set up peer for Arbitrum chain (LayerZero)
        bytes32 peerAddressBytes32 = bytes32(
            uint256(uint160(ARB_LAYERZERO_PROXY))
        );
        layerZeroAdapter.setPeer(ARB_LZ_EID, peerAddressBytes32);

        // READ_STATE channel activation removed

        // Register cross-chain relationships in registry using peer pair registration
        registry.registerAdapterPeerPair(
            address(stargateAdapter),
            ARB_STARGATE_PROXY,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID
        );

        // Register LayerZero adapter with different proxy address using peer pair registration
        registry.registerAdapterPeerPair(
            address(layerZeroAdapter),
            ARB_LAYERZERO_PROXY,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID
        );

        // Register the BridgeRouter as an executor

        vm.stopPrank();

        // Create Ark with bridge configuration
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Create CrossChainArk with the proper CrossChainConfigManager
        ark = new CrossChainArk(address(registry), DEST_CHAIN_ID, params);

        // Register the ark-proxy relationship - use a different proxy address to avoid conflicts using peer pair registration
        vm.startPrank(governor);
        registry.registerAdapterPeerPair(
            address(ark),
            ARK_PROXY,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID
        );

        // Setup permissions
        accessManager.grantCommanderRole(address(ark), commander);
        accessManager.grantKeeperRole(address(ark), commander);
        // Grant keeper role to the dedicated keeper address used in tests
        accessManager.grantKeeperRole(address(ark), keeper);
        registry.registerExecutor(address(ark));
        vm.stopPrank();

        // Register fleet commander
        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_CrossChain() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);
        vm.prank(commander);
        usdc.approve(address(ark), amount);

        // Create executeTransferParams for the board call
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(usdc),
                amount: amount,
                target: ARK_PROXY, // Use ark proxy for asset transfers
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(stargateAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory executeTransferParams = abi.encode(params, options);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act - Board the assets (this stores pending transfer params)
        vm.prank(commander);
        ark.board(amount, executeTransferParams);

        // Assert - Verify the pending transfer params were stored correctly
        (
            address originator,
            uint16 destinationChainId,
            address target,
            address asset,
            uint256 storedAmount,
            bytes memory _message,
            address refundAddress
        ) = ark.pendingTransferParams();

        (
            address specifiedAdapter,
            uint64 gasLimit,
            uint32 calldataSize,
            uint128 msgValue,
            uint256 feeTokenAmount,
            bool payInProtocolToken,
            bytes memory opts
        ) = ark.pendingTransferOptions();

        assertEq(
            destinationChainId,
            DEST_CHAIN_ID,
            "Incorrect destination chain ID"
        );
        assertEq(asset, address(usdc), "Incorrect asset address");
        assertEq(storedAmount, amount, "Incorrect stored amount");
        assertEq(target, ARK_PROXY, "Incorrect recipient address");
        assertEq(originator, address(ark), "Incorrect originator address");
        assertEq(refundAddress, commander, "Incorrect keeper address");
        assertEq(
            specifiedAdapter,
            address(stargateAdapter),
            "Incorrect adapter address"
        );
        assertEq(gasLimit, 200000, "Incorrect gas limit");
        assertEq(msgValue, 0, "Incorrect msg value");
        assertEq(calldataSize, 0, "Incorrect calldata size");

        // Verify assets were transferred to ark
        assertEq(
            usdc.balanceOf(commander),
            0,
            "Commander should have no USDC after boarding"
        );
        assertEq(
            usdc.balanceOf(address(ark)),
            amount,
            "Ark should hold the USDC"
        );
    }

    function test_FullIntegration_DepositToStargateSwap() public {
        // === STEP 1: Deposit to CrossChain (Board) ===
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);
        vm.prank(commander);
        usdc.approve(address(ark), amount);

        // Verify initial balances
        assertEq(
            usdc.balanceOf(commander),
            amount,
            "Commander should have initial USDC"
        );
        assertEq(
            usdc.balanceOf(address(ark)),
            0,
            "Ark should start with no USDC"
        );

        // Create executeTransferParams for the board call
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(stargateAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        BridgeTypes.ExecuteTransferParams memory transferParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(usdc),
                amount: amount,
                target: ARK_PROXY, // Use ark proxy for asset transfers
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        bytes memory executeTransferParams = abi.encode(
            transferParams,
            options
        );

        // Board the assets - this stores pending transfer params
        vm.prank(commander);
        ark.board(amount, executeTransferParams);

        // Verify assets were transferred to ark and pending params stored
        assertEq(
            usdc.balanceOf(commander),
            0,
            "Commander should have no USDC after boarding"
        );
        assertEq(
            usdc.balanceOf(address(ark)),
            amount,
            "Ark should hold the USDC"
        );

        // === STEP 2: Verify Pending Transfer Params ===
        (
            address originator,
            uint16 destinationChainId,
            address target,
            address asset,
            uint256 storedAmount,
            bytes memory _message,
            address refundAddress
        ) = ark.pendingTransferParams();

        (
            address specifiedAdapter,
            uint64 gasLimit,
            uint32 calldataSize,
            uint128 msgValue,
            uint256 feeTokenAmount,
            bool payInProtocolToken,
            bytes memory opts
        ) = ark.pendingTransferOptions();

        assertEq(
            destinationChainId,
            DEST_CHAIN_ID,
            "Incorrect destination chain ID"
        );
        assertEq(asset, address(usdc), "Incorrect asset address");
        assertEq(storedAmount, amount, "Incorrect stored amount");
        assertEq(target, ARK_PROXY, "Incorrect recipient address");
        assertEq(originator, address(ark), "Incorrect originator address");
        assertEq(refundAddress, commander, "Incorrect keeper address");
        assertEq(
            specifiedAdapter,
            address(stargateAdapter),
            "Incorrect adapter address"
        );
        assertEq(gasLimit, 200000, "Incorrect gas limit");
        assertEq(msgValue, 0, "Incorrect msg value");
        assertEq(calldataSize, 0, "Incorrect calldata size");
        assertEq(opts, "", "Incorrect options");
        // === STEP 3: Get Quote and Execute Transfer ===
        (uint256 nativeFee, uint256 tokenFee, ) = bridgeRouter
            .quoteTransferAssets(transferParams, options);

        assertGt(nativeFee, 0, "Native fee should be greater than 0");
        assertEq(tokenFee, 0, "Token fee should be 0 for Stargate");

        // Verify the mock Stargate contract is properly configured
        assertEq(
            mockStargate.TOKEN(),
            address(usdc),
            "Mock Stargate should be configured for USDC"
        );
        assertEq(
            uint8(mockStargate.stargateType()),
            uint8(IStargateV2.StargateType.Pool),
            "Mock Stargate should be Pool type"
        );

        // === STEP 4: Execute Transfer Directly via Ark ===
        uint256 preExecutionBalance = usdc.balanceOf(address(ark));
        vm.deal(commander, nativeFee);

        // Expect TransferInitiated event from BridgeRouter
        vm.expectEmit(false, true, true, true);
        emit IBridgeRouter.TransferInitiated(
            bytes32(0), // We can't predict the operationId
            DEST_CHAIN_ID,
            address(usdc),
            amount,
            ARK_PROXY,
            address(stargateAdapter)
        );

        // Execute the transfer directly
        vm.prank(commander);
        ark.executeTransferAssets{value: nativeFee}();

        // === STEP 5: Verify Execution Results ===
        // Verify token flow: tokens should have moved from ark
        assertLt(
            usdc.balanceOf(address(ark)),
            preExecutionBalance,
            "Ark balance should decrease after execution"
        );

        // Verify that the transfer was successful by checking the mock Stargate contract received the tokens
        // The MockStargateV2 contract consumes the tokens when sendToken is called, simulating real Stargate behavior
        assertEq(
            usdc.balanceOf(address(mockStargate)),
            amount,
            "MockStargateV2 should hold the tokens after mock transfer"
        );

        // Verify StargateAdapter no longer holds the tokens (they were transferred to Stargate)
        assertEq(
            usdc.balanceOf(address(stargateAdapter)),
            0,
            "StargateAdapter should not hold tokens after transfer to Stargate"
        );

        // Verify pending transfer params were cleared
        (
            address originator2,
            uint16 clearedChainId,
            address target2,
            address asset2,
            uint256 storedAmount2,
            bytes memory message2,
            address refundAddress2
        ) = ark.pendingTransferParams();
        (
            address specifiedAdapter2,
            uint64 gasLimit2,
            uint32 calldataSize2,
            uint128 msgValue2,
            uint256 feeTokenAmount2,
            bool payInProtocolToken2,
            bytes memory opts2
        ) = ark.pendingTransferOptions();
        assertEq(
            clearedChainId,
            0,
            "Pending transfer params should be cleared"
        );
        assertEq(
            originator2,
            address(0),
            "Pending transfer params should be cleared"
        );
        assertEq(
            target2,
            address(0),
            "Pending transfer params should be cleared"
        );
        assertEq(
            asset2,
            address(0),
            "Pending transfer params should be cleared"
        );
        assertEq(storedAmount2, 0, "Pending transfer params should be cleared");
        assertEq(message2, "", "Pending transfer params should be cleared");
        assertEq(
            refundAddress2,
            address(0),
            "Pending transfer params should be cleared"
        );
        assertEq(
            specifiedAdapter2,
            address(0),
            "Pending transfer params should be cleared"
        );
        assertEq(gasLimit2, 0, "Pending transfer params should be cleared");
        assertEq(msgValue2, 0, "Pending transfer params should be cleared");
        assertEq(calldataSize2, 0, "Pending transfer params should be cleared");
        assertEq(opts2, "", "Pending transfer params should be cleared");
        // === STEP 6: Integration Test Success Verification ===
        emit log_named_uint("Native Fee Paid", nativeFee);
        emit log_named_address("Keeper", commander);
        emit log_named_uint("Amount Transferred", amount);
        emit log_named_address("Destination", ARK_PROXY);
        emit log_string(
            "SUCCESS: Full integration test completed - CrossChain Ark -> BridgeRouter -> Stargate Adapter"
        );
    }

    function test_ExecuteTransfer_SetsInflightAssets() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC

        // Fund keeper/commander and approve Ark to take funds on board
        deal(address(usdc), commander, amount);
        vm.prank(commander);
        usdc.approve(address(ark), amount);

        // Prepare options and params for a Stargate transfer
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(stargateAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(usdc),
                amount: amount,
                target: ARK_PROXY,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });

        // Board the assets to set pending transfer (Ark holds tokens)
        bytes memory executeTransferParams = abi.encode(params, options);
        vm.prank(commander);
        ark.board(amount, executeTransferParams);

        // Quote and execute transfer via Ark (keeper role is granted to commander)
        (uint256 nativeFee, , ) = bridgeRouter.quoteTransferAssets(
            params,
            options
        );
        vm.deal(commander, nativeFee);

        vm.prank(commander);
        ark.executeTransferAssets{value: nativeFee}();

        // After execution, BridgeRouter should have called updateInflightAssets on Ark
        assertEq(
            ark.inflightAssets(),
            amount,
            "Inflight assets should equal transfer amount"
        );
    }

    // Event declaration for the event we expect from StargateAdapter
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );

    function testDisembarkWhileTransferPendingVulnerability() public {
        // Setup: Fund the ark with initial assets
        uint256 initialArkBalance = 2000e18; // 2000 tokens
        deal(address(usdc), address(ark), initialArkBalance);

        // Setup: Fund the FleetCommander with tokens for boarding
        uint256 fleetCommanderBalance = 2000e18; // 2000 tokens (enough for the transfer)
        deal(address(usdc), address(commander), fleetCommanderBalance);
        vm.prank(address(commander));
        usdc.approve(address(ark), type(uint256).max);

        // Step 1: Initiate a transfer (board) but don't execute it yet
        uint256 transferAmount = 1500e18; // 1500 tokens to transfer
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(usdc),
                amount: transferAmount,
                target: ARK_PROXY,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(stargateAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory executeTransferParams = abi.encode(params, options);

        // Board the transfer (this queues it but doesn't execute)
        vm.prank(address(commander));
        ark.board(transferAmount, executeTransferParams);

        // Step 2: Disembark a significant amount from the ark
        // This reduces the ark's local balance below what's needed for the pending transfer
        uint256 disembarkAmount = 2500e18; // Disembark more than enough to create insufficient balance
        vm.prank(address(commander));
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainArk.PendingTransferAlreadyQueued.selector
            )
        );
        ark.disembark(disembarkAmount, bytes("keeper_data")); // CrossChainArk requires keeper data

        deal(keeper, 10000000000000000);
        // Step 3: This test EXPECTS the transfer to succeed
        vm.prank(keeper);
        ark.executeTransferAssets{value: 10000000000000000}();

        (, , , address assetAfterExecution, , , ) = ark.pendingTransferParams();
        assertTrue(
            assetAfterExecution == address(0),
            "Transfer should have succeeded"
        );
    }
}
