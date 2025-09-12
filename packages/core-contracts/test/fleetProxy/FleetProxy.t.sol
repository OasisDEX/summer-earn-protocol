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
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
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
        registry.initializeBridgeConfiguration(address(mockBridgeRouter));

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
    //----------------- Constructor & Basic Getters -----------------//

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

    function test_GetBalance_ReturnsProxyTokenBalance() public {
        address asset = address(mockToken);
        uint256 amount = 1234;
        mockToken.mint(address(proxy), amount);
        assertEq(proxy.getBalance(asset), amount);
    }

    function test_TotalAssets_IncludesManuallySetInflightWithdrawals() public {
        // Establish baseline by depositing once via receive path
        uint256 depositAmount = 1000;
        _depositAssetsToFleet(depositAmount);

        uint256 baseline = fleetCommanderMock.totalAssets();

        // Update inflight as governor
        vm.prank(governor);
        proxy.forceUpdateInflightAssets(123);

        // totalAssets = fleet.totalAssets + inflightWithdrawals
        assertEq(proxy.totalAssets(), baseline + 123);
    }

    function test_AcknowledgeHubReceipt_AccessControlAndClearsInflight()
        public
    {
        // Set inflight as governor via emergency function
        vm.prank(governor);
        proxy.forceUpdateInflightAssets(77);

        // Unauthorized caller cannot acknowledge
        vm.prank(address(0xDEAD));
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotSuperKeeper(address)",
                address(0xDEAD)
            )
        );
        proxy.acknowledgeHubReceipt(bytes32(uint256(1)));

        // Grant SUPER_KEEPER to governor and then acknowledge
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(governor);

        vm.prank(governor);
        proxy.acknowledgeHubReceipt(bytes32(uint256(1)));

        // Inflight should be cleared
        assertEq(proxy.inflightWithdrawals(), 0);
    }

    //----------------- Access Control & Pausable -----------------//

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

    //----------------- Cross-Chain Receiver: TRANSFER_ASSET -----------------//

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

    function test_TotalAssets_Empty() public view {
        assertEq(proxy.totalAssets(), 0);
    }

    function test_TotalAssets_AfterDeposit_EqualsProxyOwnedAssets() public {
        // Arrange
        address asset = address(mockToken);
        uint256 amount = 1_000;
        bytes memory message = _buildDeliverPayload(asset);

        // Act: bridge delivers tokens to proxy and proxy deposits into FleetCommander
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

        // Assert: proxy.totalAssets equals its own shares converted to assets
        uint256 shares = fleetCommanderMock.balanceOf(address(proxy));
        uint256 expected = fleetCommanderMock.convertToAssets(shares);
        assertEq(proxy.totalAssets(), expected);
        assertEq(proxy.totalAssets(), amount);
    }

    function test_TotalAssets_IncludesInflightWithdrawals() public {
        // Arrange
        address asset = address(mockToken);
        uint256 amount = 1_000;
        bytes memory message = _buildDeliverPayload(asset);

        // Deposit via bridge
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

        // Act: withdraw and transfer a portion, which should burn proxy shares and add inflight
        uint256 withdrawAmount = 400;
        vm.prank(governor);
        proxy.withdrawAndTransfer(
            withdrawAmount,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            })
        );

        // Assert inflight reflected and totalAssets unchanged (shares assets + inflight)
        uint256 shares = fleetCommanderMock.balanceOf(address(proxy));
        uint256 expected = fleetCommanderMock.convertToAssets(shares) +
            proxy.inflightWithdrawals();
        assertEq(proxy.inflightWithdrawals(), withdrawAmount);
        assertEq(proxy.totalAssets(), expected);
        assertEq(proxy.totalAssets(), amount);

        // Act: governor updates inflight to 0 (simulating bridge completion)
        vm.prank(governor);
        proxy.forceUpdateInflightAssets(0);

        // Assert: totalAssets now equals remaining shares in fleet only
        uint256 expectedAfter = fleetCommanderMock.convertToAssets(shares);
        assertEq(proxy.totalAssets(), expectedAfter);
        assertEq(proxy.totalAssets(), amount - withdrawAmount);
    }

    function test_TotalAssets_IncludesLocalBalance() public {
        // Arrange: mint tokens directly to the proxy without depositing
        uint256 localAmount = 50;
        mockToken.mint(address(proxy), localAmount);

        // Assert: totalAssets reflects local balance
        assertEq(proxy.totalAssets(), localAmount);
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
    //----------------- Interfaces -----------------//

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

    //----------------- Keeper Functions: withdrawAndTransfer & notifySourceChain -----------------//

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

    function test_NotifySourceChain_CorrectMessage() public {
        // First, deposit some assets to the fleet to have something to notify about
        uint256 depositAmount = 1000;
        _depositAssetsToFleet(depositAmount);

        // Verify the fleet has assets
        uint256 expectedFleetAssets = fleetCommanderMock.convertToAssets(
            fleetCommanderMock.balanceOf(address(proxy))
        );
        assertEq(
            expectedFleetAssets,
            depositAmount,
            "Fleet should have the deposited assets"
        );

        // Get the latest transfer ID that should be set after the deposit
        bytes32 expectedTransferId = proxy.latestIncomingTransferId();
        assertTrue(
            expectedTransferId != bytes32(0),
            "Transfer ID should be set after deposit"
        );

        // Clear any previous message calls
        mockBridgeRouter.clearCalls();
        uint256 initialMessageCallCount = mockBridgeRouter
            .getMessageCallCount();

        // Give the governor some ETH for the transaction
        vm.deal(governor, 1 ether);

        // Call notifySourceChain
        vm.prank(governor);
        proxy.notifySourceChain{value: 0.1 ether}(
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            })
        );
    }

    function test_WithdrawAndTransfer_SetsRefundToKeeper_and_RefundsETH()
        public
    {
        // Arrange: governor is keeper and will call the function
        // Fund governor with ETH for fee and set router to refund to provided refundAddress
        vm.deal(governor, 10 ether);
        vm.prank(governor);
        mockBridgeRouter.setUseRefundAddress(true);

        // Clear any previous message calls
        mockBridgeRouter.clearCalls();
        uint256 initialMessageCallCount = mockBridgeRouter
            .getMessageCallCount();

        // Mint underlying to FleetCommander and shares to proxy so withdraw works
        uint256 assets = 1_000 ether;
        mockToken.mint(address(fleetCommanderMock), assets);
        // Deposit some assets so that proxy has shares after deposit via receive side
        // Instead, we mint shares directly to proxy for simplicity (using mock's helper)
        fleetCommanderMock.testMint(address(proxy), assets);

        // Act: call withdrawAndTransfer with some msg.value
        uint256 value = 0.5 ether; // greater than baseFee in mock (0.1 ether)
        vm.prank(governor);
        proxy.withdrawAndTransfer{value: value}(
            100,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            })
        );

        // Verify a transfer was sent
        uint256 finalTransferCallCount = mockBridgeRouter
            .getTransferCallCount();
        assertEq(finalTransferCallCount, 1, "Should have sent one transfer");

        // Get the last transfer call
        (
            uint16 destinationChainId,
            address asset,
            uint256 amount,
            address target,
            bytes memory message
        ) = mockBridgeRouter.transferCalls(finalTransferCallCount - 1);

        // Verify the destination chain ID
        assertEq(
            destinationChainId,
            SOURCE_CHAIN_ID,
            "Should send to source chain"
        );

        // Verify the target is the source ark
        address expectedTarget = registry.getSourceForTarget(
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(proxy),
            keccak256("ARK_FLEET_RELATIONSHIP")
        );
        assertEq(target, expectedTarget, "Target should be the source ark");

        // Decode and verify the message content
        uint256 fleetAssets = abi.decode(message, (uint256));
        uint256 expectedFleetAssets = fleetCommanderMock.convertToAssets(
            fleetCommanderMock.balanceOf(address(proxy))
        );

        // Verify the fleet assets amount
        assertEq(
            fleetAssets,
            expectedFleetAssets,
            "Message should contain correct fleet assets amount"
        );
    }

    function test_NotifySourceChain_ZeroFleetAssets() public {
        // Don't deposit any assets - fleet should have zero assets
        uint256 expectedFleetAssets = fleetCommanderMock.convertToAssets(
            fleetCommanderMock.balanceOf(address(proxy))
        );
        assertEq(
            expectedFleetAssets,
            0,
            "Fleet should have zero assets initially"
        );

        // Clear any previous message calls
        mockBridgeRouter.clearCalls();
        uint256 initialMessageCallCount = mockBridgeRouter
            .getMessageCallCount();

        // Give the governor some ETH for the transaction
        vm.deal(governor, 1 ether);

        // Call notifySourceChain
        vm.prank(governor);
        proxy.notifySourceChain{value: 0.1 ether}(
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            })
        );

        // Verify a message was sent
        uint256 finalMessageCallCount = mockBridgeRouter.getMessageCallCount();
        assertEq(
            finalMessageCallCount,
            initialMessageCallCount + 1,
            "Should have sent one message"
        );

        // Get the last message call
        (, , bytes memory message) = mockBridgeRouter.messageCalls(
            finalMessageCallCount - 1
        );

        // Decode and verify the message content
        (uint256 fleetAssets, bytes32 transferId) = abi.decode(
            message,
            (uint256, bytes32)
        );

        // Verify the fleet assets amount is zero
        assertEq(fleetAssets, 0, "Message should contain zero fleet assets");
        assertEq(
            fleetAssets,
            expectedFleetAssets,
            "Fleet assets should match expected zero amount"
        );

        // Verify the transfer ID (should be zero since no transfers have occurred)
        assertEq(
            transferId,
            bytes32(0),
            "Transfer ID should be zero when no transfers have occurred"
        );
    }

    function test_NotifySourceChain_UnauthorizedCaller() public {
        // Try to call notifySourceChain from unauthorized address
        address unauthorizedCaller = address(0x123);
        vm.deal(unauthorizedCaller, 1 ether);
        vm.prank(unauthorizedCaller);
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotKeeper(address)",
                unauthorizedCaller
            )
        );
        proxy.notifySourceChain{value: 0.1 ether}(
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            })
        );
    }

    function test_NotifySourceChain_WhenPaused() public {
        // Pause the proxy
        vm.prank(guardian);
        proxy.pause();
        assertTrue(proxy.paused(), "Proxy should be paused");

        // Give the governor some ETH for the transaction
        vm.deal(governor, 1 ether);

        // Try to call notifySourceChain when paused
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        proxy.notifySourceChain{value: 0.1 ether}(
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            })
        );

        // Assert: router was NOT called because the proxy is paused
        assertEq(
            mockBridgeRouter.getMessageCallCount(),
            0,
            "router should not be called when paused"
        );
        assertEq(
            mockBridgeRouter.lastMsgOriginator(),
            address(0),
            "originator should remain unset"
        );
        assertEq(
            mockBridgeRouter.lastMsgTarget(),
            address(0),
            "target should remain unset"
        );
        assertEq(mockBridgeRouter.lastMsgValue(), 0, "no msg.value forwarded");

        // Refund/balance checks are not applicable since call reverts before router interaction
    }

    function test_NotifySourceChain_SetsRefundToKeeper_and_RefundsETH() public {
        // Arrange
        vm.deal(governor, 10 ether);
        vm.prank(governor);
        mockBridgeRouter.setUseRefundAddress(true);

        // Give the proxy some shares to produce a fleetBalance > 0 in the message
        fleetCommanderMock.testMint(address(proxy), 1 ether);

        // Act
        uint256 value = 0.5 ether;
        vm.prank(governor);
        proxy.notifySourceChain{value: value}(
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 100000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            })
        );

        // Assert
        assertEq(
            mockBridgeRouter.lastMsgRefundAddress(),
            governor,
            "refund should be keeper"
        );
        assertEq(
            mockBridgeRouter.lastMsgOriginator(),
            address(proxy),
            "originator should be proxy"
        );
        assertEq(
            mockBridgeRouter.lastMsgTarget(),
            SOURCE_ARK_ADDRESS,
            "target should be source-chain Ark"
        );
        assertGt(mockBridgeRouter.lastMsgValue(), 0, "msg.value forwarded");
    }

    //----------------- Miscellaneous -----------------//

    function test_ProxyCannotReceiveETH() public {
        // FleetProxy has no receive/fallback; raw call should fail
        (bool ok, ) = address(proxy).call{value: 1 wei}("");
        assertEq(ok, false, "proxy should not accept ETH via receive/fallback");
    }
}
