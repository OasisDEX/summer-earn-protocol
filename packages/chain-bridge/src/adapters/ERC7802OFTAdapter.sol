// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseERC7802Adapter} from "./BaseERC7802Adapter.sol";

/**
 * @title ERC7802OFTAdapter
 * @notice ERC-7802 adapter using direct LayerZero OFT protocol
 * @dev For tokens like USDT0 that implement LayerZero OFT natively
 */
contract ERC7802OFTAdapter is BaseERC7802Adapter {
    using SafeERC20 for IERC20;
    using AddressCast for address;

    /// @notice OFT contract address per token on THIS chain
    mapping(address token => address oft) public oftForToken;

    event OftSet(address indexed token, address indexed oft);

    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint
    ) BaseERC7802Adapter(_crossChainRegistry, _accessManager, _lzEndpoint) {}

    /**
     * @notice Set the OFT contract address for a token
     * @param token The ERC20 token address
     * @param oft The LayerZero OFT contract address for this token
     */
    function setOftForToken(address token, address oft) external onlyGovernor {
        if (token == address(0) || oft == address(0)) revert InvalidParams();
        // Validate that the OFT contract is properly configured for this token
        try IOFT(oft).token() returns (address t) {
            if (t != token) revert InvalidParams();
        } catch {
            revert InvalidParams();
        }
        oftForToken[token] = oft;
        emit OftSet(token, oft);
    }

    /**
     * @dev Direct LayerZero OFT transfer implementation with optional compose support
     */
    function _sendTransport(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.ExecuteTransferParams calldata params,
        address refundAddress
    ) internal payable override returns (uint256 feeUsed) {
        address oft = oftForToken[token];
        if (oft == address(0)) revert UnsupportedAsset();

        // Approve the OFT contract to spend tokens
        IERC20(token).forceApprove(oft, amount);

        // Encode compose message if message is provided
        bytes memory composeMsg = bytes("");
        if (params.message.length > 0) {
            composeMsg = _encodeComposeTransferParams(operationId, params);
        }

        SendParam memory sendParam = SendParam({
            dstEid: uint32(_externalOrCanonical(dstChainId)),
            to: dstAdapter.toBytes32(),
            amountLD: amount,
            minAmountLD: amount, // Require exact amount (no slippage for stablecoins)
            extraOptions: bytes(""),
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        if (msg.value < fee.nativeFee) {
            revert InsufficientFee(fee.nativeFee, msg.value);
        }

        IOFT(oft).send{value: fee.nativeFee}(sendParam, fee, refundAddress);
        return fee.nativeFee;
    }

    /**
     * @dev Estimate LayerZero OFT fees with compose message support
     */
    function _estimateTransport(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal view override returns (uint256 nativeFee, uint256 tokenFee) {
        address oft = oftForToken[token];
        if (oft == address(0)) revert UnsupportedAsset();

        // Encode compose message if message is provided
        bytes memory composeMsg = bytes("");
        if (params.message.length > 0) {
            composeMsg = _encodeComposeTransferParams(operationId, params);
        }

        SendParam memory sendParam = SendParam({
            dstEid: uint32(_externalOrCanonical(dstChainId)),
            to: dstAdapter.toBytes32(),
            amountLD: amount,
            minAmountLD: amount, // Require exact amount (no slippage for stablecoins)
            extraOptions: bytes(""),
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        return (fee.nativeFee, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        MESSAGE ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Read state from a contract on a source chain (not supported by OFT adapter)
    function readState(
        bytes32,
        BridgeTypes.ExecuteReadStateParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @notice Send a message to a destination chain (not supported by OFT adapter)
    function sendMessage(
        bytes32,
        BridgeTypes.ExecuteSendMessageParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @notice Check if the adapter supports a specific message operation type
    function supportsMessageOperation(
        uint16,
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }
}
