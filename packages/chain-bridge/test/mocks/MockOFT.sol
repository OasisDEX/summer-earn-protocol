// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MessagingFee, SendParam, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockOFT
 * @notice Mock OFT contract for testing LayerZero compose functionality
 * @dev Simple mock implementation for testing purposes
 */
contract MockOFT is ERC20 {
    IERC20 public immutable tokenAddress;

    /// @notice Mock endpoint for testing
    address public endpoint;

    /// @notice Mock fee for testing
    uint256 public mockNativeFee = 0.01 ether;
    uint256 public mockLzTokenFee = 0;

    constructor(
        string memory name,
        string memory symbol,
        address _token,
        address _endpoint
    ) ERC20(name, symbol) {
        tokenAddress = IERC20(_token);
        endpoint = _endpoint;
    }

    /// @notice Mock token function
    function token() external view returns (address) {
        return address(tokenAddress);
    }

    /// @notice Mock quoteSend function
    function quoteSend(
        SendParam calldata,
        bool
    ) external view returns (MessagingFee memory) {
        return
            MessagingFee({
                nativeFee: mockNativeFee,
                lzTokenFee: mockLzTokenFee
            });
    }

    /// @notice Mock send function
    function send(
        SendParam calldata,
        MessagingFee calldata fee,
        address refundAddress
    ) external payable returns (MessagingReceipt memory) {
        // Mock implementation - just return a receipt
        return
            MessagingReceipt({
                guid: keccak256(abi.encodePacked(block.timestamp, msg.sender)),
                fee: fee,
                nonce: uint64(block.timestamp)
            });
    }

    /// @notice Mock lzReceive function for testing
    function lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata,
        address,
        bytes calldata
    ) external payable {
        // Mock implementation
    }

    /// @notice Mock lzCompose function for testing
    function lzCompose(
        address,
        bytes32,
        bytes calldata,
        address,
        bytes calldata
    ) external payable {
        // Mock implementation
    }

    /// @notice Mock approvalRequired function
    function approvalRequired() external view returns (bool) {
        return false;
    }

    /// @notice Mock oftVersion function
    function oftVersion()
        external
        view
        returns (bytes4 interfaceId, uint64 version)
    {
        return (bytes4(0), 1);
    }

    /// @notice Mock quoteOFT function
    function quoteOFT(
        SendParam calldata,
        bool
    ) external view returns (MessagingFee memory) {
        return
            MessagingFee({
                nativeFee: mockNativeFee,
                lzTokenFee: mockLzTokenFee
            });
    }

    /// @notice Mock sharedDecimals function
    function sharedDecimals() external view returns (uint8) {
        return 18;
    }

    /// @notice Set mock fees for testing
    function setMockFees(uint256 _nativeFee, uint256 _lzTokenFee) external {
        mockNativeFee = _nativeFee;
        mockLzTokenFee = _lzTokenFee;
    }

    /// @notice Mint tokens for testing
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burn tokens for testing
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
