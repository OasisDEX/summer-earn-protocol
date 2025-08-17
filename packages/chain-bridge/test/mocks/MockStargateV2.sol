// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MessagingFee, MessagingReceipt, OFTFeeDetail, OFTLimit, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStargateV2} from "../../src/interfaces/IStargateV2.sol";

/**
 * @title MockStargateV2
 * @notice Mock implementation of Stargate V2 interface for testing
 */
contract MockStargateV2Pool is IStargateV2 {
    using SafeERC20 for IERC20;

    address public immutable TOKEN;

    // Compose message tracking
    bytes public expectedComposeMsg;
    bool public composeMsgWasSet;
    bytes public lastComposeMsg;

    uint256 public mockAmountReceived;

    constructor(address _token) {
        TOKEN = _token;
    }

    function stargateType() external pure returns (StargateType) {
        return StargateType.Pool;
    }

    function token() external view returns (address) {
        return TOKEN;
    }

    function setExpectedComposeMsg(bytes memory _composeMsg) external {
        expectedComposeMsg = _composeMsg;
    }

    function setMockQuoteResponse(uint256 amountReceivedLD) external {
        mockAmountReceived = amountReceivedLD;
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
        // Transfer tokens from sender to this contract (simulating real Stargate behavior)
        IERC20(TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            _sendParam.amountLD
        );

        // Store the compose message for verification
        if (_sendParam.composeMsg.length > 0) {
            lastComposeMsg = _sendParam.composeMsg;
            composeMsgWasSet = true;

            // Check if compose message matches expected (if set)
            if (expectedComposeMsg.length > 0) {
                require(
                    keccak256(_sendParam.composeMsg) ==
                        keccak256(expectedComposeMsg),
                    "Compose message mismatch"
                );
            }
        }

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

    /// forge-lint: disable-next-item(mixed-case-function)
    function quoteOFT(
        SendParam calldata _sendParam
    )
        external
        pure
        returns (
            OFTLimit memory limit,
            OFTFeeDetail[] memory oftFeeDetails,
            OFTReceipt memory oftReceipt
        )
    {
        // Mock implementation with correct return types
        limit = OFTLimit({minAmountLD: 1, maxAmountLD: type(uint256).max});

        oftFeeDetails = new OFTFeeDetail[](1);
        oftFeeDetails[0] = OFTFeeDetail({
            feeAmountLD: -501, // Mock protocol fee (negative means fee)
            description: "protocol fee"
        });

        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.amountLD // In real scenario, this would be less due to fees
        });
    }

    function testSkipper() public {}
}

contract MockStargateV2OFT is IStargateV2 {
    using SafeERC20 for IERC20;

    address public immutable TOKEN;

    // Compose message tracking
    bytes public expectedComposeMsg;
    bool public composeMsgWasSet;
    bytes public lastComposeMsg;

    constructor(address _token) {
        TOKEN = _token;
    }

    function stargateType() external pure returns (StargateType) {
        return StargateType.OFT;
    }

    function token() external view returns (address) {
        return TOKEN;
    }

    function setExpectedComposeMsg(bytes memory _composeMsg) external {
        expectedComposeMsg = _composeMsg;
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
        // Transfer tokens from sender to this contract (simulating real Stargate behavior)
        IERC20(TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            _sendParam.amountLD
        );

        // Store the compose message for verification
        if (_sendParam.composeMsg.length > 0) {
            lastComposeMsg = _sendParam.composeMsg;
            composeMsgWasSet = true;

            // Check if compose message matches expected (if set)
            if (expectedComposeMsg.length > 0) {
                require(
                    keccak256(_sendParam.composeMsg) ==
                        keccak256(expectedComposeMsg),
                    "Compose message mismatch"
                );
            }
        }

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

    /// forge-lint: disable-next-item(mixed-case-function)
    function quoteOFT(
        SendParam calldata _sendParam
    )
        external
        pure
        returns (
            OFTLimit memory limit,
            OFTFeeDetail[] memory oftFeeDetails,
            OFTReceipt memory oftReceipt
        )
    {
        // Mock implementation with correct return types
        limit = OFTLimit({minAmountLD: 1, maxAmountLD: type(uint256).max});

        oftFeeDetails = new OFTFeeDetail[](1);
        oftFeeDetails[0] = OFTFeeDetail({
            feeAmountLD: -501, // Mock protocol fee (negative means fee)
            description: "protocol fee"
        });

        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.amountLD // In real scenario, this would be less due to fees
        });
    }

    function testSkipper() public {}
}
