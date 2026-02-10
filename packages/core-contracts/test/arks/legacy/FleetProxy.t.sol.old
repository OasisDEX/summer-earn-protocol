// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {ICrossChainRegistry} from "@summerfi/chain-bridge/interfaces/ICrossChainRegistry.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {MockAdapter} from "@summerfi/chain-bridge-test/mocks/MockAdapter.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {ArkParams} from "../../src/contracts/Ark.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {Raft} from "../../src/contracts/Raft.sol";
import {FleetProxy} from "../../src/contracts/FleetProxy.sol";
import {IFleetProxy} from "../../src/interfaces/IFleetProxy.sol";
import {CrossChainRegistry} from "@summerfi/chain-bridge/contracts/CrossChainRegistry.sol";

uint16 constant DEST_CHAIN_ID = 42161;

contract CrossChainFleetProxyTest is Test {
    // Constants
    uint16 constant SOURCE_CHAIN_ID = 111;
    address constant SOURCE_ARK_ADDRESS = address(0xBEEF);
    address constant MOCK_ADAPTER = address(0xADADADA); // Mock adapter address

    // Role constants
    bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    // Contracts under test
    FleetProxy public proxy;

    // Mocks
    ERC20Mock public mockToken;
    MockBridgeRouter public mockBridgeRouter;
    ProtocolAccessManager public accessManager;
    MockAdapter public mockAdapter;
    ArkMock public bufferArkMock;
    FleetCommanderMock public fleetCommanderMock;

    // Test addresses
    address public governor = address(1);
    address public guardian = address(2);
    address public pauser = address(3);
    ConfigurationManager public configurationManager;
    Raft public raft;
    CrossChainRegistry public registry;

    // Define separate target proxies for each adapter
    address public constant ARB_STARGATE_PROXY = address(0x999); // Mock Stargate proxy address on Arbitrum
    address public constant ARB_LAYERZERO_PROXY = address(0x998); // Mock LayerZero proxy address on Arbitrum

    function setUp() public {
        // Deploy mocks
        mockToken = new ERC20Mock();
        mockBridgeRouter = new MockBridgeRouter();
        accessManager = new ProtocolAccessManager(governor);
        registry = new CrossChainRegistry(
            address(accessManager),
            DEST_CHAIN_ID // current chain ID
        );
        mockAdapter = new MockAdapter(
            address(registry),
            address(accessManager)
        );
        mockBridgeRouter.registerAdapter(address(mockAdapter));

        // Deploy configuration manager and raft
        configurationManager = new ConfigurationManager(address(accessManager));
        raft = new Raft(address(accessManager));

        // Set up configuration manager
        vm.startPrank(governor);
        configurationManager.setRaft(address(raft));
        vm.stopPrank();

        fleetCommanderMock = new FleetCommanderMock(
            address(mockToken),
            address(0),
            PercentageUtils.fromFraction(1, 100)
        );

        bufferArkMock = new ArkMock(
            ArkParams({
                name: "BufferArkMock",
                details: "BufferArkMock details",
                accessManager: address(accessManager),
                configurationManager: address(configurationManager),
                asset: address(mockToken),
                depositCap: type(uint256).max,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                requiresKeeperData: false,
                maxDepositPercentageOfTVL: PercentageUtils.fromFraction(1, 100)
            })
        );

        fleetCommanderMock.setBufferArk(address(bufferArkMock));

        // Set up access control
        vm.startPrank(governor);
        accessManager.grantGuardianRole(guardian);
        accessManager.grantGovernorRole(governor);
        vm.stopPrank();

        // Initialize the bridge configuration in the registry
        vm.startPrank(governor);
        registry.initializeBridgeConfiguration(
            address(mockBridgeRouter),
            200000 // defaultGasLimit
        );

        // Create FleetProxy with the proper CrossChainConfigManager
        proxy = new FleetProxy(
            address(accessManager),
            address(mockBridgeRouter),
            address(registry),
            address(fleetCommanderMock),
            SOURCE_CHAIN_ID
        );

        // Register cross-chain relationships in registry
        registry.registerRelationship(
            address(bufferArkMock), // Use the ArkMock as the source
            ARB_STARGATE_PROXY, // Different target for Stargate
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );

        // Register LayerZero adapter with different target
        registry.registerRelationship(
            address(mockAdapter), // Use the mockAdapter as the source
            ARB_LAYERZERO_PROXY, // Different target for LayerZero
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );

        // Register the ark-proxy relationship
        registry.registerRelationship(
            SOURCE_ARK_ADDRESS,
            address(proxy),
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            keccak256("ARK_FLEET_RELATIONSHIP")
        );

        accessManager.grantKeeperRole(address(proxy), governor);

        mockBridgeRouter.registerAdapter(address(mockAdapter));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Build a well-formed deliver payload for the given asset.
    function _buildDeliverPayload(
        address asset
    ) internal view returns (bytes memory) {
        BridgeTypes.DeliverPayload memory dp = BridgeTypes.DeliverPayload({
            operationId: keccak256(
                abi.encodePacked("op", asset, block.timestamp)
            ),
            originator: address(this),
            sourceAsset: asset
        });
        return abi.encode(dp);
    }

    /// @dev Build an “empty” payload (operationId == 0x0) – this triggers
    ///      the MessageContentNotExpected branch in the proxy.
    function _buildEmptyPayload() internal pure returns (bytes memory) {
        BridgeTypes.DeliverPayload memory dp = BridgeTypes.DeliverPayload({
            operationId: bytes32(0),
            originator: address(0),
            sourceAsset: address(0)
        });
        return abi.encode(dp);
    }

    /// @dev Build a well-formed delivered transfer params for the given asset.
    function _buildDeliveredTransferParams(
        address asset,
        uint256 amount,
        bytes memory message,
        uint16 sourceChainId
    ) internal view returns (BridgeTypes.RelayedTransferParams memory) {
        return
            BridgeTypes.RelayedTransferParams({
                operationId: keccak256(
                    abi.encodePacked("op", asset, block.timestamp)
                ),
                originator: SOURCE_ARK_ADDRESS,
                sourceChainId: sourceChainId,
                recipient: address(proxy),
                asset: asset,
                amount: amount,
                message: message
            });
    }
    //----------------- Constructor Tests -----------------//

    function test_Constructor() public view {
        // Test all constructor values are properly initialized
        assertEq(address(proxy.bridgeRouter()), address(mockBridgeRouter));
        assertEq(address(proxy.crossChainRegistry()), address(registry));
        assertEq(proxy.fleetAddress(), address(fleetCommanderMock));

        // Verify registry relationship works
        address arkFromRegistry = registry.getSourceForTarget(
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(proxy),
            keccak256("ARK_FLEET_RELATIONSHIP")
        );
        assertEq(arkFromRegistry, SOURCE_ARK_ADDRESS);
    }

    //----------------- Administrative Tests -----------------//

    function test_PauseUnpause() public {
        // Test pause - guardian can pause
        vm.prank(guardian);
        proxy.pause();
        assertTrue(proxy.paused());

        // Verify operations are blocked when paused
        // Try to receive assets while paused
        address asset = address(mockToken);
        uint256 amount = 1000;
        bytes memory message = _buildDeliverPayload(asset);
        mockToken.mint(address(proxy), amount);

        // Should revert with Paused error
        vm.prank(address(mockBridgeRouter));
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    asset,
                    amount,
                    message,
                    SOURCE_CHAIN_ID
                )
            )
        );

        // Setup keeper role for testing withdrawAndTransfer
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(proxy), governor);
        vm.stopPrank();

        // Try withdrawAndTransfer while paused
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        proxy.withdrawAndTransfer(
            100,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            })
        );

        // Non-governor can't unpause
        vm.prank(guardian);
        vm.expectRevert();
        proxy.unpause();

        // Governor can unpause
        vm.prank(governor);
        proxy.unpause();
        assertFalse(proxy.paused());

        // Operations should work after unpausing
        vm.prank(address(mockBridgeRouter));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    asset,
                    amount,
                    message,
                    SOURCE_CHAIN_ID
                )
            )
        );
        assertEq(fleetCommanderMock.totalAssets(), amount);
    }

    //----------------- CrossChainReceiver Tests -----------------//

    function test_ReceiveMessageWithAssets() public {
        // Prepare the message for receiving assets
        address asset = address(mockToken);
        uint256 amount = 1000;
        bytes memory message = _buildDeliverPayload(asset);

        // Call from the bridge router address
        mockToken.mint(address(proxy), amount);
        vm.prank(address(mockBridgeRouter));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    asset,
                    amount,
                    message,
                    SOURCE_CHAIN_ID
                )
            )
        );

        // Verify token balance was updated
        assertEq(fleetCommanderMock.totalAssets(), amount);
    }
    function test_ReceiveMessageWithAssets_WrongPorxy() public {
        // Prepare the message for receiving assets
        address asset = address(mockToken);
        uint256 amount = 1000;
        bytes memory message = _buildDeliverPayload(asset);

        BridgeTypes.RelayedTransferParams
            memory params = _buildDeliveredTransferParams(
                asset,
                amount,
                message,
                SOURCE_CHAIN_ID
            );
        params.originator = address(0x123);
        // Call from the bridge router address
        mockToken.mint(address(proxy), amount);
        vm.prank(address(mockBridgeRouter));
        vm.expectRevert(abi.encodeWithSignature("InvalidRequestor()"));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(params)
        );
    }
    function test_SupportsInterface() public view {
        // Should support ICrossChainReceiver interface
        bytes4 interfaceId = type(ICrossChainReceiver).interfaceId;
        assertTrue(proxy.supportsInterface(interfaceId));

        // Should support IERC165 interface
        interfaceId = 0x01ffc9a7; // IERC165 interface ID
        assertTrue(proxy.supportsInterface(interfaceId));

        // Should not support random interface
        interfaceId = 0x12345678;
        assertFalse(proxy.supportsInterface(interfaceId));
    }

    /**
     * @notice Helper method to deposit assets to the fleet proxy
     * @param amount The amount of tokens to deposit
     * @return messageId The generated message ID for the deposit
     */
    function _depositAssetsToFleet(uint256 amount) internal returns (bytes32) {
        address asset = address(mockToken);

        // Mint tokens to the proxy
        mockToken.mint(address(proxy), amount);

        // Prepare the message for receiving assets
        bytes memory message = _buildDeliverPayload(asset);
        bytes32 messageId = keccak256(
            abi.encode("deposit", amount, block.timestamp)
        );

        // Call from the bridge router address (via adapter)
        vm.prank(address(mockBridgeRouter));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    asset,
                    amount,
                    message,
                    SOURCE_CHAIN_ID
                )
            )
        );

        // Verify token balance was updated in the fleet commander
        assertEq(fleetCommanderMock.totalAssets(), amount);

        return messageId;
    }

    function test_ReceiveMessageWithAssets_UnauthorizedSender() public {
        // Prepare the message for receiving assets
        address asset = address(mockToken);
        uint256 amount = 1000;
        bytes memory message = _buildDeliverPayload(asset);

        // Mint tokens to the proxy
        mockToken.mint(address(proxy), amount);

        // Call from an unauthorized address (not the adapter)
        address unauthorizedCaller = address(0x123);
        vm.prank(unauthorizedCaller);

        // Should revert with CallerNotRegisteredAdapter error
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    asset,
                    amount,
                    message,
                    SOURCE_CHAIN_ID
                )
            )
        );
    }

    function test_ReceiveMessageWithAssets_InvalidAsset() public {
        // Create a different token that doesn't match the fleet's configured asset
        ERC20Mock invalidToken = new ERC20Mock();
        uint256 amount = 1000;

        bytes memory message = _buildDeliverPayload(address(invalidToken));

        // Mint invalid tokens to the proxy
        invalidToken.mint(address(proxy), amount);

        // Call from the adapter but with invalid asset
        vm.prank(address(mockBridgeRouter));

        // Should revert with InvalidAsset error
        vm.expectRevert(abi.encodeWithSignature("InvalidAsset()"));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    address(invalidToken),
                    amount,
                    message,
                    SOURCE_CHAIN_ID
                )
            )
        );
    }

    function test_ReceiveMessageWithAssets_ZeroAmount() public {
        // Prepare the message with zero amount
        address asset = address(mockToken);
        uint256 amount = 0;

        bytes memory message = _buildDeliverPayload(asset);

        // Call from the adapter with zero amount
        vm.prank(address(mockBridgeRouter));

        // Should revert with NoAssets error
        vm.expectRevert(abi.encodeWithSignature("NoAssets()"));
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    asset,
                    amount,
                    message,
                    SOURCE_CHAIN_ID
                )
            )
        );
    }

    function test_ReceiveMessageWithAssets_EmptyMessage() public {
        // Use empty message
        address asset = address(mockToken);
        uint256 amount = 1000;
        bytes memory emptyMessage = _buildEmptyPayload();

        // Mint tokens to the proxy
        mockToken.mint(address(proxy), amount);

        // Call from the adapter with empty message
        // This should emit the in-code message warning but still process the assets
        vm.prank(address(mockBridgeRouter));

        // No event expectation since MessageContentNotExpected isn't declared as an event

        // Call should succeed
        proxy.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                _buildDeliveredTransferParams(
                    asset,
                    amount,
                    emptyMessage,
                    SOURCE_CHAIN_ID
                )
            )
        );

        // Verify tokens were still processed correctly
        assertEq(fleetCommanderMock.totalAssets(), amount);
    }

    function test_WithdrawAndTransfer_ZeroAmount() public {
        // Try to withdraw and transfer with zero amount
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("NoAssets()"));
        proxy.withdrawAndTransfer(
            0,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            })
        );
    }
}
