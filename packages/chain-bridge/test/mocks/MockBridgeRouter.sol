// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol"; // Using Test contract for cheatcodes like makeAddr if needed
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

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

    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatuses;
    mapping(bytes32 => address) public operationOriginators; // Track who requested via queue
    mapping(bytes32 => address) public operationAdapters;
    mapping(bytes32 => uint256) public operationBaseFeesPaid; // Track fee forwarded by queue

    uint256 internal operationNonce; // To generate unique mock operation IDs

    // Add mapping for chain to router addresses if not already present
    mapping(uint16 => address) public chainToRouterAddress;

    uint64 public DEFAULT_GAS_LIMIT = 200000; // Default value matching the real implementation

    // Mock-specific event
    event BridgeQueueAddressSet(address bridgeQueue); // Mock specific event

    // --- Errors ---
    error CallerNotBridgeQueue();
    error RefundFailed();

    // --- Modifiers ---
    modifier onlyBridgeQueue() {
        if (msg.sender != mockBridgeQueueAddress) {
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

    function setMockOperationStatus(
        bytes32 _operationId,
        BridgeTypes.OperationStatus _status
    ) external {
        operationStatuses[_operationId] = _status;
        emit OperationStatusUpdated(_operationId, _status); // Simulate update
    }

    // --- IBridgeRouter Implementation ---

    // --- Main Functions ---

    function quote(
        uint16 /* destinationChainId */,
        address /* asset */,
        uint256 /* amount */,
        BridgeTypes.BridgeOptions calldata /* options */,
        BridgeTypes.OperationType /* operationType */
    )
        external
        pure
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
    {
        // Return base fees (without multiplier)
        uint256 mockBaseNativeFee = 0.1 ether; // Example base fee
        uint256 mockBaseTokenFee = 0; // Example base token fee
        nativeFee = mockBaseNativeFee; // Return base fee, not total
        tokenFee = mockBaseTokenFee;
        selectedAdapter = MOCK_ADAPTER_ADDRESS;
        return (nativeFee, tokenFee, selectedAdapter);
    }

    // --- Internal Execution Functions (Helper for external calls) ---
    // Updated to accept the struct, although called by the external funcs below

    function _executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal returns (bytes32 operationId) {
        if (shouldRevert) {
            revert("MockRouter: Execution failed");
        }

        operationId = keccak256(abi.encodePacked("transfer", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS; // Simulate adapter selection
        operationBaseFeesPaid[operationId] = msg.value; // Track base fee received

        // Simulate token transfer from queue (already approved)
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        ); // Pull from queue
        // Keep tokens in the router for testing purposes
        // In a real scenario, this would transfer to the adapter or burn/lock

        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.recipient,
            MOCK_ADAPTER_ADDRESS
        );
        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.PENDING
        );

        // Refund any excess native fee to the keeper
        uint256 baseFee = 0.1 ether; // Base fee from quote
        if (msg.value > baseFee) {
            (bool success, ) = msg.sender.call{value: msg.value - baseFee}("");
            if (!success) revert RefundFailed();
        }

        return operationId;
    }

    function _executeReadState(
        BridgeTypes.ExecuteReadStateParams calldata params
    ) internal returns (bytes32 operationId) {
        operationId = keccak256(abi.encodePacked("read", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;
        operationBaseFeesPaid[operationId] = msg.value;

        emit ReadRequestInitiated(
            operationId,
            params.dstChainId,
            params.dstContract,
            params.selector,
            params.readParams,
            MOCK_ADAPTER_ADDRESS
        );
        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.PENDING
        );

        return operationId;
    }

    function _executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params
    ) internal returns (bytes32 operationId) {
        operationId = keccak256(abi.encodePacked("message", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationOriginators[operationId] = params.originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;
        operationBaseFeesPaid[operationId] = msg.value;

        emit MessageInitiated(
            operationId,
            params.destinationChainId,
            params.recipient,
            MOCK_ADAPTER_ADDRESS
        );
        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.PENDING
        );

        return operationId;
    }

    // --- Adapter Callbacks ---
    // These are simplified, just updating status. Real adapters would call these.
    function updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external override {
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
    ) external override {
        // require(msg.sender == MOCK_ADAPTER_ADDRESS, "Mock: Unauthorized adapter"); // Example check
        operationStatuses[requestId] = status;
        emit OperationStatusUpdated(requestId, status);
        if (status == BridgeTypes.OperationStatus.DELIVERED) {
            emit MessageDelivered(requestId, recipient, true);
        } else if (status == BridgeTypes.OperationStatus.FAILED) {
            emit MessageDelivered(requestId, recipient, false);
        }
    }

    function notifyMessageReceived(
        bytes32 operationId,
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    ) external override {
        // require(msg.sender == MOCK_ADAPTER_ADDRESS, "Mock: Unauthorized adapter"); // Example check
        operationStatuses[operationId] = BridgeTypes.OperationStatus.DELIVERED; // Simulate initial delivered status
        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );
        emit MessageDelivered(operationId, recipient, true);
        if (asset != address(0) && amount > 0) {
            emit TransferReceived(
                operationId,
                asset,
                amount,
                recipient,
                sourceChainId
            );
            // Simulate receiving asset from adapter
            // If testing asset flow end-to-end, adapter mock would need minting/transfer ability
        }
        // Simulate trying to send confirmation back (can be mocked further if needed)
    }

    function deliverReadResponse(
        bytes32 operationId,
        bytes calldata
    ) external override {
        // require(msg.sender == operationAdapters[operationId], "Mock: Unauthorized adapter");
        address originator = operationOriginators[operationId];
        // Simulate attempting to call originator - for tests, just update status & emit
        bool delivered = originator != address(0); // Mock success if originator exists
        if (delivered) {
            operationStatuses[operationId] = BridgeTypes
                .OperationStatus
                .COMPLETED;
            emit OperationStatusUpdated(
                operationId,
                BridgeTypes.OperationStatus.COMPLETED
            );
        } else {
            operationStatuses[operationId] = BridgeTypes.OperationStatus.FAILED;
            emit OperationStatusUpdated(
                operationId,
                BridgeTypes.OperationStatus.FAILED
            );
        }
        emit ReadResponseDelivered(operationId, originator, delivered);
    }

    function receiveConfirmation(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external override {
        // require(msg.sender == MOCK_ADAPTER_ADDRESS, "Mock: Unauthorized adapter"); // Example check
        // Simulate basic status progression check
        if (
            status > operationStatuses[operationId] &&
            operationStatuses[operationId] != BridgeTypes.OperationStatus.FAILED
        ) {
            operationStatuses[operationId] = status;
            emit OperationStatusUpdated(operationId, status);
        }
    }

    // --- View Functions ---
    function getOperationStatus(
        bytes32 operationId
    ) external view returns (BridgeTypes.OperationStatus) {
        return operationStatuses[operationId];
    }

    // Implement other view functions simply returning mock/default values
    function getBestAdapter(
        uint16,
        address,
        uint256
    ) external pure returns (address bestAdapter) {
        return MOCK_ADAPTER_ADDRESS;
    }

    function getBestAdapter(
        uint16,
        address,
        uint256,
        BridgeTypes.OperationType
    ) external pure returns (address bestAdapter) {
        return MOCK_ADAPTER_ADDRESS;
    }

    function getBestAdapterForStateRead(
        uint16
    ) external pure returns (address) {
        return MOCK_ADAPTER_ADDRESS;
    }

    function getAdapters() external pure returns (address[] memory) {
        address[] memory adapters = new address[](1);
        adapters[0] = MOCK_ADAPTER_ADDRESS;
        return adapters;
    }

    function isValidAdapter(address adapter) external pure returns (bool) {
        return adapter == MOCK_ADAPTER_ADDRESS;
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
    function registerAdapter(address adapter) external override {
        emit AdapterRegistered(adapter);
    }

    function removeAdapter(address adapter) external override {
        emit AdapterRemoved(adapter);
    }

    function pause() external override {
        /* No-op in mock */
    }

    function unpause() external override {
        /* No-op in mock */
    }

    // Renamed function
    function setDefaultGasLimit(uint256 _limit) external override {
        DEFAULT_GAS_LIMIT = uint64(_limit); // Update mock state
        emit DefaultGasLimitUpdated(_limit);
    }

    function setChainRouterAddress(
        uint16 _chainId,
        address _routerAddress
    ) external override {
        chainToRouterAddress[_chainId] = _routerAddress; // Store in mock
        emit ChainRouterAddressUpdated(_chainId, _routerAddress);
    }

    function recoverFunds(address recipient, uint256 amount) external override {
        (bool s, ) = payable(recipient).call{value: amount}("");
        require(s);
        emit RouterFundsRemoved(recipient, amount);
    }

    function recoverOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external {
        operationStatuses[operationId] = status;
    }

    // Using the interface methods only - remove the duplicate
    function setBridgeQueueAddress(address _bridgeQueue) external {
        mockBridgeQueueAddress = _bridgeQueue;
        emit BridgeQueueAddressSet(_bridgeQueue);
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
        BridgeTypes.ExecuteTransferParams calldata params
    ) external payable override onlyBridgeQueue returns (bytes32 operationId) {
        return _executeTransferAssets(params);
    }

    function executeReadState(
        BridgeTypes.ExecuteReadStateParams calldata params
    ) external payable override onlyBridgeQueue returns (bytes32 operationId) {
        return _executeReadState(params);
    }

    function executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params
    ) external payable override onlyBridgeQueue returns (bytes32 operationId) {
        return _executeSendMessage(params);
    }
}
