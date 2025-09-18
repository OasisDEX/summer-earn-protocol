// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

import {IStargateV2} from "../interfaces/IStargateV2.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseERC7802Adapter} from "./BaseERC7802Adapter.sol";

/**
 * @title ERC7802OFTAdapter
 * @notice ERC-7802 adapter using Stargate V2 (OFT-enabled) transport
 */
contract ERC7802OFTAdapter is BaseERC7802Adapter {
    using SafeERC20 for IERC20;
    using AddressCast for address;

    /// @notice token => Stargate V2 pool contract on THIS chain
    mapping(address token => address pool) public oftPoolForToken;

    event OftPoolSet(address indexed token, address indexed pool);

    constructor(
        address _crossChainRegistry,
        address _accessManager
    ) BaseERC7802Adapter(_crossChainRegistry, _accessManager) {}

    function setOftPool(address token, address pool) external onlyGovernor {
        if (token == address(0) || pool == address(0)) revert InvalidParams();
        // Validate pool belongs to token
        try IStargateV2(pool).token() returns (address t) {
            if (t != token) revert InvalidParams();
        } catch {
            revert InvalidParams();
        }
        oftPoolForToken[token] = pool;
        emit OftPoolSet(token, pool);
    }

    function _send7802(
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata,
        address refundAddress
    ) internal payable override returns (uint256 feeUsed) {
        address pool = oftPoolForToken[token];
        if (pool == address(0)) revert UnsupportedAsset();

        IERC20(token).forceApprove(pool, amount);

        SendParam memory p = SendParam({
            dstEid: uint32(_externalOrCanonical(dstChainId)),
            to: dstAdapter.toBytes32(),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        MessagingFee memory q = IStargateV2(pool).quoteSend(p, false);
        if (msg.value < q.nativeFee)
            revert InsufficientFee(q.nativeFee, msg.value);

        IStargateV2(pool).sendToken{value: q.nativeFee}(p, q, refundAddress);
        return q.nativeFee;
    }

    function _estimate7802(
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata
    ) internal view override returns (uint256 nativeFee, uint256 tokenFee) {
        address pool = oftPoolForToken[token];
        if (pool == address(0)) revert UnsupportedAsset();

        SendParam memory p = SendParam({
            dstEid: uint32(_externalOrCanonical(dstChainId)),
            to: dstAdapter.toBytes32(),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory q = IStargateV2(pool).quoteSend(p, false);
        return (q.nativeFee, 0);
    }
}
