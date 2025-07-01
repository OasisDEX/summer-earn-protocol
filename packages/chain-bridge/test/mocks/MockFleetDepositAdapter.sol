// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IFleetDepositAdapter} from "../../src/interfaces/IFleetDepositAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockFleetDepositAdapter
 * @notice Mock adapter for testing user-initiated fleet deposit functionality
 */
contract MockFleetDepositAdapter is IFleetDepositAdapter {
    using SafeERC20 for IERC20;

    bool public shouldRevert = false;
    bytes32 public lastOperationId;
    uint256 public lastAmount;
    address public lastAsset;
    uint16 public lastDestinationChainId;
    address public lastDestinationAdapter;
    bytes public lastComposeMessage;
    BridgeTypes.AdapterParams public lastAdapterParams;

    uint256 private operationCounter = 0; // Add counter for unique operation IDs

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function sendFleetDepositToDestinationChain(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address destinationAdapter,
        bytes memory composeMessage,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable override returns (bytes32 operationId) {
        if (shouldRevert) revert("Mock adapter reverted");

        // Generate unique operation ID using counter
        operationCounter++;
        operationId = keccak256(
            abi.encode(block.timestamp, amount, msg.sender, operationCounter)
        );

        // Transfer tokens from caller (FleetDepositManager) to this contract (adapter receives the tokens)
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Store all parameters for verification
        lastOperationId = operationId;
        lastAmount = amount;
        lastAsset = asset;
        lastDestinationChainId = destinationChainId;
        lastDestinationAdapter = destinationAdapter;
        lastComposeMessage = composeMessage;
        lastAdapterParams = adapterParams;

        return operationId;
    }

    function supportsUserInitiatedFleetDeposits()
        external
        pure
        override
        returns (bool)
    {
        return true;
    }

    /**
     * @notice Estimate fee for cross-chain operations
     * @dev Mock implementation for testing
     */
    function estimateFee(
        uint16,
        address,
        uint256,
        BridgeTypes.AdapterParams calldata,
        BridgeTypes.OperationType
    ) external pure returns (uint256 nativeFee, uint256 tokenFee) {
        return (0.01 ether, 0);
    }

    /**
     * @notice Reset the adapter state for fresh testing
     */
    function reset() external {
        shouldRevert = false;
        lastOperationId = bytes32(0);
        lastAmount = 0;
        lastAsset = address(0);
        lastDestinationChainId = 0;
        lastDestinationAdapter = address(0);
        lastComposeMessage = "";
        delete lastAdapterParams;
        // Don't reset operationCounter to maintain uniqueness across resets
    }
}
