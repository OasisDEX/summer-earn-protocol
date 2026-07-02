// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ISyrupWithdrawalManagerV2
/// @notice Interface for the V2 Maple Syrup withdrawal manager supporting multiple requests per owner
interface ISyrupWithdrawalManagerV2 {
    /**
     *  @notice Returns the last request id for a given owner.
     *          Function must exist for backwards compatibility with the old implementation where we supported only one
     * request per owner.
     *  @param  owner          The account to check the last request id for.
     *  @return requestId      The id of the last valid withdrawal request for the account.
     */
    function requestIds(
        address owner
    ) external view returns (uint256 requestId);

    /**
     *  @notice Returns the owner and amount of shares associated with a withdrawal request.
     *  @param  requestId Identifier of the withdrawal request.
     *  @return owner     Address of the share owner.
     *  @return shares    Amount of shares pending redemption.
     */
    function requests(
        uint256 requestId
    ) external view returns (address owner, uint256 shares);

    /**
     *  @notice Returns the amount of shares escrowed for a specific user yet to be processed.
     *  @param  owner          The address of the owner of shares.
     *  @return escrowedShares Amount of shares escrowed for the user.
     */
    function userEscrowedShares(
        address owner
    ) external view returns (uint256 escrowedShares);
}
