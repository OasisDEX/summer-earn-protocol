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

    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatuses;
    mapping(bytes32 => address) public operationOriginators; // Track who requested via queue
    mapping(bytes32 => address) public operationAdapters;
    mapping(bytes32 => uint256) public operationBaseFeesPaid; // Track fee forwarded by queue

    uint256 internal operationNonce; // To generate unique mock operation IDs

    // Add mapping for chain to router addresses if not already present
    mapping(uint16 => address) public chainToRouterAddress;

    // Add storage variable for confirmation gas limit if not already present
    uint64 public confirmationGasLimit = 200000; // Default value matching the real implementation

    // Mock-specific event
    event BridgeQueueAddressSet(address bridgeQueue); // Mock specific event

    // --- Errors ---
    error CallerNotBridgeQueue();

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
        view
        override
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
    {
        // Return pre-configured total fees based on the multiplier
        // For simplicity, let's assume a base fee and calculate total
        uint256 mockBaseNativeFee = 0.1 ether; // Example base fee
        uint256 mockBaseTokenFee = 0; // Example base token fee
        nativeFee = (mockBaseNativeFee * mockFeeMultiplier) / 100;
        tokenFee = (mockBaseTokenFee * mockFeeMultiplier) / 100;
        selectedAdapter = MOCK_ADAPTER_ADDRESS;
        // We could add logic here to return different fees based on input if needed for tests
        return (nativeFee, tokenFee, selectedAdapter);
    }

    // --- Internal Execution Functions (Called by BridgeQueue) ---

    function _executeTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        address originator,
        BridgeTypes.BridgeOptions calldata /* options */
    ) internal returns (bytes32 operationId) {
        operationId = keccak256(abi.encodePacked("transfer", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationOriginators[operationId] = originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS; // Simulate adapter selection
        operationBaseFeesPaid[operationId] = msg.value; // Track base fee received

        // Simulate token transfer from queue (already approved)
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount); // Pull from queue
        // In a real scenario, this might transfer to the adapter or burn/lock
        // For mock, just holding it is fine, or transfer to a dummy address
        IERC20(asset).safeTransfer(makeAddr("mock_adapter_vault"), amount);

        emit TransferInitiated(
            operationId,
            destinationChainId,
            asset,
            amount,
            recipient,
            MOCK_ADAPTER_ADDRESS
        );
        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.PENDING
        );

        return operationId;
    }

    function _executeReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.BridgeOptions calldata /* options */
    ) internal returns (bytes32 operationId) {
        operationId = keccak256(abi.encodePacked("read", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationOriginators[operationId] = originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;
        operationBaseFeesPaid[operationId] = msg.value;

        emit ReadRequestInitiated(
            operationId,
            dstChainId,
            dstContract,
            selector,
            readParams,
            MOCK_ADAPTER_ADDRESS
        );
        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.PENDING
        );

        return operationId;
    }

    function _executeSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata /* message */,
        address originator,
        BridgeTypes.BridgeOptions calldata /* options */
    ) internal returns (bytes32 operationId) {
        operationId = keccak256(abi.encodePacked("message", operationNonce++));
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationOriginators[operationId] = originator;
        operationAdapters[operationId] = MOCK_ADAPTER_ADDRESS;
        operationBaseFeesPaid[operationId] = msg.value;

        emit MessageInitiated(
            operationId,
            destinationChainId,
            recipient,
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
        bytes calldata resultData
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
    ) external view returns (address bestAdapter) {
        return MOCK_ADAPTER_ADDRESS;
    }

    function getBestAdapter(
        uint16,
        address,
        uint256,
        BridgeTypes.OperationType
    ) external view returns (address bestAdapter) {
        return MOCK_ADAPTER_ADDRESS;
    }

    function getBestAdapterForStateRead(
        uint16
    ) external view returns (address) {
        return MOCK_ADAPTER_ADDRESS;
    }

    function getAdapters() external view returns (address[] memory) {
        address[] memory adapters = new address[](1);
        adapters[0] = MOCK_ADAPTER_ADDRESS;
        return adapters;
    }

    function isValidAdapter(address adapter) external view returns (bool) {
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

    function setConfirmationGasLimit(uint64 _limit) external override {
        emit ConfirmationGasLimitUpdated(_limit);
    }

    function setChainRouterAddress(
        uint16 _chainId,
        address _routerAddress
    ) external override {
        emit ChainRouterAddressUpdated(_chainId, _routerAddress);
    }

    function removeRouterFunds(
        address recipient,
        uint256 amount
    ) external override {
        (bool s, ) = payable(recipient).call{value: amount}("");
        require(s);
        emit RouterFundsRemoved(recipient, amount);
    }

    function addRouterFunds() external payable override {
        emit RouterFundsAdded(msg.sender, msg.value);
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

    // --- Deprecated User Functions ---
    // Revert or implement basic mock behavior if needed for specific tests
    function transferAssets(
        uint16,
        address,
        uint256,
        address,
        BridgeTypes.BridgeOptions calldata
    ) external payable override returns (bytes32) {
        revert("Mock: Deprecated");
    }

    function readState(
        uint16,
        address,
        bytes4,
        bytes calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable override returns (bytes32) {
        revert("Mock: Deprecated");
    }

    function sendMessage(
        uint16,
        address,
        bytes calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable override returns (bytes32) {
        revert("Mock: Deprecated");
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

    function executeTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyBridgeQueue returns (bytes32 operationId) {
        return
            _executeTransferAssets(
                destinationChainId,
                asset,
                amount,
                recipient,
                originator,
                options
            );
    }

    function executeReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyBridgeQueue returns (bytes32 operationId) {
        return
            _executeReadState(
                dstChainId,
                dstContract,
                selector,
                readParams,
                originator,
                options
            );
    }

    function executeSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyBridgeQueue returns (bytes32 operationId) {
        return
            _executeSendMessage(
                destinationChainId,
                recipient,
                message,
                originator,
                options
            );
    }
}
