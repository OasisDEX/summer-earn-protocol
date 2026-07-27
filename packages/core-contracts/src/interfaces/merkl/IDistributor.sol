// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IDistributor
/// @notice Interface for the Merkl Merkle-based rewards distributor
interface IDistributor {
    /// @notice Toggles whether an operator is authorized to claim on behalf of a user
    /// @param user The user granting or revoking the operator
    /// @param operator The operator to toggle
    function toggleOperator(address user, address operator) external;

    /// @notice Claims rewards for multiple users and tokens using Merkle proofs
    /// @param users The recipients of the claims
    /// @param tokens The reward tokens to claim, aligned with users
    /// @param amounts The cumulative amounts to claim, aligned with users/tokens
    /// @param proofs The Merkle proofs for each claim
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;

    /// @notice Returns whether an operator is authorized for a user (non-zero if authorized)
    /// @param user The user to query
    /// @param operator The operator to query
    /// @return Non-zero if the operator is authorized for the user
    function operators(
        address user,
        address operator
    ) external view returns (uint256);
}
