// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {BridgeRouter} from "@summerfi/chain-bridge/router/BridgeRouter.sol";
import {BridgeQueue} from "@summerfi/chain-bridge/router/BridgeQueue.sol";
import {LayerZeroAdapter} from "@summerfi/chain-bridge/adapters/LayerZeroAdapter.sol";
import {StargateAdapter} from "@summerfi/chain-bridge/adapters/StargateAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

// Mock Stargate V2 contract for testing
contract MockStargateV2 {
    enum StargateType {
        Pool,
        OFT
    }

    struct Ticket {
        uint56 ticketId;
        bytes passenger;
    }

    address public immutable token;
    StargateType public immutable stargateType;

    constructor(address _token, StargateType _stargateType) {
        token = _token;
        stargateType = _stargateType;
    }

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address
    )
        external
        payable
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt,
            Ticket memory ticket
        )
    {
        // Mock implementation - just return mock structs
        msgReceipt = MessagingReceipt({
            guid: bytes32(uint256(1)),
            nonce: 1,
            fee: _fee
        });

        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.amountLD
        });

        ticket = Ticket({ticketId: 1, passenger: ""});
    }

    function quoteSend(
        SendParam calldata,
        bool
    ) external pure returns (MessagingFee memory msgFee) {
        // Return a mock fee
        msgFee = MessagingFee({nativeFee: 0.01 ether, lzTokenFee: 0});
    }

    function quoteOFT(
        SendParam calldata _sendParam
    )
        external
        pure
        returns (uint256 limit, uint256 oftLimit, OFTReceipt memory oftReceipt)
    {
        // Mock implementation
        limit = _sendParam.amountLD;
        oftLimit = _sendParam.amountLD;
        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.amountLD
        });
    }
}

contract CrossChainArkForkTest is Test, ArkTestBase {
    CrossChainArk public ark;
    BridgeRouter public bridgeRouter;
    BridgeQueue public bridgeQueue;
    LayerZeroAdapter public layerZeroAdapter;
    StargateAdapter public stargateAdapter;
    IERC20 public usdc;
    MockStargateV2 public mockStargate;

    // LayerZero specific constants
    address public constant LZ_ENDPOINT_MAINNET =
        0x1a44076050125825900e736c501f859c50fE728c;
    uint16 public constant DEST_CHAIN_ID = 42161; // Arbitrum
    uint32 public constant ARB_LZ_EID = 30110; // LayerZero v2 EID for Arbitrum One
    address public constant ARB_PROXY = address(0x999); // Mock proxy address on Arbitrum

    uint256 public constant FORK_BLOCK = 22_145_762;

    event Boarded(address indexed commander, address token, uint256 amount);

    function setUp() public {
        // Create a mainnet fork
        vm.createSelectFork("mainnet", FORK_BLOCK);

        initializeCoreContracts();
        setupBridgeContracts();
    }

    function setupBridgeContracts() internal {
        // Create access manager
        accessManager = new ProtocolAccessManager(governor);

        // Configure roles
        vm.startPrank(governor);
        accessManager.grantGuardianRole(guardian);
        vm.stopPrank();

        // Initialize chain router mappings
        uint16[] memory chainIds = new uint16[](1);
        address[] memory routerAddresses = new address[](1);
        chainIds[0] = DEST_CHAIN_ID;
        routerAddresses[0] = address(0x999); // Mock remote router address

        // Deploy BridgeQueue
        bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Temporarily 0, will be set later
            commander // Make the commander the queue manager
        );

        // Create router, passing the deployed BridgeQueue address
        bridgeRouter = new BridgeRouter(
            address(accessManager),
            address(bridgeQueue)
        );

        // Set the bridge router address in the queue
        vm.startPrank(governor);
        bridgeQueue.setBridgeRouter(address(bridgeRouter));
        vm.stopPrank();

        // Setup LayerZero adapter
        uint16[] memory supportedChains = new uint16[](1);
        uint32[] memory lzEids = new uint32[](1);
        supportedChains[0] = DEST_CHAIN_ID;
        lzEids[0] = ARB_LZ_EID;

        layerZeroAdapter = new LayerZeroAdapter(
            LZ_ENDPOINT_MAINNET,
            address(bridgeRouter),
            supportedChains,
            lzEids,
            governor
        );

        // Setup Stargate adapter
        stargateAdapter = new StargateAdapter(address(bridgeRouter), governor);

        // Register adapters with router
        vm.startPrank(governor);
        bridgeRouter.registerAdapter(address(layerZeroAdapter));
        bridgeRouter.registerAdapter(address(stargateAdapter));

        // Configure Stargate adapter
        stargateAdapter.addSupportedChain(DEST_CHAIN_ID, ARB_LZ_EID);
        stargateAdapter.addSupportedChain(uint16(block.chainid), ARB_LZ_EID); // Add current chain (mainnet)

        // Initialize USDC
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        // Deploy mock Stargate contract
        mockStargate = new MockStargateV2(
            address(usdc),
            MockStargateV2.StargateType.Pool
        );

        // Add USDC as supported asset for Stargate adapter on both chains
        // Current chain (mainnet) - needed for the adapter to find the Stargate contract
        stargateAdapter.addSupportedAsset(
            uint16(block.chainid), // Current chain
            address(usdc),
            address(mockStargate)
        );

        // Destination chain (Arbitrum)
        stargateAdapter.addSupportedAsset(
            DEST_CHAIN_ID,
            address(usdc),
            address(mockStargate)
        );

        // Set up peer for Arbitrum chain (LayerZero)
        bytes32 peerAddressBytes32 = bytes32(uint256(uint160(ARB_PROXY)));
        layerZeroAdapter.setPeer(ARB_LZ_EID, peerAddressBytes32);

        // Activate the read channel for state reading operations
        uint32 READ_CHANNEL_ID = 4294967295;
        layerZeroAdapter.activateReadChannel(READ_CHANNEL_ID);
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
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new CrossChainArk(
            address(bridgeQueue),
            address(bridgeRouter),
            DEST_CHAIN_ID,
            params
        );

        // Set the target proxy
        vm.prank(governor);
        ark.setTargetProxy(ARB_PROXY);

        // Add ark as queue manager
        vm.startPrank(governor);
        bridgeQueue.addQueueManager(address(ark));
        vm.stopPrank();

        // Permissioning
        vm.prank(governor);
        accessManager.grantCommanderRole(address(ark), commander);

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

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act
        vm.prank(commander);
        ark.board(amount, bytes(""));

        // Assert
        // Get the first pending queue ID (should be the one created by the board call)
        bytes32 queueId = bridgeQueue.getPendingQueueIdAtIndex(0);
        (
            uint16 destinationChainId,
            address asset,
            uint256 queuedAmount,
            address recipient,
            address originator,
            bytes32 operationId
        ) = bridgeQueue.queuedTransfers(queueId);

        // Verify all the queued transfer parameters
        assertEq(
            destinationChainId,
            DEST_CHAIN_ID,
            "Incorrect destination chain ID"
        );
        assertEq(asset, address(usdc), "Incorrect asset address");
        assertEq(queuedAmount, amount, "Incorrect queued amount");
        assertEq(recipient, ARB_PROXY, "Incorrect recipient address");
        assertEq(originator, address(ark), "Incorrect originator address");
        assertEq(
            operationId,
            bytes32(0),
            "Operation ID should be zero initially"
        );
    }

    function test_ReadState_CrossChain() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);
        vm.prank(commander);
        usdc.approve(address(ark), amount);
        vm.prank(commander);
        ark.board(amount, bytes(""));

        // Mock the remote balance response
        uint256 remoteBalance = 1000 * 10 ** 6;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256(
            abi.encode(
                DEST_CHAIN_ID,
                address(usdc),
                bytes4(keccak256("balanceOf(address)")),
                abi.encode(ARB_PROXY),
                block.timestamp,
                address(ark)
            )
        );

        // Mock the router's notifyMessageReceived function
        vm.mockCall(
            address(bridgeRouter),
            abi.encodeWithSelector(bridgeRouter.notifyMessageReceived.selector),
            abi.encode()
        );

        // Simulate receiving the state read response
        vm.prank(address(bridgeRouter));
        ark.receiveStateRead(
            resultData,
            address(ark),
            DEST_CHAIN_ID,
            requestId
        );

        // Assert that the remote balance was updated
        assertEq(
            ark.totalAssets(),
            amount + remoteBalance,
            "Total assets should include both local and remote balances"
        );
    }

    function test_FullIntegration_DepositToStargateSwap() public {
        // === STEP 1: Deposit to CrossChain (Board) ===
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);
        vm.prank(commander);
        usdc.approve(address(ark), amount);

        // Board the assets - this should queue them
        vm.prank(commander);
        ark.board(amount, bytes(""));

        // Verify assets are queued
        bytes32 queueId = bridgeQueue.getPendingQueueIdAtIndex(0);
        assertEq(
            uint8(bridgeQueue.queueIdToStatus(queueId)),
            uint8(BridgeTypes.OperationStatus.QUEUED),
            "Operation should be queued"
        );

        // === STEP 2: Setup for Stargate Adapter ===
        // No mocking needed - we have a real mock contract deployed

        // === STEP 3: Keeper Executes Queued Operation ===
        address keeper = makeAddr("keeper");
        vm.deal(keeper, 10 ether); // Give keeper ETH for fees

        // Get quote for execution using Stargate adapter
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(stargateAdapter), // Use Stargate adapter
            adapterParams: BridgeTypes.AdapterParams({
                gasLimit: 200000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            })
        });

        (uint256 nativeFee, , ) = bridgeRouter.quote(
            DEST_CHAIN_ID,
            address(usdc),
            amount,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Keeper executes the queued operation
        vm.prank(keeper);
        bytes32 operationId = bridgeQueue.executeQueuedOperation{
            value: nativeFee
        }(queueId, options);

        // === STEP 4: Verify Execution Results ===
        // Check that operation status changed to SENT
        assertEq(
            uint8(bridgeQueue.queueIdToStatus(queueId)),
            uint8(BridgeTypes.OperationStatus.SENT),
            "Operation should be marked as SENT"
        );

        // Verify operation ID mapping
        assertEq(
            bridgeQueue.operationIdToQueueId(operationId),
            queueId,
            "Operation ID should map back to queue ID"
        );

        // Verify assets were transferred from commander to router/adapter
        assertEq(
            usdc.balanceOf(commander),
            0,
            "Commander should have no USDC left"
        );

        // Verify pending queue is empty
        assertEq(
            bridgeQueue.getPendingQueueCount(),
            0,
            "Pending queue should be empty after execution"
        );

        // === STEP 5: Verify Cross-Chain Transfer Initiated ===
        // In a real integration test, you would:
        // 1. Check that the adapter called the underlying protocol (Stargate)
        // 2. Verify the cross-chain message was properly formatted
        // 3. Potentially simulate the message being received on the destination chain

        // For this test, we can verify the operation was processed
        assertTrue(
            operationId != bytes32(0),
            "Operation ID should be non-zero"
        );

        emit log_named_bytes32("Executed Operation ID", operationId);
        emit log_named_uint("Native Fee Paid", nativeFee);
        emit log_named_address("Keeper", keeper);
        emit log_string(
            "SUCCESS: Full integration test completed with Stargate adapter"
        );
    }
}
