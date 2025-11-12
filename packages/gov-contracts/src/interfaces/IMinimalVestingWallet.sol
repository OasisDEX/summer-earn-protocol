// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @dev this is a minimal vesting wallet interface
interface IMinimalVestingWallet {
    /// @dev the balance of the vesting wallet can only go down - if it goes up - tokens were sent to the wallet (unintended bhavior)
    function balanceOf(address _user) external view returns (uint256);
    /// @dev the current owner of the vesting wallet ( might be different that owner in the factory contract)
    function owner() external view returns (address);
    /// @dev the ownership of the vesting wallet can be trnsfered - this is used to transfer the ownership of the vesting wallet to the user
    function transferOwnership(address newOwner) external;
    /// @dev the amount of tokens released from the vesting wallet
    function released(address _token) external view returns (uint256);
}
