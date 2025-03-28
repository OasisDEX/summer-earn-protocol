// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IStargateRouter} from "../../src/interfaces/IStargateRouter.sol";

contract MockStargateRouter {
    // Event to log swap calls
    event SwapCalled(
        uint16 dstChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address refundAddress,
        uint256 amount,
        uint256 amountMin,
        IStargateRouter.lzTxObj lzTxParams,
        bytes toAddress,
        bytes payload
    );

    // Mock implementation of swap
    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        IStargateRouter.lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable returns (uint256) {
        // Log the call
        emit SwapCalled(
            _dstChainId,
            _srcPoolId,
            _dstPoolId,
            _refundAddress,
            _amountLD,
            _minAmountLD,
            _lzTxParams,
            _to,
            _payload
        );

        // Return a mock value (e.g., nonce)
        return 12345;
    }

    // Mock implementation of quoteLayerZeroFee
    function quoteLayerZeroFee(
        uint16,
        uint8,
        bytes calldata,
        bytes calldata _payload,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external pure returns (uint256 _fee, uint256 _payloadSize) {
        // Return sensible mock values
        // Fee should be related to gas and payload size
        uint256 baseGasFee = 0.01 ether;
        uint256 gasComponent = _lzTxParams.dstGasForCall * 0.00000001 ether;
        uint256 payloadComponent = _payload.length * 0.0001 ether;

        return (baseGasFee + gasComponent + payloadComponent, _payload.length);
    }
}
