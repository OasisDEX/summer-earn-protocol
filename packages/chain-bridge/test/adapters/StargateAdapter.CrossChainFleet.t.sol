// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../src/adapters/StargateAdapter.sol";
import "../src/libraries/BridgeTypes.sol";
import "./mocks/MockStargate.sol";
import "./mocks/MockLayerZeroEndpoint.sol";
import "./mocks/MockERC20.sol";

// Mock FleetCommander for testing
contract MockFleetCommander {
    using SafeERC20 for IERC20;

    address public asset;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public maxDepositLimit;

    event Deposit(address indexed receiver, uint256 assets, uint256 shares);
    event DepositWithReferral(
        address indexed receiver,
        uint256 assets,
        uint256 shares,
        bytes referralCode
    );

    constructor(address _asset) {
        asset = _asset;
        maxDepositLimit = type(uint256).max;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 sharesOut) {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        sharesOut = assets; // 1:1 ratio for simplicity
        shares[receiver] += sharesOut;
        totalShares += sharesOut;
        emit Deposit(receiver, assets, sharesOut);
        return sharesOut;
    }

    function deposit(
        uint256 assets,
        address receiver,
        bytes memory referralCode
    ) external returns (uint256 sharesOut) {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        sharesOut = assets; // 1:1 ratio for simplicity
        shares[receiver] += sharesOut;
        totalShares += sharesOut;
        emit DepositWithReferral(receiver, assets, sharesOut, referralCode);
        return sharesOut;
    }

    function maxDeposit(address) external view returns (uint256) {
        return maxDepositLimit;
    }

    function setMaxDepositLimit(uint256 _limit) external {
        maxDepositLimit = _limit;
    }
}

// Mock FleetCommander that always fails
contract FailingFleetCommander {
    address public asset;

    constructor(address _asset) {
        asset = _asset;
    }

    function deposit(uint256, address) external pure returns (uint256) {
        revert("Always fails");
    }

    function deposit(
        uint256,
        address,
        bytes memory
    ) external pure returns (uint256) {
        revert("Always fails");
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }
}

/**
 * @title Cross-Chain Fleet Deposit Tests for StargateAdapter
 * @dev Comprehensive test suite for cross-chain fleet deposit functionality
 */
contract StargateAdapterCrossChainFleetTest is Test {
    using SafeERC20 for IERC20;

    StargateAdapter public adapter;
    MockLayerZeroEndpoint public lzEndpoint;
    MockStargate public stargate;
    MockERC20 public token;
    MockFleetCommander public fleetCommander;
    FailingFleetCommander public failingFleetCommander;

    address public constant BRIDGE_ROUTER = address(0x1234);
    address public constant OWNER = address(0x5678);
    address public constant USER = address(0x9ABC);
    address public constant SHARE_RECIPIENT = address(0xDEF0);

    uint16 public constant SOURCE_CHAIN_ID = 1;
    uint16 public constant DEST_CHAIN_ID = 2;
    uint32 public constant DEST_ENDPOINT_ID = 30102;

    bytes32 public constant TEST_OPERATION_ID = keccak256("test-operation");

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

    event CrossChainFleetDepositFailed(
        bytes32 indexed operationId,
        address indexed fleetCommander,
        address asset,
        uint256 amount,
        string reason
    );

    function setUp() public {
        // Deploy mock contracts
        lzEndpoint = new MockLayerZeroEndpoint();
        token = new MockERC20("Test Token", "TEST", 6);
        stargate = new MockStargate(address(token));

        // Deploy adapter
        adapter = new StargateAdapter(
            BRIDGE_ROUTER,
            OWNER,
            address(lzEndpoint)
        );

        // Deploy fleet commanders
        fleetCommander = new MockFleetCommander(address(token));
        failingFleetCommander = new FailingFleetCommander(address(token));

        // Setup adapter configuration
        vm.startPrank(OWNER);
        adapter.addSupportedChain(
            DEST_CHAIN_ID,
            DEST_ENDPOINT_ID,
            address(adapter)
        );
        adapter.addSupportedAsset(address(token), address(stargate));
        vm.stopPrank();

        // Mint tokens to user
        token.mint(USER, 10000 * 10 ** 6);

        // Setup stargate mock
        stargate.setToken(address(token));

        vm.label(address(adapter), "StargateAdapter");
        vm.label(address(fleetCommander), "FleetCommander");
        vm.label(address(token), "TestToken");
        vm.label(USER, "User");
        vm.label(SHARE_RECIPIENT, "ShareRecipient");
    }

    function test_CrossChainDepositToFleet_Success() public {
        uint256 amount = 1000 * 10 ** 6;
        bytes memory referralCode = "SUMMER2024";

        // User approves adapter
        vm.prank(USER);
        token.approve(address(adapter), amount);

        // Mock Stargate fee estimation
        stargate.setQuoteFee(0.01 ether);

        // Execute cross-chain deposit
        vm.prank(USER);
        vm.deal(USER, 1 ether);

        vm.expectEmit(true, true, true, false);
        emit CrossChainFleetDepositInitiated(
            bytes32(0), // Will be generated
            DEST_CHAIN_ID,
            USER,
            address(fleetCommander),
            address(token),
            amount,
            SHARE_RECIPIENT
        );

        bytes32 operationId = adapter.crossChainDepositToFleet{
            value: 0.01 ether
        }(
            DEST_CHAIN_ID,
            address(token),
            amount,
            address(fleetCommander),
            SHARE_RECIPIENT,
            referralCode,
            BridgeTypes.AdapterParams(bytes(""))
        );

        // Verify tokens were transferred from user
        assertEq(token.balanceOf(USER), 9000 * 10 ** 6);
        assertEq(token.balanceOf(address(adapter)), amount);

        // Verify operation ID was generated
        assertTrue(operationId != bytes32(0));
    }

    function test_CrossChainDepositToFleet_ZeroAmount() public {
        vm.prank(USER);
        vm.expectRevert(StargateAdapter.InvalidParams.selector);
        adapter.crossChainDepositToFleet(
            DEST_CHAIN_ID,
            address(token),
            0,
            address(fleetCommander),
            SHARE_RECIPIENT,
            bytes(""),
            BridgeTypes.AdapterParams(bytes(""))
        );
    }

    function test_CrossChainDepositToFleet_InvalidFleetCommander() public {
        vm.prank(USER);
        vm.expectRevert(StargateAdapter.InvalidParams.selector);
        adapter.crossChainDepositToFleet(
            DEST_CHAIN_ID,
            address(token),
            1000 * 10 ** 6,
            address(0),
            SHARE_RECIPIENT,
            bytes(""),
            BridgeTypes.AdapterParams(bytes(""))
        );
    }

    function test_CrossChainDepositToFleet_InvalidShareRecipient() public {
        vm.prank(USER);
        vm.expectRevert(StargateAdapter.InvalidParams.selector);
        adapter.crossChainDepositToFleet(
            DEST_CHAIN_ID,
            address(token),
            1000 * 10 ** 6,
            address(fleetCommander),
            address(0),
            bytes(""),
            BridgeTypes.AdapterParams(bytes(""))
        );
    }

    function test_CrossChainDepositToFleet_UnsupportedChain() public {
        vm.prank(USER);
        vm.expectRevert(StargateAdapter.UnsupportedChain.selector);
        adapter.crossChainDepositToFleet(
            999, // Unsupported chain
            address(token),
            1000 * 10 ** 6,
            address(fleetCommander),
            SHARE_RECIPIENT,
            bytes(""),
            BridgeTypes.AdapterParams(bytes(""))
        );
    }

    function test_CrossChainDepositToFleet_UnsupportedAsset() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNSUP", 18);

        vm.prank(USER);
        vm.expectRevert(StargateAdapter.UnsupportedAsset.selector);
        adapter.crossChainDepositToFleet(
            DEST_CHAIN_ID,
            address(unsupportedToken),
            1000 * 10 ** 18,
            address(fleetCommander),
            SHARE_RECIPIENT,
            bytes(""),
            BridgeTypes.AdapterParams(bytes(""))
        );
    }

    function test_EstimateFleetDepositFee() public {
        uint256 amount = 1000 * 10 ** 6;
        bytes memory referralCode = "SUMMER2024";

        stargate.setQuoteFee(0.015 ether);

        // Create compose message for fleet deposit
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(token),
            amount,
            block.chainid,
            bytes32(0), // operation ID
            USER, // original user
            referralCode
        );

        (uint256 nativeFee, uint256 tokenFee) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(token),
            amount,
            BridgeTypes.AdapterParams({
                gasLimit: 500000, // Higher gas for fleet operations
                calldataSize: 0,
                msgValue: 0,
                options: composeMsg
            }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        assertEq(nativeFee, 0.015 ether);
        assertEq(tokenFee, 0);
    }

    function test_EstimateFleetDepositFee_UnsupportedChain() public {
        vm.expectRevert(StargateAdapter.UnsupportedChain.selector);
        adapter.estimateFee(
            999,
            address(token),
            1000 * 10 ** 6,
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    function test_HandleFleetDepositMessage_Success() public {
        uint256 amount = 1000 * 10 ** 6;
        bytes memory referralCode = "SUMMER2024";

        // Create fleet deposit compose message
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(token),
            amount,
            uint256(SOURCE_CHAIN_ID),
            TEST_OPERATION_ID,
            USER,
            referralCode
        );

        // Mock OFT compose message encoding
        bytes memory oftMessage = abi.encodePacked(
            uint64(1), // nonce
            uint32(SOURCE_CHAIN_ID), // srcEid
            amount, // amountLD
            composeMsg
        );

        // Fund adapter with tokens (as if received from Stargate)
        token.mint(address(adapter), amount);

        // Mock the stargate call by setting up the endpoint call
        vm.prank(address(lzEndpoint));
        vm.expectEmit(true, true, true, true);
        emit CrossChainFleetDepositCompleted(
            TEST_OPERATION_ID,
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(token),
            amount,
            amount, // 1:1 share ratio
            SOURCE_CHAIN_ID
        );

        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );

        // Verify fleet commander received the deposit
        assertEq(fleetCommander.shares(SHARE_RECIPIENT), amount);
        assertEq(token.balanceOf(address(fleetCommander)), amount);
        assertEq(token.balanceOf(address(adapter)), 0);
    }

    function test_HandleFleetDepositMessage_FleetCommanderFailure() public {
        uint256 amount = 1000 * 10 ** 6;

        // Create fleet deposit compose message with failing fleet commander
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(failingFleetCommander),
            SHARE_RECIPIENT,
            address(token),
            amount,
            uint256(SOURCE_CHAIN_ID),
            TEST_OPERATION_ID,
            USER,
            bytes("")
        );

        // Mock OFT compose message encoding
        bytes memory oftMessage = abi.encodePacked(
            uint64(1), // nonce
            uint32(SOURCE_CHAIN_ID), // srcEid
            amount, // amountLD
            composeMsg
        );

        // Fund adapter with tokens
        token.mint(address(adapter), amount);

        // Expect failure event
        vm.expectEmit(true, true, true, true);
        emit CrossChainFleetDepositFailed(
            TEST_OPERATION_ID,
            address(failingFleetCommander),
            address(token),
            amount,
            "Always fails"
        );

        vm.prank(address(lzEndpoint));
        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );

        // Verify tokens are held by adapter for recovery
        assertEq(token.balanceOf(address(adapter)), amount);

        // Check failed compose was recorded
        (
            address failedAsset,
            uint256 failedAmount,
            address intendedRecipient,
            bytes32 failedOpId,
            address originator,
            uint16 sourceChainId,
            uint256 timestamp,
            bool isDeposit
        ) = adapter.failedComposes(TEST_OPERATION_ID);

        assertEq(failedAsset, address(token));
        assertEq(failedAmount, amount);
        assertEq(intendedRecipient, address(failingFleetCommander));
        assertEq(failedOpId, TEST_OPERATION_ID);
        assertEq(originator, USER);
        assertEq(sourceChainId, SOURCE_CHAIN_ID);
        assertTrue(isDeposit);
        assertTrue(timestamp > 0);
    }

    function test_HandleFleetDepositMessage_InsufficientBalance() public {
        uint256 amount = 1000 * 10 ** 6;

        // Create fleet deposit compose message
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(fleetCommander),
            SHARE_RECIPIENT,
            address(token),
            amount,
            uint256(SOURCE_CHAIN_ID),
            TEST_OPERATION_ID,
            USER,
            bytes("")
        );

        // Mock OFT compose message encoding
        bytes memory oftMessage = abi.encodePacked(
            uint64(1), // nonce
            uint32(SOURCE_CHAIN_ID), // srcEid
            amount, // amountLD
            composeMsg
        );

        // Don't fund adapter with tokens - should revert
        vm.prank(address(lzEndpoint));
        vm.expectRevert(StargateAdapter.InsufficientBalance.selector);
        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );
    }

    function test_DepositToFleetCommander_WrongAsset() public {
        MockERC20 wrongToken = new MockERC20("Wrong", "WRONG", 18);
        MockFleetCommander wrongAssetFleet = new MockFleetCommander(
            address(wrongToken)
        );

        uint256 amount = 1000 * 10 ** 6;
        token.mint(address(adapter), amount);

        vm.expectRevert(StargateAdapter.InvalidParams.selector);
        adapter._depositToFleetCommander(
            address(wrongAssetFleet),
            address(token),
            amount,
            SHARE_RECIPIENT,
            bytes(""),
            TEST_OPERATION_ID,
            USER,
            address(token),
            SOURCE_CHAIN_ID
        );
    }

    function test_DepositToFleetCommander_ExceedsMaxDeposit() public {
        uint256 amount = 1000 * 10 ** 6;
        token.mint(address(adapter), amount);

        // Set low deposit limit
        fleetCommander.setMaxDepositLimit(amount / 2);

        vm.expectRevert(StargateAdapter.InvalidParams.selector);
        adapter._depositToFleetCommander(
            address(fleetCommander),
            address(token),
            amount,
            SHARE_RECIPIENT,
            bytes(""),
            TEST_OPERATION_ID,
            USER,
            address(token),
            SOURCE_CHAIN_ID
        );
    }

    function test_DepositToFleetCommander_WithReferralCode() public {
        uint256 amount = 1000 * 10 ** 6;
        bytes memory referralCode = "SUMMER2024";
        token.mint(address(adapter), amount);

        vm.expectEmit(true, true, true, true);
        emit MockFleetCommander.DepositWithReferral(
            SHARE_RECIPIENT,
            amount,
            amount,
            referralCode
        );

        uint256 shares = adapter._depositToFleetCommander(
            address(fleetCommander),
            address(token),
            amount,
            SHARE_RECIPIENT,
            referralCode,
            TEST_OPERATION_ID,
            USER,
            address(token),
            SOURCE_CHAIN_ID
        );

        assertEq(shares, amount);
        assertEq(fleetCommander.shares(SHARE_RECIPIENT), amount);
    }

    function test_DepositToFleetCommander_UnauthorizedCaller() public {
        vm.prank(USER);
        vm.expectRevert(StargateAdapter.Unauthorized.selector);
        adapter._depositToFleetCommander(
            address(fleetCommander),
            address(token),
            1000 * 10 ** 6,
            SHARE_RECIPIENT,
            bytes(""),
            TEST_OPERATION_ID,
            USER,
            address(token),
            SOURCE_CHAIN_ID
        );
    }

    function test_IsFleetCommander() public {
        assertTrue(adapter._isFleetCommander(address(fleetCommander)));
        assertFalse(adapter._isFleetCommander(address(token)));
        assertFalse(adapter._isFleetCommander(address(0)));
    }

    function test_LegacyAssetTransferStillWorks() public {
        uint256 amount = 1000 * 10 ** 6;

        // Create legacy compose message (old format)
        bytes memory legacyComposeMsg = abi.encode(
            SHARE_RECIPIENT, // recipient
            address(token), // sourceAsset
            amount, // amount (not used in current implementation)
            uint256(SOURCE_CHAIN_ID), // sourceChainId
            TEST_OPERATION_ID, // operationId
            USER // originator
        );

        // Mock OFT compose message encoding
        bytes memory oftMessage = abi.encodePacked(
            uint64(1), // nonce
            uint32(SOURCE_CHAIN_ID), // srcEid
            amount, // amountLD
            legacyComposeMsg
        );

        // Fund adapter and recipient
        token.mint(address(adapter), amount);

        vm.prank(address(lzEndpoint));
        // This should process as legacy message since it doesn't start with FLEET_DEPOSIT_TYPE
        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );

        // Should transfer tokens to recipient (legacy behavior)
        assertEq(token.balanceOf(SHARE_RECIPIENT), amount);
    }

    function test_ManualRecovery_FleetDeposit() public {
        uint256 amount = 1000 * 10 ** 6;

        // First create a failed fleet deposit
        bytes memory composeMsg = abi.encode(
            adapter.FLEET_DEPOSIT_TYPE(),
            address(failingFleetCommander),
            SHARE_RECIPIENT,
            address(token),
            amount,
            uint256(SOURCE_CHAIN_ID),
            TEST_OPERATION_ID,
            USER,
            bytes("")
        );

        bytes memory oftMessage = abi.encodePacked(
            uint64(1),
            uint32(SOURCE_CHAIN_ID),
            amount,
            composeMsg
        );

        token.mint(address(adapter), amount);

        vm.prank(address(lzEndpoint));
        adapter.lzCompose(
            address(stargate),
            bytes32(0),
            oftMessage,
            address(0),
            bytes("")
        );

        // Verify failure was recorded
        (
            address failedAsset,
            uint256 failedAmount,
            ,
            ,
            ,
            ,
            ,
            bool isDeposit
        ) = adapter.failedComposes(TEST_OPERATION_ID);
        assertEq(failedAsset, address(token));
        assertEq(failedAmount, amount);
        assertTrue(isDeposit);

        // Manual recovery by governance
        bytes memory customMessage = abi.encode(
            TEST_OPERATION_ID,
            USER,
            address(token)
        );

        vm.prank(OWNER);
        adapter.manualRecovery(
            address(token),
            amount,
            SHARE_RECIPIENT,
            TEST_OPERATION_ID,
            false, // Don't try receive call for failed fleet deposits
            customMessage
        );

        // Verify tokens were recovered
        assertEq(token.balanceOf(SHARE_RECIPIENT), amount);
        assertEq(token.balanceOf(address(adapter)), 0);

        // Verify failed compose was cleared
        (address clearedAsset, , , , , , , bool clearedIsDeposit) = adapter
            .failedComposes(TEST_OPERATION_ID);
        assertEq(clearedAsset, address(0));
        assertFalse(clearedIsDeposit);
    }
}
