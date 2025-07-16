// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title IStargateRouter
 * @notice Interface for Stargate Protocol's Router, used for cross-chain token transfers
 * @dev Based on the mainnet deployment at 0x8731d54E9D02c286767d56ac03e8037C07e01e98
 */
interface IStargateRouter {
    /**
     * @notice Parameters for LayerZero transactions
     * @param dstGasForCall Gas to use for the function call on destination
     * @param dstNativeAmount Amount of native asset to send to destination recipient
     * @param dstNativeAddr Address on destination to receive native tokens
     */
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    /**
     * @notice Swap tokens from source chain to destination chain
     * @param _dstChainId Stargate chain ID of the destination chain
     * @param _srcPoolId Source Stargate pool ID
     * @param _dstPoolId Destination Stargate pool ID
     * @param _refundAddress Address to refund excess fees to
     * @param _amountLD Amount of tokens to swap in local decimals
     * @param _minAmountLD Minimum amount to receive on destination in local decimals
     * @param _lzTxParams LayerZero transaction parameters
     * @param _to Address bytes on destination to receive tokens
     * @param _payload Additional payload to send to destination
     */
    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    /**
     * @notice Quote the LayerZero fee for a Stargate operation
     * @param _dstChainId Stargate chain ID of the destination chain
     * @param _functionType Function type (1 for swap)
     * @param _toAddress Recipient address bytes on destination
     * @param _transferAndCallPayload Payload for the transfer
     * @param _lzTxParams LayerZero transaction parameters
     * @return nativeFee Native token fee
     * @return zroFee ZRO token fee (usually 0)
     */
    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256 nativeFee, uint256 zroFee);

    /**
     * @notice Add liquidity to a Stargate pool
     * @param _poolId Pool ID to add liquidity to
     * @param _amountLD Amount to add in local decimals
     * @param _to Address to receive LP tokens
     */
    function addLiquidity(
        uint256 _poolId,
        uint256 _amountLD,
        address _to
    ) external;

    /**
     * @notice Instantly redeem LP tokens for underlying tokens locally
     * @param _srcPoolId Source pool ID
     * @param _amountLP Amount of LP tokens to redeem
     * @param _to Address to receive underlying tokens
     * @return amountSD Amount of underlying tokens received in shared decimals
     */
    function instantRedeemLocal(
        uint16 _srcPoolId,
        uint256 _amountLP,
        address _to
    ) external returns (uint256 amountSD);

    /**
     * @notice Redeem LP tokens remotely (cross-chain)
     * @param _dstChainId Destination chain ID
     * @param _srcPoolId Source pool ID
     * @param _dstPoolId Destination pool ID
     * @param _refundAddress Address to refund excess fees
     * @param _amountLP Amount of LP tokens to redeem
     * @param _minAmountLD Minimum amount to receive in local decimals
     * @param _lzTxParams LayerZero transaction parameters
     * @param _to Recipient address bytes
     * @param _payload Additional payload
     */
    function redeemRemote(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    /**
     * @notice Create a new Stargate pool
     * @param _poolId Pool ID to create
     * @param _token Token address for the pool
     * @param _sharedDecimals Number of shared decimals
     * @param _localDecimals Number of local decimals
     * @param _name Pool name
     * @param _symbol Pool symbol
     * @param _router Router address
     */
    function createPool(
        uint256 _poolId,
        address _token,
        uint8 _sharedDecimals,
        uint8 _localDecimals,
        string calldata _name,
        string calldata _symbol,
        address _router
    ) external;

    /**
     * @notice Send tokens that were accidentally sent to the router
     * @param _token Token address
     * @param _amount Amount to send
     * @param _to Recipient address
     */
    function sendToken(address _token, uint256 _amount, address _to) external;

    /**
     * @notice Get the local Stargate pool address for a pool ID
     * @param _poolId Pool ID
     * @return Pool address
     */
    function getPool(uint256 _poolId) external view returns (address);
}
