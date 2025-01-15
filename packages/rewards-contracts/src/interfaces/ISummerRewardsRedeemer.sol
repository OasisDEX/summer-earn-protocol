// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISummerRewardsRedeemer
 * @author Summer.fi
 * @notice Interface for managing and distributing token rewards using Merkle proofs
 * @dev This contract enables efficient distribution of rewards to multiple users
 *      using Merkle trees. Each distribution is identified by an index and has its
 *      own Merkle root. Users can claim their rewards by providing proofs of inclusion.
 */
interface ISummerRewardsRedeemer {
    /// EVENTS
    event Claimed(address indexed user, uint256 indexed index, uint256 amount);
    event RootAdded(uint256 indexed index, bytes32 root);
    event RootRemoved(uint256 indexed index);

    /// ERRORS
    error InvalidRewardsToken(address token);
    error RootAlreadyAdded(uint256 index, bytes32 root);
    error UserCannotClaim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] proof
    );
    error UserAlreadyClaimed(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] proof
    );
    error ClaimMultipleLengthMismatch(
        uint256[] indices,
        uint256[] amounts,
        bytes32[][] proofs
    );
    error ClaimMultipleEmpty(
        uint256[] indices,
        uint256[] amounts,
        bytes32[][] proofs
    );
    error CallerNotAdmiralsQuarters();

    /**
     * @notice Adds a new Merkle root for a distribution
     * @param index Unique identifier for the distribution
     * @param root Merkle root hash of the distribution
     */
    function addRoot(uint256 index, bytes32 root) external;

    /**
     * @notice Removes a Merkle root
     * @param index Distribution index to remove
     */
    function removeRoot(uint256 index) external;

    /**
     * @notice Gets the Merkle root for a distribution
     * @param index Distribution index to query
     * @return bytes32 The Merkle root hash
     */
    function getRoot(uint256 index) external view returns (bytes32);

    /**
     * @notice Checks if a user can claim from a distribution
     * @param user Address of the user to check
     * @param index Distribution index to check
     * @param amount Amount attempting to claim
     * @param proof Merkle proof to verify
     * @return bool True if claim is possible, false otherwise
     */
    function canClaim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) external view returns (bool);

    /**
     * @notice Claims rewards for a single distribution
     * @param user Address of the user to claim for
     * @param index Distribution index to claim from
     * @param amount Amount of tokens to claim
     * @param proof Merkle proof verifying the claim
     */
    function claim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof
    ) external;

    /**
     * @notice Claims rewards from multiple distributions at once
     * @param user Address of the user to claim for
     * @param indices Array of distribution indices to claim from
     * @param amounts Array of amounts to claim from each distribution
     * @param proofs Array of Merkle proofs for each claim
     */
    function claimMultiple(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;

    /**
     * @notice Claims rewards for multiple distributions at once
     * @param indices Array of distribution indices to claim from
     * @param amounts Array of amounts to claim from each distribution
     * @param proofs Array of Merkle proofs for each claim
     */
    function claimMultiple(
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;

    /**
     * @notice Emergency withdrawal of tokens
     * @param token Address of token to withdraw
     * @param to Address to send tokens to
     * @param amount Amount of tokens to withdraw
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external;

    /**
     * @notice Checks if a user has already claimed from a distribution
     * @param user Address to check
     * @param index Distribution index to check
     * @return bool True if already claimed, false otherwise
     */
    function hasClaimed(
        address user,
        uint256 index
    ) external view returns (bool);

    /**
     * @notice Gets the timestamp when the contract was deployed
     * @return uint256 The deployment timestamp
     */
    function deployedAt() external view returns (uint256);

    /**
     * @notice Gets the token being distributed as rewards
     * @return IERC20 The rewards token
     */
    function rewardsToken() external view returns (IERC20);
}
