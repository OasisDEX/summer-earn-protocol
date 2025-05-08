// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {BridgeRouter} from "@summerfi/chain-bridge/router/BridgeRouter.sol";
import {BridgeQueue} from "@summerfi/chain-bridge/router/BridgeQueue.sol";
import {LayerZeroAdapter} from "@summerfi/chain-bridge/adapters/LayerZeroAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {ArkTestBase} from "./ArkTestBase.sol";

contract CrossChainArkForkTest is Test, ArkTestBase {
    CrossChainArk public ark;
    BridgeRouter public bridgeRouter;
    BridgeQueue public bridgeQueue;
    LayerZeroAdapter public layerZeroAdapter;
    IERC20 public usdc;

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
            address(bridgeQueue),
            chainIds,
            routerAddresses
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

        // Register adapter with router
        vm.startPrank(governor);
        bridgeRouter.registerAdapter(address(layerZeroAdapter));

        // Set up peer for Arbitrum chain
        bytes32 peerAddressBytes32 = bytes32(uint256(uint160(ARB_PROXY)));
        layerZeroAdapter.setPeer(ARB_LZ_EID, peerAddressBytes32);

        // Activate the read channel for state reading operations
        uint32 READ_CHANNEL_ID = 4294967295;
        layerZeroAdapter.activateReadChannel(READ_CHANNEL_ID);
        vm.stopPrank();

        // Initialize USDC
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

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

        BridgeTypes.BridgeOptions memory bridgeOptions = BridgeTypes
            .BridgeOptions({
                specifiedAdapter: address(layerZeroAdapter),
                adapterParams: BridgeTypes.AdapterParams({
                    gasLimit: 500000,
                    calldataSize: 0,
                    msgValue: 0,
                    options: ""
                })
            });

        ark = new CrossChainArk(
            address(bridgeQueue),
            address(bridgeRouter),
            DEST_CHAIN_ID,
            ARB_PROXY,
            bridgeOptions,
            params
        );

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
            BridgeTypes.BridgeOptions memory options,
            address originator,

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
            options.specifiedAdapter,
            address(layerZeroAdapter),
            "Incorrect adapter specified"
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
}
