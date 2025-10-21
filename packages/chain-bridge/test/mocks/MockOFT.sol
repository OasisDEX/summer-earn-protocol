// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MessagingFee, SendParam, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/**
 * @title MockOFT
 * @notice Mock implementation of LayerZero OFT for testing
 */
contract MockOFT {
    using SafeERC20 for IERC20;

    address public immutable UNDERLYING_TOKEN;
    address public owner;
    uint256 public quoteSendNativeFee = 0.1 ether;
    uint256 public quoteSendTokenFee = 0;

    mapping(address => bool) public approvedSpenders;

    constructor(address _token) {
        UNDERLYING_TOKEN = _token;
        owner = msg.sender;
    }

    function approve(address spender) external {
        approvedSpenders[spender] = true;
    }

    function setQuoteSendFees(uint256 nativeFee, uint256 tokenFee) external {
        quoteSendNativeFee = nativeFee;
        quoteSendTokenFee = tokenFee;
    }

    function token() external view returns (address) {
        return UNDERLYING_TOKEN;
    }

    function quoteSend(
        SendParam calldata,
        bool
    ) external view returns (MessagingFee memory) {
        return
            MessagingFee({
                nativeFee: quoteSendNativeFee,
                lzTokenFee: quoteSendTokenFee
            });
    }

    function send(
        SendParam calldata sendParam,
        MessagingFee calldata fee,
        address refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory) {
        // Validate fee
        require(msg.value >= fee.nativeFee, "Insufficient fee");

        // Transfer tokens from sender
        IERC20(UNDERLYING_TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            sendParam.amountLD
        );

        // Burn tokens (simplified - in real OFT this would be more complex)
        // For testing, we'll just hold them

        // Refund excess native
        if (msg.value > fee.nativeFee) {
            payable(refundAddress).transfer(msg.value - fee.nativeFee);
        }

        // Return mock receipts
        return (
            MessagingReceipt({guid: bytes32(0), nonce: 0, fee: fee}),
            OFTReceipt({
                amountSentLD: sendParam.amountLD,
                amountReceivedLD: sendParam.amountLD
            })
        );
    }

    function forceApprove(address spender, uint256 amount) external {
        IERC20(UNDERLYING_TOKEN).approve(spender, amount);
    }

    // Helper functions for testing
    function mint(address to, uint256 amount) external {
        // In a real scenario, this would be handled by the OFT's minting mechanism
        // For testing, we'll assume tokens are pre-funded
    }

    function burn(address from, uint256 amount) external {
        // Simplified burn for testing
        IERC20(UNDERLYING_TOKEN).safeTransferFrom(from, address(this), amount);
    }
}
