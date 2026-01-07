// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISuperchainTokenBridge} from "../../src/interfaces/ISuperchainTokenBridge.sol";

/**
 * @title MockSuperchainTokenBridge
 * @notice Mock implementation of ISuperchainTokenBridge for testing
 */
contract MockSuperchainTokenBridge is ISuperchainTokenBridge {
    event ERC20Sent(
        address indexed token,
        uint32 indexed destinationChainId,
        address indexed recipient,
        uint256 amount
    );

    function sendERC20(
        address token,
        uint256 dstChainId,
        address to,
        uint256 amount
    ) external {
        emit ERC20Sent(token, uint32(dstChainId), to, amount);
    }
}
