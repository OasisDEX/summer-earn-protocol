// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title MockBridgeRouter
 * @notice Mock implementation of IBridgeRouter for testing purposes.
 */
contract MockBridgeRouter is Test, IBridgeRouter {
    using SafeERC20 for IERC20;

    // --- Mock State ---
    uint256 public mockFeeMultiplier = 200; // Default 200%
    address public mockBridgeQueueAddress;
    address public mockAuthorizedExecutor;
    address public constant MOCK_ADAPTER_ADDRESS = address(0xAA);
    uint256 public constant QUOTE_GAS = 50000; // Example gas estimate
    bool public shouldRevert = false; // Flag to control reverting behavior
    bool public mockPaused = false; // Added from core contracts version
    uint256 public mockFee = 0.1 ether; // Added for quote function

    // Variables to control mock behavior (Added from core contracts version)
    bytes32 public nextTransferId;
    bytes32 public nextMessageId;
    // READ_STATE removed

    // Track calls for verification (Added from core contracts version)
    struct TransferCall {
        uint16 destinationChainId;
        address asset;
        uint256 amount;
        address target;
        bytes message;
    }

    struct MessageCall {
        uint16 destinationChainId;
        address target;
        bytes message;
    }

    TransferCall[] public transferCalls;
    MessageCall[] public messageCalls;

    // Mock-specific events (Added from core contracts version)
    event MockTransferAssets(
        bytes32 operationId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address target
    );
    event MockSendMessage(
        bytes32 operationId,
        uint16 destinationChainId,
        address target,
        bytes message
    );

    mapping(bytes32 => address) public operationOriginators; // Track who requested via queue
    mapping(bytes32 => address) public operationAdapters;
    mapping(bytes32 => uint256) public operationBaseFeesPaid; // Track fee forwarded by queue

    uint256 internal operationNonce; // To generate unique mock operation IDs

    uint64 public defaultGasLimit = 200000; // Default value matching the real implementation

    // Add mapping for registered adapters
    mapping(address => bool) public registeredAdapters;

    // --- Extended recording for stricter tests ---
    bool public useRefundAddressInsteadOfSender = false;
    address public lastRefundAddress;
    address public lastOriginator;
    address public lastTarget;
    address public lastAsset;
    uint256 public lastAmount;
    uint16 public lastDestinationChainId;
    uint256 public lastMsgValue;

    address public lastMsgRefundAddress;
    address public lastMsgOriginator;
    address public lastMsgTarget;
    uint16 public lastMsgDestinationChainId;
    bytes public lastMsgMessage;

    // --- Errors ---
    error CallerNotBridgeQueue();
    error RefundFailed();

    // --- Modifiers ---
    modifier onlyAuthorizedExecutor() {
        address expected = mockAuthorizedExecutor == address(0)
            ? mockBridgeQueueAddress
            : mockAuthorizedExecutor;
        if (expected != address(0) && msg.sender != expected) {
            revert CallerNotBridgeQueue();
        }
        _;
    }

    // --- Constructor ---
    constructor() {
        // Can initialize mock state if needed
    }

    // --- Mock Specific Setters ---
    function setFeeMultiplier(uint256 _multiplier) external {
        mockFeeMultiplier = _multiplier;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setUseRefundAddress(bool _use) external {
        useRefundAddressInsteadOfSender = _use;
    }

    function setAuthorizedExecutor(address executor) external {
        mockAuthorizedExecutor = executor;
    }

    function setBridgeQueue(address queue) external {
        mockBridgeQueueAddress = queue;
    }

    // Add registerAdapter function
    function registerAdapter(address adapter) external {
        registeredAdapters[adapter] = true;
    }

    // Add isValidAdapter function
    function isValidAdapter(address adapter) external view returns (bool) {
        return registeredAdapters[adapter];
    }

    // --- IBridgeRouter Implementation ---

    // --- Main Functions ---

    function quoteTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata /* params */,
        BridgeTypes.BridgeOptions calldata /* options */
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        nativeFee = mockFee;
        tokenFee = 0;
        specifiedAdapter = MOCK_ADAPTER_ADDRESS;
    }

    // READ_STATE quote removed

    function quoteSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata /* params */,
        BridgeTypes.BridgeOptions calldata /* options */
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        nativeFee = mockFee / 5; // Lower fee for message operations
        tokenFee = 0;
        specifiedAdapter = MOCK_ADAPTER_ADDRESS;
    }

    function quote(
        uint16 /* destinationChainId */,
        address /* asset */,
        uint256 /* amount */,
        BridgeTypes.BridgeOptions calldata /* options */,
        BridgeTypes.OperationType /* operationType */
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        nativeFee = mockFee;
        tokenFee = 0;
        specifiedAdapter = MOCK_ADAPTER_ADDRESS;
        return (nativeFee, tokenFee, specifiedAdapter);
    }

    // --- Internal Execution Functions (Helper for external calls) ---
    // Updated to accept the struct, although called by the external funcs below

    function _executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal returns (bytes32 operationId) {
        if (shouldRevert) {
            revert("MockRouter: Execution failed");
        }

        // Record params for assertions in tests
        lastOriginator = params.originator;
        lastTarget = params.target;
        lastAsset = params.asset;
        lastAmount = params.amount;
        lastDestinationChainId = params.destinationChainId;
        lastRefundAddress = params.refundAddress;
        lastMsgValue = msg.value;

        operationId = keccak256(abi.encodePacked("transfer", operationNonce++));
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS; // Store specified adapter
        operationBaseFeesPaid[operationId] = msg.value; // Track base fee received

        // Simulate token transfer from queue (already approved)
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        ); // Pull from queue
        // Keep tokens in the router for testing purposes
        // In a real scenario, this would transfer to the adapter or burn/lock

        // Record the call (align with behavior that transfer carries message)
        transferCalls.push(
            TransferCall({
                destinationChainId: params.destinationChainId,
                asset: params.asset,
                amount: params.amount,
                target: params.target,
                message: params.message
            })
        );

        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target,
            MOCK_ADAPTER_ADDRESS
        );

        // Refund any excess native fee to the keeper or provided refundAddress (for stricter tests)
        uint256 baseFee = 0.1 ether; // Base fee from quote
        if (msg.value > baseFee) {
            address refundTo = useRefundAddressInsteadOfSender
                ? params.refundAddress
                : msg.sender;
            (bool success, ) = refundTo.call{value: msg.value - baseFee}("");
            if (!success) revert RefundFailed();
        }

        return operationId;
    }

    // READ_STATE exec removed

    function _executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params
    ) internal returns (bytes32 operationId) {
        // Record params for assertions in tests
        lastMsgOriginator = params.originator;
        lastMsgTarget = params.target;
        lastMsgDestinationChainId = params.destinationChainId;
        lastMsgMessage = params.message;
        lastMsgRefundAddress = params.refundAddress;
        lastMsgValue = msg.value;

        operationId = keccak256(abi.encodePacked("message", operationNonce++));
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;
        operationBaseFeesPaid[operationId] = msg.value;

        emit MessageInitiated(
            operationId,
            params.destinationChainId,
            params.target,
            MOCK_ADAPTER_ADDRESS
        );

        // Refund any excess native fee to the keeper or provided refundAddress (for stricter tests)
        uint256 baseFee = 0.1 ether; // Base fee from quote
        if (msg.value > baseFee) {
            address refundTo = useRefundAddressInsteadOfSender
                ? params.refundAddress
                : msg.sender;
            (bool success, ) = refundTo.call{value: msg.value - baseFee}("");
            if (!success) revert RefundFailed();
        }

        return operationId;
    }

    function deliver(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload
    ) external {
        bytes32 operationId;

        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedTransferParams)
            );

            operationId = data.operationId;

            // Track the handling adapter
            operationAdapters[data.operationId] = msg.sender;

            // Transfer the asset if we have tokens
            if (data.asset != address(0) && data.amount > 0) {
                IERC20(data.asset).safeTransfer(data.recipient, data.amount);
            }

            // Call appropriate receiver interface
            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                abi.encode(data)
            );
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedMessageParams)
            );

            operationId = data.operationId;

            // Track the handling adapter
            operationAdapters[data.operationId] = msg.sender;

            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.MESSAGE,
                abi.encode(data)
            );
        } else if (operationType == BridgeTypes.OperationType.READ_STATE) {
            revert("UnsupportedOperationType");
        } else {
            revert("UnsupportedOperationType");
        }

        emit OperationDelivered(operationId, operationType);
    }

    // Implement other view functions simply returning mock/default values

    function getAdapters() external pure returns (address[] memory) {
        address[] memory adapters = new address[](1);
        adapters[0] = MOCK_ADAPTER_ADDRESS;
        return adapters;
    }

    function getRouterBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function feeMultiplier() external view returns (uint256) {
        return mockFeeMultiplier;
    }

    function bridgeQueue() external view returns (address) {
        return mockBridgeQueueAddress;
    }

    // --- Admin Functions ---
    // Implement simplified versions for testing setup or ignore if not needed for queue tests
    function removeAdapter(address adapter) external override {
        emit AdapterRemoved(adapter);
    }

    function pause() external override {
        mockPaused = true;
    }

    function unpause() external override {
        mockPaused = false;
    }

    function sweep(
        address token,
        address recipient,
        uint256 amount
    ) external override {
        if (token == address(0)) {
            (bool s, ) = payable(recipient).call{value: amount}("");
            require(s);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
        emit RouterAssetsRecovered(token, recipient, amount);
    }

    // --- Interface Support ---
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IBridgeRouter).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    // --- Receive Ether ---
    receive() external payable {}

    fallback() external payable {}

    // --- External Execute Functions (Matching IBridgeRouter) ---

    function executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata
    )
        external
        payable
        override
        onlyAuthorizedExecutor
        returns (bytes32 operationId)
    {
        return _executeTransferAssets(params);
    }

    // READ_STATE external exec removed

    function executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata
    )
        external
        payable
        override
        onlyAuthorizedExecutor
        returns (bytes32 operationId)
    {
        // Record the call
        messageCalls.push(
            MessageCall({
                destinationChainId: params.destinationChainId,
                target: params.target,
                message: params.message
            })
        );

        return _executeSendMessage(params);
    }

    // Add missing functions from core contracts version
    function clearCalls() external {
        delete transferCalls;
        delete messageCalls;
    }

    function getTransferCallCount() external view returns (uint256) {
        return transferCalls.length;
    }

    function getMessageCallCount() external view returns (uint256) {
        return messageCalls.length;
    }

    // Update transferAssets to record calls
    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address target,
        BridgeTypes.BridgeOptions calldata
    ) external payable returns (bytes32) {
        if (mockPaused) revert Paused();
        if (shouldRevert) revert TransferFailed();

        // Record the call
        transferCalls.push(
            TransferCall({
                destinationChainId: destinationChainId,
                asset: asset,
                amount: amount,
                target: target,
                message: ""
            })
        );

        bytes32 operationId = nextTransferId;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;

        emit TransferInitiated(
            operationId,
            destinationChainId,
            asset,
            amount,
            target,
            MOCK_ADAPTER_ADDRESS
        );

        emit MockTransferAssets(
            operationId,
            destinationChainId,
            asset,
            amount,
            target
        );

        return operationId;
    }

    // Update sendMessage to record calls
    function sendMessage(
        uint16 destinationChainId,
        address target,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata
    ) external payable returns (bytes32) {
        if (mockPaused) revert Paused();

        // Record the call
        messageCalls.push(
            MessageCall({
                destinationChainId: destinationChainId,
                target: target,
                message: message
            })
        );

        bytes32 operationId = nextMessageId;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;

        emit MessageInitiated(
            operationId,
            destinationChainId,
            target,
            MOCK_ADAPTER_ADDRESS
        );

        emit MockSendMessage(operationId, destinationChainId, target, message);

        return operationId;
    }

    // Add configureMock function from core contracts version
    function configureMock(
        bytes32 _nextTransferId,
        bytes32 _nextMessageId,
        bool _mockPaused,
        bool _shouldRevert,
        uint256 _mockFee,
        address
    ) external {
        nextTransferId = _nextTransferId;
        nextMessageId = _nextMessageId;
        mockPaused = _mockPaused;
        shouldRevert = _shouldRevert;
        mockFee = _mockFee;
        // Note: We don't have mockSpecifiedAdapter in this version as we use MOCK_ADAPTER_ADDRESS
    }

    // Add readState function from core contracts version
    function readState(
        uint16 destinationChainId,
        address target,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata
    ) external payable returns (bytes32) {
        if (mockPaused) revert Paused();

        bytes32 operationId = nextReadId;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;

        emit ReadRequestInitiated(
            operationId,
            destinationChainId,
            target,
            selector,
            readParams,
            MOCK_ADAPTER_ADDRESS
        );

        return operationId;
    }
}
