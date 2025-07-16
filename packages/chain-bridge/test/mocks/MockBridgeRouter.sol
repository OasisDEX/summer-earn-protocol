// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28; // Using Test contract for cheatcodes like makeAddr if needed

import { IBridgeRouter } from "../../src/interfaces/IBridgeRouter.sol";
import { BridgeTypes } from "../../src/libraries/BridgeTypes.sol";

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Test } from "forge-std/Test.sol";

/**
 * @title MockBridgeRouter
 * @notice Mock implementation of IBridgeRouter for testing purposes.
 */
contract MockBridgeRouter is Test, IBridgeRouter {

    using SafeERC20 for IERC20;

    // --- Mock State ---
    uint256 public mockFeeMultiplier = 200; // Default 200%
    address public mockBridgeQueueAddress;
    address public constant MOCK_ADAPTER_ADDRESS = address(0xAA);
    uint256 public constant QUOTE_GAS = 50000; // Example gas estimate
    bool public shouldRevert = false; // Flag to control reverting behavior
    bool public mockPaused = false; // Added from core contracts version
    uint256 public mockFee = 0.1 ether; // Added for quote function

    // Variables to control mock behavior (Added from core contracts version)
    bytes32 public nextTransferId;
    bytes32 public nextMessageId;
    bytes32 public nextReadId;

    // Track calls for verification (Added from core contracts version)
    struct TransferCall {
        uint16 destinationChainId;
        address asset;
        uint256 amount;
        address recipient;
    }

    struct MessageCall {
        uint16 destinationChainId;
        address recipient;
        bytes message;
    }

    TransferCall[] public transferCalls;
    MessageCall[] public messageCalls;

    // Mock-specific events (Added from core contracts version)
    event MockTransferAssets(
        bytes32 operationId, uint16 destinationChainId, address asset, uint256 amount, address recipient
    );
    event MockSendMessage(bytes32 operationId, uint16 destinationChainId, address recipient, bytes message);

    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatuses;
    mapping(bytes32 => address) public operationOriginators; // Track who requested via queue
    mapping(bytes32 => address) public operationAdapters;
    mapping(bytes32 => uint256) public operationBaseFeesPaid; // Track fee forwarded by queue

    uint256 internal operationNonce; // To generate unique mock operation IDs

    // Add mapping for chain to router addresses if not already present
    mapping(uint16 => address) public chainToRouterAddress;

    uint64 public DEFAULT_GAS_LIMIT = 200000; // Default value matching the real implementation

    // Add mapping for registered adapters
    mapping(address => bool) public registeredAdapters;

    // --- Errors ---
    error CallerNotBridgeQueue();
    error RefundFailed();

    // --- Modifiers ---
    modifier onlyAuthorizedExecutor() {
        // todo: add access manager or something similar
        // if (msg.sender != mockBridgeQueueAddress) {
        //     revert CallerNotAuthorized();
        // }
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

    function setMockOperationStatus(bytes32 _operationId, BridgeTypes.OperationStatus _status) external {
        operationStatuses[_operationId] = _status;
        emit OperationStatusUpdated(_operationId, _status); // Simulate update
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

    function quote(
        uint16, /* destinationChainId */
        address, /* asset */
        uint256, /* amount */
        BridgeTypes.BridgeOptions calldata, /* options */
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

    function _executeTransferAssets(BridgeTypes.ExecuteTransferParams calldata params)
        internal
        returns (bytes32 operationId)
    {
        if (shouldRevert) {
            revert("MockRouter: Execution failed");
        }

        operationId = keccak256(abi.encodePacked("transfer", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS; // Store specified adapter
        operationBaseFeesPaid[operationId] = msg.value; // Track base fee received

        // Simulate token transfer from queue (already approved)
        IERC20(params.asset).safeTransferFrom(msg.sender, address(this), params.amount); // Pull from queue
        // Keep tokens in the router for testing purposes
        // In a real scenario, this would transfer to the adapter or burn/lock

        emit TransferInitiated(
            operationId, params.destinationChainId, params.asset, params.amount, params.recipient, MOCK_ADAPTER_ADDRESS
        );
        emit OperationStatusUpdated(operationId, BridgeTypes.OperationStatus.SENT);

        // Refund any excess native fee to the keeper
        uint256 baseFee = 0.1 ether; // Base fee from quote
        if (msg.value > baseFee) {
            (bool success,) = msg.sender.call{ value: msg.value - baseFee }("");
            if (!success) revert RefundFailed();
        }

        return operationId;
    }

    function _executeReadState(BridgeTypes.ExecuteReadStateParams calldata params)
        internal
        returns (bytes32 operationId)
    {
        operationId = keccak256(abi.encodePacked("read", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;
        operationBaseFeesPaid[operationId] = msg.value;

        emit ReadRequestInitiated(
            operationId,
            params.destinationChainId,
            params.destinationContract,
            params.selector,
            params.readParams,
            MOCK_ADAPTER_ADDRESS
        );
        emit OperationStatusUpdated(operationId, BridgeTypes.OperationStatus.SENT);

        // Refund any excess native fee to the keeper
        uint256 baseFee = 0.1 ether; // Base fee from quote
        if (msg.value > baseFee) {
            (bool success,) = msg.sender.call{ value: msg.value - baseFee }("");
            if (!success) revert RefundFailed();
        }

        return operationId;
    }

    function _executeSendMessage(BridgeTypes.ExecuteSendMessageParams calldata params)
        internal
        returns (bytes32 operationId)
    {
        operationId = keccak256(abi.encodePacked("message", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;
        operationBaseFeesPaid[operationId] = msg.value;

        emit MessageInitiated(operationId, params.destinationChainId, params.recipient, MOCK_ADAPTER_ADDRESS);
        emit OperationStatusUpdated(operationId, BridgeTypes.OperationStatus.SENT);

        // Refund any excess native fee to the keeper
        uint256 baseFee = 0.1 ether; // Base fee from quote
        if (msg.value > baseFee) {
            (bool success,) = msg.sender.call{ value: msg.value - baseFee }("");
            if (!success) revert RefundFailed();
        }

        return operationId;
    }

    // --- Adapter Callbacks ---
    // These are simplified, just updating status. Real adapters would call these.
    function updateOperationStatus(bytes32 operationId, BridgeTypes.OperationStatus status) external override {
        // In real scenario, would check msg.sender is the expected adapter (operationAdapters[operationId])
        if (operationAdapters[operationId] == address(0)) {
            // If no adapter stored (e.g., direct call in test)
            operationAdapters[operationId] = msg.sender; // Assume caller is adapter
        }
        // require(msg.sender == operationAdapters[operationId], "Mock: Unauthorized adapter");
        operationStatuses[operationId] = status;
        emit OperationStatusUpdated(operationId, status);
    }

    function updateReceiveStatus(
        bytes32 requestId,
        address recipient,
        BridgeTypes.OperationStatus status
    )
        external
        override
    {
        // require(msg.sender == MOCK_ADAPTER_ADDRESS, "Mock: Unauthorized adapter"); // Example check
        operationStatuses[requestId] = status;
        emit OperationStatusUpdated(requestId, status);
        if (status == BridgeTypes.OperationStatus.FAILED) {
            emit MessageDelivered(requestId, recipient, false);
        }
    }

    function notifyMessageReceived(
        bytes32 operationId,
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    )
        external
        override
    {
        // require(msg.sender == MOCK_ADAPTER_ADDRESS, "Mock: Unauthorized adapter"); // Example check
        // Emit events for tracking
        emit MessageDelivered(operationId, recipient, true);
        if (asset != address(0) && amount > 0) {
            emit TransferReceived(operationId, asset, amount, recipient, sourceChainId);
            // Simulate receiving asset from adapter
            // If testing asset flow end-to-end, adapter mock would need minting/transfer ability
        }
    }

    function deliver(
        bytes32 operationId,
        uint16 sourceChainId,
        address asset,
        uint256 amount,
        address recipient,
        bytes calldata
    )
        external
    {
        // Track the handling adapter
        operationAdapters[operationId] = msg.sender;

        // 1. Move tokens first (if any)
        if (asset != address(0) && amount > 0) {
            IERC20(asset).safeTransfer(recipient, amount);

            // Emit transfer received event
            emit TransferReceived(operationId, asset, amount, recipient, sourceChainId);
        }

        // Always emit message delivered event
        emit MessageDelivered(operationId, recipient, true);
    }

    function deliverReadResponse(bytes32 operationId, uint16, bytes calldata) external {
        // require(msg.sender == operationAdapters[operationId], "Mock: Unauthorized adapter");
        address originator = operationOriginators[operationId];
        // Simulate attempting to call originator - for tests, just update status & emit
        bool delivered = originator != address(0); // Mock success if originator exists
        if (delivered) {
            // Emit event for successful delivery
            emit ReadResponseDelivered(operationId, originator, delivered);
        } else {
            // Update status to FAILED if delivery failed
            operationStatuses[operationId] = BridgeTypes.OperationStatus.FAILED;
            emit OperationStatusUpdated(operationId, BridgeTypes.OperationStatus.FAILED);
            emit ReadResponseDelivered(operationId, originator, delivered);
        }
    }

    // --- View Functions ---
    function getOperationStatus(bytes32 operationId) external view returns (BridgeTypes.OperationStatus) {
        return operationStatuses[operationId];
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

    function setChainRouterAddress(uint16 _chainId, address _routerAddress) external override {
        chainToRouterAddress[_chainId] = _routerAddress; // Store in mock
        emit ChainRouterAddressUpdated(_chainId, _routerAddress);
    }

    function recoverFunds(address recipient, uint256 amount) external override {
        (bool s,) = payable(recipient).call{ value: amount }("");
        require(s);
        emit RouterFundsRecovered(recipient, amount);
    }

    function recoverOperationStatus(bytes32 operationId, BridgeTypes.OperationStatus status) external {
        operationStatuses[operationId] = status;
    }

    // --- Interface Support ---
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IBridgeRouter).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    // --- Receive Ether ---
    receive() external payable { }
    fallback() external payable { }

    // --- External Execute Functions (Matching IBridgeRouter) ---

    function executeTransferAssets(BridgeTypes.ExecuteTransferParams calldata params)
        external
        payable
        override
        onlyAuthorizedExecutor
        returns (bytes32 operationId)
    {
        return _executeTransferAssets(params);
    }

    function executeReadState(BridgeTypes.ExecuteReadStateParams calldata params)
        external
        payable
        override
        onlyAuthorizedExecutor
        returns (bytes32 operationId)
    {
        return _executeReadState(params);
    }

    function executeSendMessage(BridgeTypes.ExecuteSendMessageParams calldata params)
        external
        payable
        override
        onlyAuthorizedExecutor
        returns (bytes32 operationId)
    {
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
        address recipient,
        BridgeTypes.BridgeOptions calldata
    )
        external
        payable
        returns (bytes32)
    {
        if (mockPaused) revert Paused();
        if (shouldRevert) revert TransferFailed();

        // Record the call
        transferCalls.push(
            TransferCall({ destinationChainId: destinationChainId, asset: asset, amount: amount, recipient: recipient })
        );

        bytes32 operationId = nextTransferId;
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;

        emit TransferInitiated(operationId, destinationChainId, asset, amount, recipient, MOCK_ADAPTER_ADDRESS);

        emit MockTransferAssets(operationId, destinationChainId, asset, amount, recipient);

        return operationId;
    }

    // Update sendMessage to record calls
    function sendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata
    )
        external
        payable
        returns (bytes32)
    {
        if (mockPaused) revert Paused();
        if (shouldRevert) revert ReceiverRejectedCall();

        // Record the call
        messageCalls.push(
            MessageCall({ destinationChainId: destinationChainId, recipient: recipient, message: message })
        );

        bytes32 operationId = nextMessageId;
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;

        emit MessageInitiated(operationId, destinationChainId, recipient, MOCK_ADAPTER_ADDRESS);

        emit MockSendMessage(operationId, destinationChainId, recipient, message);

        return operationId;
    }

    // Add configureMock function from core contracts version
    function configureMock(
        bytes32 _nextTransferId,
        bytes32 _nextMessageId,
        bytes32 _nextReadId,
        bool _mockPaused,
        bool _shouldRevert,
        uint256 _mockFee,
        address
    )
        external
    {
        nextTransferId = _nextTransferId;
        nextMessageId = _nextMessageId;
        nextReadId = _nextReadId;
        mockPaused = _mockPaused;
        shouldRevert = _shouldRevert;
        mockFee = _mockFee;
        // Note: We don't have mockSpecifiedAdapter in this version as we use MOCK_ADAPTER_ADDRESS
    }

    // Add readState function from core contracts version
    function readState(
        uint16 destinationChainId,
        address destinationContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata
    )
        external
        payable
        returns (bytes32)
    {
        if (mockPaused) revert Paused();
        if (shouldRevert) revert ReceiverRejectedCall();

        bytes32 operationId = nextReadId;
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;

        emit ReadRequestInitiated(
            operationId, destinationChainId, destinationContract, selector, readParams, MOCK_ADAPTER_ADDRESS
        );

        return operationId;
    }

    function testSkipper() public { }

}
