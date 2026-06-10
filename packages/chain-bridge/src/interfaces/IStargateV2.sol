// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MessagingFee, MessagingReceipt, OFTFeeDetail, OFTLimit, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/**
 * @title IStargateV2
 * @notice Interface for Stargate V2 Protocol
 * @dev Based on LayerZero V2 OFT standard with Stargate extensions
 */
interface IStargateV2 {
    /// @notice Type of Stargate endpoint (Pool or OFT)
    enum StargateType {
        Pool,
        OFT
    }

    /// @notice Ticket structure representing cross-chain transfer details
    struct Ticket {
        uint56 ticketId;
        bytes passenger;
    }

    /**
     * @notice Send tokens cross-chain via Stargate V2
     * @param _sendParam Struct containing parameters for the send operation
     * @param _fee The LayerZero messaging fee
     * @param _refundAddress The address to receive any gas refunds
     * @return msgReceipt The message receipt
     * @return oftReceipt The OFT receipt
     * @return ticket The transit ticket details
     */
    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt,
            Ticket memory ticket
        );

    /**
     * @notice Estimate the messaging fee for sending tokens cross-chain
     * @param _sendParam Struct containing parameters for the send operation
     * @param _payInLzToken True if paying in LZ token, false for native gas token
     * @return msgFee The messaging fee quote
     */
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee);

    /**
     * @notice Query the OFT limits and estimated fees for a send operation
     * @param _sendParam Struct containing parameters for the send operation, including destination
     *        chain, recipient, amount to send, and minimum amount to receive
     * @return limit The OFT transfer limit details (min/max sendable amounts)
     * @return oftFeeDetails Detailed fee breakdown for the OFT transfer
     * @return oftReceipt Predicted receipt details including amount sent and amount received
     */
    // forge-lint: disable-next-item(mixed-case-function)
    function quoteOFT(
        SendParam calldata _sendParam
    )
        external
        view
        returns (
            OFTLimit memory limit,
            OFTFeeDetail[] memory oftFeeDetails,
            OFTReceipt memory oftReceipt
        );

    /**
     * @notice Returns the Stargate type of this endpoint
     * @return The StargateType (Pool or OFT)
     */
    function stargateType() external pure returns (StargateType);

    /**
     * @notice Returns the address of the underlying token managed by this Stargate contract
     * @return The token address
     */
    function token() external view returns (address);
}
