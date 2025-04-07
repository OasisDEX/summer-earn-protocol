// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {CrossChainArkProxy} from "../../src/contracts/ArkProxy.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {MockBridgeRouter} from "../mocks/MockBridgeRouter.sol";

contract CrossChainArkProxyTest is Test {
    // Constants
    uint16 constant SOURCE_CHAIN_ID = 111;
    uint16 constant DEST_CHAIN_ID = 222;
    address constant SOURCE_ARK_ADDRESS = address(0xBEEF);

    // Role constants
    bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    // Contracts under test
    CrossChainArkProxy public proxy;

    // Mocks
    ERC20Mock public mockToken;
    MockBridgeRouter public mockBridgeRouter;
    ProtocolAccessManager public accessManager;

    // Test addresses
    address public governor = address(1);
    address public guardian = address(2);
    address public pauser = address(3);

    // Events to test
    event AssetsReceived(
        address indexed token,
        uint256 amount,
        uint16 indexed sourceChainId,
        bytes32 indexed messageId
    );

    event AssetsSent(
        address indexed token,
        uint256 amount,
        uint16 indexed sourceChainId,
        bytes32 indexed messageId
    );

    event SourceChainRegistered(
        uint16 indexed sourceChainId,
        address indexed sourceAddress
    );

    event SourceChainRemoved(
        uint16 indexed sourceChainId,
        address indexed sourceAddress
    );

    function setUp() public {
        // Deploy mocks
        mockToken = new ERC20Mock();
        mockBridgeRouter = new MockBridgeRouter();
        accessManager = new ProtocolAccessManager(governor);

        // Set up access control
        vm.startPrank(governor);
        accessManager.grantRole(GUARDIAN_ROLE, guardian);
        accessManager.grantRole(GOVERNOR_ROLE, governor);
        vm.stopPrank();

        // Deploy the proxy
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(mockToken);

        uint16[] memory sourceChainIds = new uint16[](1);
        sourceChainIds[0] = SOURCE_CHAIN_ID;

        address[] memory sourceAddresses = new address[](1);
        sourceAddresses[0] = SOURCE_ARK_ADDRESS;

        proxy = new CrossChainArkProxy(
            address(accessManager),
            address(mockBridgeRouter),
            supportedTokens,
            sourceChainIds,
            sourceAddresses
        );
    }

    //----------------- Constructor Tests -----------------//

    function test_Constructor() public {
        // Test basic constructor values
        assertEq(address(proxy.bridgeRouter()), address(mockBridgeRouter));

        // Test token configuration
        assertTrue(proxy.supportedTokens(address(mockToken)));
        assertFalse(proxy.supportedTokens(address(0xDEAD)));

        // Test source chain configuration
        assertTrue(
            proxy.authorizedSources(SOURCE_CHAIN_ID, SOURCE_ARK_ADDRESS)
        );
        assertFalse(proxy.authorizedSources(SOURCE_CHAIN_ID, address(0xDEAD)));
        assertFalse(proxy.authorizedSources(DEST_CHAIN_ID, SOURCE_ARK_ADDRESS));
    }

    //----------------- Administrative Tests -----------------//

    function test_AddSupportedToken() public {
        address newToken = address(0xABCD);

        // Unauthorized access should fail
        vm.expectRevert();
        proxy.addSupportedToken(newToken);

        // Authorized access should work
        vm.prank(guardian);
        proxy.addSupportedToken(newToken);

        assertTrue(proxy.supportedTokens(newToken));
    }

    function test_RemoveSupportedToken() public {
        // Unauthorized access should fail
        vm.expectRevert();
        proxy.removeSupportedToken(address(mockToken));

        // Authorized access should work
        vm.prank(guardian);
        proxy.removeSupportedToken(address(mockToken));

        assertFalse(proxy.supportedTokens(address(mockToken)));
    }

    function test_RegisterSourceChain() public {
        address newSourceAddress = address(0xCAFE);
        uint16 newChainId = 333;

        // Expect event
        vm.expectEmit(true, true, false, false);
        emit SourceChainRegistered(newChainId, newSourceAddress);

        // Authorized access should work
        vm.prank(guardian);
        proxy.registerSourceChain(newChainId, newSourceAddress);

        assertTrue(proxy.authorizedSources(newChainId, newSourceAddress));
    }

    function test_RemoveSourceChain() public {
        // Expect event
        vm.expectEmit(true, true, false, false);
        emit SourceChainRemoved(SOURCE_CHAIN_ID, SOURCE_ARK_ADDRESS);

        // Authorized access should work
        vm.prank(guardian);
        proxy.removeSourceChain(SOURCE_CHAIN_ID, SOURCE_ARK_ADDRESS);

        assertFalse(
            proxy.authorizedSources(SOURCE_CHAIN_ID, SOURCE_ARK_ADDRESS)
        );
    }

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
        vm.expectRevert("CrossChainArkProxy: Caller is not the bridge router");
        proxy.receiveMessage(new bytes(0), address(0), 0, bytes32(0));
    }

    function test_ReceiveMessage_UnauthorizedSource() public {
        // Setup an unauthorized source chain/address
        bytes memory message = new bytes(0);
        address recipient = address(0xDEAD);
        uint16 sourceChainId = DEST_CHAIN_ID; // Not authorized
        bytes32 messageId = keccak256(abi.encode("test"));

        // Mock the bridge router call
        vm.prank(address(mockBridgeRouter));
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainArkProxy.UnauthorizedSourceChain.selector,
                sourceChainId,
                recipient
            )
        );

        proxy.receiveMessage(message, recipient, sourceChainId, messageId);
    }

    function test_ReceiveMessage_ReceiveAssets() public {
        // Prepare the message for receiving assets
        address token = address(mockToken);
        uint256 amount = 1000;
        bytes memory message = abi.encodeWithSelector(
            proxy.receiveAssets.selector,
            token,
            amount
        );
        bytes32 messageId = keccak256(abi.encode("test"));

        // Expect AssetsReceived event
        vm.expectEmit(true, true, true, true);
        emit AssetsReceived(token, amount, SOURCE_CHAIN_ID, messageId);

        // Mock the bridge router call
        vm.prank(address(mockBridgeRouter));
        proxy.receiveMessage(
            message,
            SOURCE_ARK_ADDRESS,
            SOURCE_CHAIN_ID,
            messageId
        );

        // Verify token balance was updated
        assertEq(proxy.tokenBalances(token), amount);
    }

    function test_ReceiveMessage_WithdrawAssets() public {
        // First, add some tokens to the contract
        address token = address(mockToken);
        uint256 initialAmount = 1000;
        uint256 withdrawAmount = 500;

        // Setup token balance for the proxy
        mockToken.mint(address(proxy), initialAmount);
        bytes memory receiveMessage = abi.encodeWithSelector(
            proxy.receiveAssets.selector,
            token,
            initialAmount
        );
        bytes32 receiveMessageId = keccak256(abi.encode("receive"));

        // Set initial token balance
        vm.prank(address(mockBridgeRouter));
        proxy.receiveMessage(
            receiveMessage,
            SOURCE_ARK_ADDRESS,
            SOURCE_CHAIN_ID,
            receiveMessageId
        );

        // Prepare withdraw message
        bytes memory withdrawMessage = abi.encodeWithSelector(
            proxy.withdrawAssets.selector,
            token,
            withdrawAmount,
            SOURCE_ARK_ADDRESS
        );
        bytes32 withdrawMessageId = keccak256(abi.encode("withdraw"));

        // Configure mock to return a transfer ID
        bytes32 transferId = keccak256(abi.encode("transferId"));
        mockBridgeRouter.setNextTransferId(transferId);

        // Expect AssetsSent event
        vm.expectEmit(true, true, true, true);
        emit AssetsSent(token, withdrawAmount, SOURCE_CHAIN_ID, transferId);

        // Mock the bridge router call
        vm.prank(address(mockBridgeRouter));
        proxy.receiveMessage(
            withdrawMessage,
            SOURCE_ARK_ADDRESS,
            SOURCE_CHAIN_ID,
            withdrawMessageId
        );

        // Verify token balance was reduced
        assertEq(proxy.tokenBalances(token), initialAmount - withdrawAmount);
    }

    function test_ReceiveMessage_WithdrawAssets_InsufficientBalance() public {
        // Prepare withdraw message with insufficient balance
        address token = address(mockToken);
        uint256 withdrawAmount = 1000; // No tokens in the contract

        bytes memory withdrawMessage = abi.encodeWithSelector(
            proxy.withdrawAssets.selector,
            token,
            withdrawAmount,
            SOURCE_ARK_ADDRESS
        );
        bytes32 withdrawMessageId = keccak256(abi.encode("withdraw"));

        // Expect InsufficientBalance revert
        vm.prank(address(mockBridgeRouter));
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainArkProxy.InsufficientBalance.selector,
                withdrawAmount,
                0
            )
        );

        proxy.receiveMessage(
            withdrawMessage,
            SOURCE_ARK_ADDRESS,
            SOURCE_CHAIN_ID,
            withdrawMessageId
        );
    }

    function test_ReceiveMessage_UnsupportedToken() public {
        // Prepare message with unsupported token
        address unsupportedToken = address(0xDEAD);
        uint256 amount = 1000;

        bytes memory message = abi.encodeWithSelector(
            proxy.receiveAssets.selector,
            unsupportedToken,
            amount
        );
        bytes32 messageId = keccak256(abi.encode("test"));

        // Expect UnsupportedToken revert
        vm.prank(address(mockBridgeRouter));
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainArkProxy.UnsupportedToken.selector,
                unsupportedToken
            )
        );

        proxy.receiveMessage(
            message,
            SOURCE_ARK_ADDRESS,
            SOURCE_CHAIN_ID,
            messageId
        );
    }

    function test_ReceiveStateRead() public {
        // Prepare state read result
        bytes memory resultData = abi.encode(uint256(1000));
        address requestor = SOURCE_ARK_ADDRESS;
        uint16 sourceChainId = SOURCE_CHAIN_ID;
        bytes32 requestId = keccak256(abi.encode("readRequest"));

        // Mock the bridge router call - should not revert
        vm.prank(address(mockBridgeRouter));
        proxy.receiveStateRead(resultData, requestor, sourceChainId, requestId);

        // Actual logic to be implemented in the contract later
    }

    function test_SupportsInterface() public {
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
}
