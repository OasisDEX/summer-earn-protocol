// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title IStargateReceiver
 * @notice Interface for receiving cross-chain messages through Stargate
 */
interface IStargateReceiver {
    /**
     * @notice Called by Stargate router when tokens are received from another chain
     * @param _chainId Source chain ID in Stargate format
     * @param _srcAddress Source address as bytes
     * @param _nonce Stargate nonce
     * @param _token Address of the token being transferred
     * @param _amount Amount of tokens received
     * @param _payload ABI encoded payload sent from source chain
     */
    function sgReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _token,
        uint256 _amount,
        bytes memory _payload
    ) external;
}
