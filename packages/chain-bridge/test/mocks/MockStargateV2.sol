// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/**
 * @title MockStargateV2
 * @notice Mock implementation of Stargate V2 interface for testing
 */
contract MockStargateV2 {
    enum StargateType {
        Pool,
        OFT
    }

    struct Ticket {
        uint56 ticketId;
        bytes passenger;
    }

    address public immutable token;
    StargateType public immutable stargateType;

    constructor(address _token, StargateType _stargateType) {
        token = _token;
        stargateType = _stargateType;
    }

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address
    )
        external
        payable
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt,
            Ticket memory ticket
        )
    {
        // Mock implementation - just return mock structs
        msgReceipt = MessagingReceipt({
            guid: bytes32(uint256(1)),
            nonce: 1,
            fee: _fee
        });

        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.amountLD
        });

        ticket = Ticket({ticketId: 1, passenger: ""});
    }

    function quoteSend(
        SendParam calldata,
        bool
    ) external pure returns (MessagingFee memory msgFee) {
        // Return a mock fee
        msgFee = MessagingFee({nativeFee: 0.01 ether, lzTokenFee: 0});
    }

    function quoteOFT(
        SendParam calldata _sendParam
    )
        external
        pure
        returns (uint256 limit, uint256 oftLimit, OFTReceipt memory oftReceipt)
    {
        // Mock implementation
        limit = _sendParam.amountLD;
        oftLimit = _sendParam.amountLD;
        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.amountLD
        });
    }
}
