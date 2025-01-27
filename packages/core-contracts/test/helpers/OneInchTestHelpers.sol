// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

/**
 * @title OneInchHelpers
 * @dev A contract that provides helper functions for encoding and decoding 1inch unoswap data.
 * This contract is designed to work with 1inch's unoswap function, which allows for efficient
 * token swaps across various DEX protocols.
 */
contract OneInchTestHelpers {
    // Custom type to represent addresses as uint256 for bitwise operations
    type Address is uint256;

    // Constants for bitwise operations
    uint256 private constant _PROTOCOL_OFFSET = 253;
    uint256 private constant _WETH_UNWRAP_FLAG = 1 << 252;
    uint256 private constant _WETH_NOT_WRAP_FLAG = 1 << 251;
    uint256 private constant _USE_PERMIT2_FLAG = 1 << 250;
    uint256 private constant _LOW_160_BIT_MASK = (1 << 160) - 1;
    uint256 private constant _UNISWAP_V3_ZERO_FOR_ONE_FLAG = 1 << 247;

    /**
     * @dev Enum representing supported DEX protocols
     */
    enum Protocol {
        UniswapV2,
        UniswapV3,
        Curve
    }

    /**
     * @notice Decodes the unoswap function call data
     * @param data The encoded function call data
     * @return token The address of the token to be swapped
     * @return amount The amount of tokens to be swapped
     * @return minReturn The minimum amount of tokens to be received after the swap
     * @return dex The address of the DEX to be used for the swap
     * @return protocol The protocol to be used for the swap
     * @return shouldUnwrapWeth Whether the resulting WETH should be unwrapped to ETH
     * @return shouldWrapWeth Whether the input ETH should be wrapped to WETH
     * @return usePermit2 Whether to use Permit2 for token approvals
     */
    function decodeUnoswapData(
        bytes memory data
    )
        public
        pure
        returns (
            address token,
            uint256 amount,
            uint256 minReturn,
            address dex,
            Protocol protocol,
            bool shouldUnwrapWeth,
            bool shouldWrapWeth,
            bool usePermit2
        )
    {
        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }
        require(
            selector ==
                bytes4(keccak256("unoswap(uint256,uint256,uint256,uint256)")),
            "Invalid selector"
        );

        Address wrappedDex;
        assembly {
            token := mload(add(data, 36))
            amount := mload(add(data, 68))
            minReturn := mload(add(data, 100))
            wrappedDex := mload(add(data, 132))
        }

        uint256 encodedDex = Address.unwrap(wrappedDex);
        protocol = Protocol(encodedDex >> _PROTOCOL_OFFSET);
        shouldUnwrapWeth = (encodedDex & _WETH_UNWRAP_FLAG) != 0;
        shouldWrapWeth = (encodedDex & _WETH_NOT_WRAP_FLAG) == 0;
        usePermit2 = (encodedDex & _USE_PERMIT2_FLAG) != 0;

        // Clear the protocol and flag bits from the dex address
        dex = address(uint160(Address.unwrap(wrappedDex) & _LOW_160_BIT_MASK));

        // Log decoded data for debugging purposes
        console.log("Token:", token);
        console.log("Amount:", amount);
        console.log("Min Return:", minReturn);
        console.log("DEX:", dex);
        console.log("Protocol:", uint256(protocol));
        console.log("Should Unwrap WETH:", shouldUnwrapWeth);
        console.log("Should Wrap WETH:", shouldWrapWeth);
        console.log("Use Permit2:", usePermit2);
    }

    /**
     * @notice Encodes the parameters for a unoswap function call
     * @param token The address of the token to be swapped
     * @param amount The amount of tokens to be swapped
     * @param minReturn The minimum amount of tokens to be received after the swap
     * @param dex The address of the DEX to be used for the swap
     * @param protocol The protocol to be used for the swap
     * @param shouldUnwrapWeth Whether the resulting WETH should be unwrapped to ETH
     * @param shouldWrapWeth Whether the input ETH should be wrapped to WETH
     * @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
     * @param usePermit2 Whether to use Permit2 for token approvals
     * @return The encoded function call data for the unoswap function
     */
    function encodeUnoswapData(
        address token,
        uint256 amount,
        uint256 minReturn,
        address dex,
        Protocol protocol,
        bool shouldUnwrapWeth,
        bool shouldWrapWeth,
        bool zeroForOne,
        bool usePermit2
    ) public pure returns (bytes memory) {
        uint256 encodedDex = uint256(uint160(dex));

        // Set protocol
        encodedDex |= uint256(protocol) << _PROTOCOL_OFFSET;

        // Set flags
        if (shouldUnwrapWeth) {
            encodedDex |= _WETH_UNWRAP_FLAG;
        }
        if (!shouldWrapWeth) {
            encodedDex |= _WETH_NOT_WRAP_FLAG;
        }
        if (usePermit2) {
            encodedDex |= _USE_PERMIT2_FLAG;
        }
        if (zeroForOne) {
            encodedDex |= _UNISWAP_V3_ZERO_FOR_ONE_FLAG;
        }
        return
            abi.encodeWithSelector(
                bytes4(keccak256("unoswap(uint256,uint256,uint256,uint256)")),
                uint256(uint160(token)),
                amount,
                minReturn,
                encodedDex
            );
    }

    function testSkip() public pure {}
}
