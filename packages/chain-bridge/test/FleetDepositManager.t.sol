// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FleetDepositManager} from "../src/FleetDepositManager.sol";
import {IFleetDepositAdapter} from "../src/interfaces/IFleetDepositAdapter.sol";
import {BridgeTypes} from "../src/libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock adapter for testing
contract MockFleetDepositAdapter is IFleetDepositAdapter {
    bool public shouldRevert = false;
    bytes32 public lastOperationId;
    uint256 public lastAmount;
    address public lastAsset;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function executeCrossChainFleetDeposit(
        uint16,
        address asset,
        uint256 amount,
        address,
        bytes memory,
        BridgeTypes.AdapterParams calldata
    ) external payable override returns (bytes32 operationId) {
        if (shouldRevert) revert("Mock adapter reverted");

        operationId = keccak256(abi.encode(block.timestamp, amount));
        lastOperationId = operationId;
        lastAmount = amount;
        lastAsset = asset;

        return operationId;
    }

    function supportsFleetDeposits() external pure override returns (bool) {
        return true;
    }

    // Add estimateFee method for testing
    function estimateFee(
        uint16,
        address,
        uint256,
        BridgeTypes.AdapterParams calldata,
        BridgeTypes.OperationType
    ) external pure returns (uint256 nativeFee, uint256 tokenFee) {
        return (0.01 ether, 0);
    }
}

// Mock ERC20 token
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock access manager
contract MockAccessManager {
    mapping(address => bool) public governors;

    constructor() {
        governors[msg.sender] = true;
    }

    function setGovernor(address governor, bool isGovernor) external {
        governors[governor] = isGovernor;
    }

    function hasRole(bytes32, address account) external view returns (bool) {
        return governors[account];
    }
}

// Mock bridge router
contract MockBridgeRouter {
    mapping(address => bool) public registeredAdapters;

    function registerAdapter(address adapter) external {
        registeredAdapters[adapter] = true;
    }

    function isValidAdapter(address adapter) external view returns (bool) {
        return registeredAdapters[adapter];
    }
}

contract FleetDepositManagerTest is Test {
    FleetDepositManager public manager;
    MockFleetDepositAdapter public mockAdapter;
    MockToken public token;
    MockAccessManager public accessManager;
    MockBridgeRouter public mockBridgeRouter;

    address public user = address(0x1);
    address public fleetCommander = address(0x2);
    uint16 public constant DEST_CHAIN_ID = 8453; // Base
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;

    event CrossChainFleetDepositInitiated(
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
        accessManager = new MockAccessManager();
        mockBridgeRouter = new MockBridgeRouter();
        manager = new FleetDepositManager(
            address(accessManager),
            address(mockBridgeRouter)
        );
        mockAdapter = new MockFleetDepositAdapter();
        token = new MockToken();

        // Setup user with tokens
        token.mint(user, DEPOSIT_AMOUNT * 10);

        // Register mock adapter with bridge router
        mockBridgeRouter.registerAdapter(address(mockAdapter));
    }

    function test_IsAdapterSupported() public {
        // Test supported adapter
        assertTrue(manager.isAdapterSupported(address(mockAdapter)));

        // Test unsupported adapter
        address unsupportedAdapter = address(0x999);
        assertFalse(manager.isAdapterSupported(unsupportedAdapter));
    }

    function test_CrossChainDepositToFleet() public {
        vm.startPrank(user);

        // Approve and deposit
        token.approve(address(manager), DEPOSIT_AMOUNT);

        // Create compose message for fee estimation
        bytes memory composeMessage = manager.createFleetDepositMessage(
            fleetCommander,
            user,
            address(token),
            DEPOSIT_AMOUNT,
            bytes("")
        );

        // Estimate fee using adapter's estimateFee with compose message
        (uint256 nativeFee, ) = mockAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: composeMessage
            }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Execute deposit
        vm.expectEmit(true, true, true, false);
        emit CrossChainFleetDepositInitiated(
            bytes32(0), // operationId will be different
            DEST_CHAIN_ID,
            user,
            address(mockAdapter),
            fleetCommander,
            address(token),
            DEPOSIT_AMOUNT,
            user
        );

        bytes32 operationId = manager.crossChainDepositToFleet{
            value: nativeFee
        }(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            user,
            bytes(""),
            BridgeTypes.AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("")
            })
        );

        vm.stopPrank();

        // Verify operation completed
        assertNotEq(operationId, bytes32(0));
        assertEq(mockAdapter.lastOperationId(), operationId);
        assertEq(mockAdapter.lastAmount(), DEPOSIT_AMOUNT);
        assertEq(mockAdapter.lastAsset(), address(token));
    }

    function test_UnsupportedAdapter() public {
        address unsupportedAdapter = address(0x999);

        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        vm.expectRevert(FleetDepositManager.UnsupportedBridgeAdapter.selector);
        manager.crossChainDepositToFleet(
            unsupportedAdapter,
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            user,
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

    function test_CreateFleetDepositMessage() public {
        bytes memory composeMessage = manager.createFleetDepositMessage(
            fleetCommander,
            user,
            address(token),
            DEPOSIT_AMOUNT,
            bytes("SUMMER2024")
        );

        assertGt(composeMessage.length, 0);

        // Decode message to verify it contains correct data
        (
            bytes32 messageType,
            address decodedFleetCommander,
            address decodedRecipient,
            address decodedAsset,
            uint256 decodedAmount
        ) = abi.decode(
                composeMessage,
                (bytes32, address, address, address, uint256)
            );

        assertEq(messageType, manager.FLEET_DEPOSIT_TYPE());
        assertEq(decodedFleetCommander, fleetCommander);
        assertEq(decodedRecipient, user);
        assertEq(decodedAsset, address(token));
        assertEq(decodedAmount, DEPOSIT_AMOUNT);
    }

    function test_FleetDepositWithReferralCode() public {
        bytes memory referralCode = bytes("SUMMER2024");

        vm.startPrank(user);
        token.approve(address(manager), DEPOSIT_AMOUNT);

        bytes32 operationId = manager.crossChainDepositToFleet{
            value: 0.01 ether
        }(
            address(mockAdapter),
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            user,
            referralCode,
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
}
