// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {MockBridgeRouter} from "../mocks/MockBridgeRouter.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {ArkParams} from "../../src/contracts/Ark.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {Raft} from "../../src/contracts/Raft.sol";
import {CrossChainFleetProxy} from "../../src/contracts/FleetProxy.sol";
import {IFleetProxy} from "../../src/interfaces/IFleetProxy.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {IFleetCommander} from "../../src/interfaces/IFleetCommander.sol";
import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {IArkConfigProvider} from "../../src/interfaces/IArkConfigProvider.sol";

contract CrossChainFleetProxyTest is Test {
    // Constants
    uint16 constant SOURCE_CHAIN_ID = 111;
    uint16 constant DEST_CHAIN_ID = 222;
    address constant SOURCE_ARK_ADDRESS = address(0xBEEF);
    address constant MOCK_ADAPTER = address(0xADADADA); // Mock adapter address

    // Role constants
    bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    // Contracts under test
    CrossChainFleetProxy public proxy;

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

    function setUp() public {
        // Deploy mocks
        mockToken = new ERC20Mock();
        mockBridgeRouter = new MockBridgeRouter();
        accessManager = new ProtocolAccessManager(governor);
        mockAdapter = new MockAdapter(address(mockBridgeRouter));
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

        proxy = new CrossChainFleetProxy(
            address(accessManager),
            address(mockBridgeRouter),
            address(fleetCommanderMock),
            100000
        );
    }

    //----------------- Constructor Tests -----------------//

    function test_Constructor() public view {
        // Test basic constructor values
        assertEq(address(proxy.bridgeRouter()), address(mockBridgeRouter));
    }

    //----------------- Administrative Tests -----------------//
    function test_PauseUnpause() public {
        // Test pause - guardian can pause
        vm.prank(guardian);
        proxy.pause();
        assertTrue(proxy.paused());

        // Non-governor can't unpause
        vm.prank(guardian);
        vm.expectRevert();
        proxy.unpause();

        // Governor can unpause
        vm.prank(governor);
        proxy.unpause();
        assertFalse(proxy.paused());
    }

    //----------------- CrossChainReceiver Tests -----------------//

    function test_ReceiveMessage_UnauthorizedCaller() public {
        // Only the bridge router can call receiveMessage
        vm.expectRevert(IFleetProxy.CallerNotRegisteredAdapter.selector);
        proxy.receiveMessage(SOURCE_CHAIN_ID, new bytes(0));
    }

    function test_ReceiveMessage_ReceiveAssets() public {
        // Prepare the message for receiving assets
        address asset = address(mockToken);
        uint256 amount = 1000;
        bytes memory message = abi.encodeWithSelector(
            ICrossChainReceiver.receiveMessageWithAssets.selector,
            asset,
            amount
        );

        // Call from the bridge router address
        mockToken.mint(address(proxy), amount);
        vm.prank(address(mockAdapter));
        proxy.receiveMessageWithAssets(asset, amount, message);

        // Verify token balance was updated
        assertEq(fleetCommanderMock.totalAssets(), amount);
    }

    function test_ReceiveMessage_WithdrawAssets() public {
        // First, deposit some tokens to the fleet
        uint256 initialAmount = 1000;
        uint256 withdrawAmount = 500;
        _depositAssetsToFleet(initialAmount);

        // Get the token from the fleetCommander
        address token = address(mockToken);

        // Prepare withdraw message - using simplified approach without selector
        bytes memory withdrawMessage = abi.encode(
            token,
            withdrawAmount,
            SOURCE_ARK_ADDRESS
        );

        // Send withdraw message
        vm.prank(address(mockAdapter));
        proxy.receiveMessage(SOURCE_CHAIN_ID, withdrawMessage);

        // Verify remaining balance in the fleet commander
        assertEq(
            fleetCommanderMock.totalAssets(),
            initialAmount - withdrawAmount
        );
    }

    function test_ReceiveMessage_WithdrawAssets_InsufficientBalance() public {
        // Get the token from the fleetCommander
        address token = address(mockToken);
        uint256 withdrawAmount = 1000; // No tokens in the contract

        // Prepare withdraw message - should include token, amount, and recipient
        bytes memory withdrawMessage = abi.encode(
            token,
            withdrawAmount,
            SOURCE_ARK_ADDRESS
        );

        // Ensure the fleetCommanderMock's getConfig returns the correct asset
        fleetCommanderMock.setBufferArk(address(bufferArkMock));

        // Expect InsufficientBalance revert when trying to withdraw
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                address(proxy),
                withdrawAmount,
                0
            )
        );
        vm.prank(address(mockAdapter));
        proxy.receiveMessage(SOURCE_CHAIN_ID, withdrawMessage);
    }

    function test_ReceiveStateRead() public {
        // Prepare state read result
        bytes memory resultData = abi.encode(uint256(1000));
        address requestor = SOURCE_ARK_ADDRESS;
        uint16 sourceChainId = SOURCE_CHAIN_ID;
        bytes32 requestId = keccak256(abi.encode("readRequest"));

        // Mock the bridge router call - should not revert
        vm.expectRevert(IFleetProxy.InvalidOperation.selector);
        vm.prank(address(mockBridgeRouter));
        proxy.receiveStateRead(resultData, requestor, sourceChainId, requestId);
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
        bytes memory message = abi.encodeWithSelector(
            ICrossChainReceiver.receiveMessageWithAssets.selector,
            asset,
            amount
        );
        bytes32 messageId = keccak256(
            abi.encode("deposit", amount, block.timestamp)
        );

        // Call from the bridge router address (via adapter)
        vm.prank(address(mockAdapter));
        proxy.receiveMessageWithAssets(asset, amount, message);

        // Verify token balance was updated in the fleet commander
        assertEq(fleetCommanderMock.totalAssets(), amount);

        return messageId;
    }
}
