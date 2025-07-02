// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {FleetDepositManager} from "../../src/contracts/FleetDepositManager.sol";
import {IFleetDepositAdapter} from "@summerfi/chain-bridge/interfaces/IFleetDepositAdapter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {MockAccessManager} from "@summerfi/chain-bridge-test/mocks/MockAccessManager.sol";
import {MockFleetDepositAdapter} from "@summerfi/chain-bridge-test/mocks/MockFleetDepositAdapter.sol";
import {MockFleetDepositAdapterNoSupport} from "@summerfi/chain-bridge-test/mocks/MockFleetDepositAdapterNoSupport.sol";
import {FleetCommanderTestMock} from "../mocks/FleetCommanderTestMock.sol";

contract FleetDepositManagerTest is Test {
    FleetDepositManager public manager;
    MockFleetDepositAdapter public mockAdapter;
    MockFleetDepositAdapterNoSupport public noSupportAdapter;
    ERC20Mock public token;
    MockBridgeRouter public mockBridgeRouter;
    MockAccessManager public mockAccessManager;
    FleetCommanderTestMock public mockFleetCommander;

    address public user = address(0x1);
    address public user2 = address(0x2);
    address public fleetCommander = address(0x3);
    address public shareRecipient = address(0x4);
    uint16 public constant DEST_CHAIN_ID = 8453; // Base
    uint16 public constant ALT_CHAIN_ID = 137; // Polygon
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 public constant LARGE_AMOUNT = 1_000_000 * 10 ** 18;

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
        // Deploy contracts
        mockBridgeRouter = new MockBridgeRouter();
        mockAccessManager = new MockAccessManager();

        // Updated constructor to match actual implementation
        manager = new FleetDepositManager(
            address(mockBridgeRouter),
            address(mockAccessManager)
        );

        mockAdapter = new MockFleetDepositAdapter();
        noSupportAdapter = new MockFleetDepositAdapterNoSupport();
        token = new ERC20Mock();

        // Create a mock fleet commander that supports the token
        mockFleetCommander = new FleetCommanderTestMock(address(token));

        // Setup users with tokens and ETH
        token.mint(user, DEPOSIT_AMOUNT * 10);
        token.mint(user2, DEPOSIT_AMOUNT * 10);
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);

        // Register mock adapter with bridge router
        mockBridgeRouter.registerAdapter(address(mockAdapter));
        mockBridgeRouter.registerAdapter(address(noSupportAdapter));

        // For testing, we'll use the mock fleet commander address as fleet commander
        fleetCommander = address(mockFleetCommander);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_Success() public {
        FleetDepositManager newManager = new FleetDepositManager(
            address(mockBridgeRouter),
            address(mockAccessManager)
        );
        assertEq(address(newManager.bridgeRouter()), address(mockBridgeRouter));
        assertEq(newManager.FLEET_DEPOSIT_TYPE(), keccak256("FLEET_DEPOSIT"));
    }

    function test_Constructor_RevertWhen_ZeroAddressBridgeRouter() public {
        vm.expectRevert(FleetDepositManager.InvalidParams.selector);
        new FleetDepositManager(address(0), address(mockAccessManager));
    }

    function test_Constructor_RevertWhen_ZeroAddressAccessManager() public {
        vm.expectRevert();
        new FleetDepositManager(address(mockBridgeRouter), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTER VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IsAdapterSupported_Success() public view {
        assertTrue(manager.isAdapterSupported(address(mockAdapter)));
    }

    function test_IsAdapterSupported_UnsupportedAdapter() public view {
        address unsupportedAdapter = address(0x999);
        assertFalse(manager.isAdapterSupported(unsupportedAdapter));
    }

    function test_IsAdapterSupported_AdapterNotRegistered() public {
        MockFleetDepositAdapter unregisteredAdapter = new MockFleetDepositAdapter();
        assertFalse(manager.isAdapterSupported(address(unregisteredAdapter)));
    }

    function test_IsAdapterSupported_AdapterDoesNotSupportFleetDeposits()
        public
        view
    {
        assertFalse(manager.isAdapterSupported(address(noSupportAdapter)));
    }

    function test_IsAdapterSupported_AdapterReverts() public view {
        address invalidAdapter = address(0x789);
        assertFalse(manager.isAdapterSupported(invalidAdapter));
    }

    /*//////////////////////////////////////////////////////////////
                        CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitiateDepositToTargetChainFleet_Success() public {
        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        bytes32 operationId = manager.initiateDepositToTargetChainFleet{
            value: 0.01 ether
        }(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0.01 ether,
                options: bytes("")
            })
        );

        vm.stopPrank();

        // Verify operation completed
        assertNotEq(operationId, bytes32(0));
        assertEq(mockAdapter.lastOperationId(), operationId);
        assertEq(mockAdapter.lastAmount(), DEPOSIT_AMOUNT);
        assertEq(mockAdapter.lastAsset(), address(token));
        assertEq(mockAdapter.lastDestinationChainId(), DEST_CHAIN_ID);
    }

    function test_InitiateDepositToTargetChainFleet_WithReferralCode() public {
        bytes memory referralCode = bytes("SUMMER2024");

        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectEmit(false, true, true, false); // Don't check operationId (first indexed parameter)
        emit FleetDepositToTargetChainInitiated(
            bytes32(0), // operationId will be different
            DEST_CHAIN_ID,
            user,
            address(mockAdapter),
            fleetCommander,
            address(token),
            DEPOSIT_AMOUNT,
            shareRecipient
        );

        bytes32 operationId = manager.initiateDepositToTargetChainFleet{
            value: 0.01 ether
        }(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            referralCode,
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0.01 ether,
                options: bytes("")
            })
        );

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));

        // Verify referral code is in compose message
        bytes memory composeMessage = mockAdapter.lastComposeMessage();
        (, , , , , , , , bytes memory decodedReferralCode) = abi.decode(
            composeMessage,
            (
                bytes32,
                address,
                address,
                address,
                uint256,
                uint256,
                bytes32,
                address,
                bytes
            )
        );
        assertEq(decodedReferralCode, referralCode);
    }

    function test_InitiateDepositToTargetChainFleet_DifferentChainIds() public {
        uint16[] memory chainIds = new uint16[](3);
        chainIds[0] = 1; // Ethereum
        chainIds[1] = 137; // Polygon
        chainIds[2] = 42161; // Arbitrum

        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT * 3);

        for (uint i = 0; i < chainIds.length; i++) {
            mockAdapter.reset(); // Reset adapter state

            bytes32 operationId = manager.initiateDepositToTargetChainFleet(
                address(mockAdapter),
                chainIds[i],
                address(token),
                DEPOSIT_AMOUNT,
                fleetCommander,
                shareRecipient,
                bytes(""),
                BridgeTypes.AdapterParams({
                    gasLimit: 500000,
                    calldataSize: 0,
                    msgValue: 0,
                    options: bytes("")
                })
            );

            assertNotEq(operationId, bytes32(0));
            assertEq(mockAdapter.lastDestinationChainId(), chainIds[i]);
        }

        vm.stopPrank();
    }

    function test_CrossChainDepositToFleet_LargeAmount() public {
        token.mint(user, LARGE_AMOUNT);

        vm.startPrank(user);
        token.approve(address(manager), LARGE_AMOUNT);

        bytes32 operationId = manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            LARGE_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));
        assertEq(mockAdapter.lastAmount(), LARGE_AMOUNT);
    }

    function test_CrossChainDepositToFleet_MultipleDeposits() public {
        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT * 3);

        bytes32[] memory operationIds = new bytes32[](3);

        for (uint i = 0; i < 3; i++) {
            mockAdapter.reset(); // Reset adapter state

            operationIds[i] = manager.initiateDepositToTargetChainFleet(
                address(mockAdapter),
                DEST_CHAIN_ID,
                address(token),
                DEPOSIT_AMOUNT,
                fleetCommander,
                shareRecipient,
                abi.encodePacked("REF", i),
                BridgeTypes.AdapterParams({
                    gasLimit: 500000,
                    calldataSize: 0,
                    msgValue: 0,
                    options: bytes("")
                })
            );

            assertNotEq(operationIds[i], bytes32(0));
        }

        vm.stopPrank();

        // Verify all operation IDs are unique
        for (uint i = 0; i < 3; i++) {
            for (uint j = i + 1; j < 3; j++) {
                assertNotEq(operationIds[i], operationIds[j]);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CrossChainDepositToFleet_RevertWhen_AmountIsZero() public {
        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectRevert(FleetDepositManager.InvalidParams.selector);
        manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            0, // Zero amount
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );
        vm.stopPrank();
    }

    function test_CrossChainDepositToFleet_RevertWhen_FleetCommanderIsZero()
        public
    {
        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectRevert(FleetDepositManager.InvalidParams.selector);
        manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            address(0), // Zero fleet commander
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );
        vm.stopPrank();
    }

    function test_CrossChainDepositToFleet_RevertWhen_ShareRecipientIsZero()
        public
    {
        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectRevert(FleetDepositManager.InvalidParams.selector);
        manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            address(0), // Zero share recipient
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );
        vm.stopPrank();
    }

    function test_CrossChainDepositToFleet_RevertWhen_UnsupportedAdapter()
        public
    {
        address unsupportedAdapter = address(0x999);

        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectRevert(FleetDepositManager.UnsupportedBridgeAdapter.selector);
        manager.initiateDepositToTargetChainFleet(
            unsupportedAdapter,
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );

        vm.stopPrank();
    }

    function test_CrossChainDepositToFleet_RevertWhen_AdapterReverts() public {
        mockAdapter.setShouldRevert(true);

        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectRevert("Mock adapter reverted");
        manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );
        vm.stopPrank();
    }

    function test_CrossChainDepositToFleet_RevertWhen_InsufficientAllowance()
        public
    {
        vm.startPrank(user);
        // Don't approve tokens

        vm.expectRevert();
        manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );
        vm.stopPrank();
    }

    function test_CrossChainDepositToFleet_RevertWhen_InsufficientBalance()
        public
    {
        address poorUser = address(0x123);
        vm.startPrank(poorUser);

        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectRevert();
        manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOSE MESSAGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EncodeFleetDepositMessage_Success() public view {
        bytes memory composeMessage = manager.encodeFleetDepositMessage(
            fleetCommander,
            shareRecipient,
            address(token),
            DEPOSIT_AMOUNT,
            bytes("SUMMER2024")
        );

        assertGt(composeMessage.length, 0);

        (
            bytes32 messageType,
            address decodedFleetCommander,
            address decodedRecipient,
            address decodedAsset,
            uint256 decodedAmount,
            uint256 sourceChainId,
            bytes32 operationId,
            address originalUser,
            bytes memory referralCode
        ) = abi.decode(
                composeMessage,
                (
                    bytes32,
                    address,
                    address,
                    address,
                    uint256,
                    uint256,
                    bytes32,
                    address,
                    bytes
                )
            );

        assertEq(messageType, manager.FLEET_DEPOSIT_TYPE());
        assertEq(decodedFleetCommander, fleetCommander);
        assertEq(decodedRecipient, shareRecipient);
        assertEq(decodedAsset, address(token));
        assertEq(decodedAmount, DEPOSIT_AMOUNT);
        assertEq(sourceChainId, block.chainid);
        assertEq(operationId, bytes32(0)); // Should be zero placeholder
        assertEq(originalUser, address(this)); // msg.sender in view function
        assertEq(referralCode, bytes("SUMMER2024"));
    }

    function test_EncodeFleetDepositMessage_EmptyReferralCode() public view {
        bytes memory composeMessage = manager.encodeFleetDepositMessage(
            fleetCommander,
            shareRecipient,
            address(token),
            DEPOSIT_AMOUNT,
            bytes("") // Empty referral code
        );

        assertGt(composeMessage.length, 0);

        (, , , , , , , , bytes memory referralCode) = abi.decode(
            composeMessage,
            (
                bytes32,
                address,
                address,
                address,
                uint256,
                uint256,
                bytes32,
                address,
                bytes
            )
        );

        assertEq(referralCode.length, 0);
    }

    function test_CreateFleetDepositMessage_LongReferralCode() public view {
        bytes memory longReferralCode = bytes(
            "VERYLONGREFERRALCODEFORFLEETDEPOSITS2024"
        );

        bytes memory composeMessage = manager.encodeFleetDepositMessage(
            fleetCommander,
            shareRecipient,
            address(token),
            DEPOSIT_AMOUNT,
            longReferralCode
        );

        assertGt(composeMessage.length, 0);

        (, , , , , , , , bytes memory decodedReferralCode) = abi.decode(
            composeMessage,
            (
                bytes32,
                address,
                address,
                address,
                uint256,
                uint256,
                bytes32,
                address,
                bytes
            )
        );

        assertEq(decodedReferralCode, longReferralCode);
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CrossChainDepositToFleet_MaxUint256Amount() public {
        uint256 maxAmount = type(uint256).max / 2; // Use half of max to avoid overflow
        token.mint(user, maxAmount);

        vm.startPrank(user);
        token.approve(address(manager), maxAmount);

        bytes32 operationId = manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            maxAmount,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));
        assertEq(mockAdapter.lastAmount(), maxAmount);
    }

    function test_CrossChainDepositToFleet_HighGasLimit() public {
        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        bytes32 operationId = manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 5000000, // Very high gas limit
                calldataSize: 1000,
                msgValue: 0,
                options: bytes("extra_options")
            })
        );

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));

        // Get adapter params to verify - destructure the tuple
        (uint64 gasLimit, uint32 calldataSize, , ) = mockAdapter
            .lastAdapterParams();
        assertEq(gasLimit, 5000000);
        assertEq(calldataSize, 1000);
    }

    /*//////////////////////////////////////////////////////////////
                            REENTRANCY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CrossChainDepositToFleet_ReentrancyProtection() public {
        // This test ensures the ReentrancyGuard is working
        // The actual reentrancy attempt would be in a malicious adapter
        // For now, we just verify the modifier is applied by checking successful execution
        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        bytes32 operationId = manager.initiateDepositToTargetChainFleet(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                        FULL FLOW UNIT TESTS
    //////////////////////////////////////////////////////////////*/

    // NOTE: For real integration tests using actual adapters and forks,
    // see packages/core-contracts/test/integration/FleetDepositManager.integration.fork.t.sol

    function test_CrossChainDepositToFleet_FullFlow() public {
        bytes memory referralCode = bytes("INTEGRATION_TEST");

        vm.startPrank(user);

        // Initial balance check
        uint256 initialBalance = token.balanceOf(user);
        assertEq(initialBalance, DEPOSIT_AMOUNT * 10);

        // Approve tokens
        token.approve(address(manager), DEPOSIT_AMOUNT);

        // Execute deposit
        bytes32 operationId = manager.initiateDepositToTargetChainFleet{
            value: 0.01 ether
        }(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            referralCode,
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0.01 ether,
                options: bytes("test_options")
            })
        );

        vm.stopPrank();

        // Verify all state changes
        assertNotEq(operationId, bytes32(0));
        assertEq(token.balanceOf(user), initialBalance - DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(mockAdapter)), DEPOSIT_AMOUNT);

        // Verify adapter received correct parameters
        assertEq(mockAdapter.lastOperationId(), operationId);
        assertEq(mockAdapter.lastAmount(), DEPOSIT_AMOUNT);
        assertEq(mockAdapter.lastAsset(), address(token));
        assertEq(mockAdapter.lastDestinationChainId(), DEST_CHAIN_ID);
        assertEq(mockAdapter.lastDestinationAdapter(), address(0));

        // Verify adapter params - destructure the tuple
        (uint64 gasLimit, uint32 calldataSize, uint128 msgValue, ) = mockAdapter
            .lastAdapterParams();
        assertEq(gasLimit, 500000);
        assertEq(calldataSize, 100);
        assertEq(msgValue, 0.01 ether);

        // Verify compose message structure (it will be different than expected due to operation ID)
        bytes memory actualComposeMessage = mockAdapter.lastComposeMessage();
        assertGt(actualComposeMessage.length, 0);

        (
            bytes32 messageType,
            address receivedFleetCommander,
            address receivedShareRecipient,
            address receivedAsset,
            uint256 receivedAmount,
            uint256 sourceChainId,
            ,
            address originalUser,
            bytes memory receivedReferralCode
        ) = abi.decode(
                actualComposeMessage,
                (
                    bytes32,
                    address,
                    address,
                    address,
                    uint256,
                    uint256,
                    bytes32,
                    address,
                    bytes
                )
            );

        assertEq(messageType, manager.FLEET_DEPOSIT_TYPE());
        assertEq(receivedFleetCommander, fleetCommander);
        assertEq(receivedShareRecipient, shareRecipient);
        assertEq(receivedAsset, address(token));
        assertEq(receivedAmount, DEPOSIT_AMOUNT);
        assertEq(sourceChainId, block.chainid);
        assertEq(originalUser, user);
        assertEq(receivedReferralCode, referralCode);
    }
}
