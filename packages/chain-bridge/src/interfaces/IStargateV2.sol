// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MessagingFee, MessagingReceipt, OFTFeeDetail, OFTLimit, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/**
 * @title IStargateV2
 * @notice Interface for Stargate V2 Protocol
 * @dev Based on LayerZero V2 OFT standard with Stargate extensions
 */
interface IStargateV2 {
    enum StargateType {
        Pool,
        OFT
    }

    struct Ticket {
        uint56 ticketId;
        bytes passenger;
    }

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

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee);

    /// forge-lint: disable-next-item(mixed-case-function)
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

    function stargateType() external pure returns (StargateType);

    function token() external view returns (address);
}
