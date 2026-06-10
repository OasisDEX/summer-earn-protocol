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
    /**
     * @notice Emitted when a user successfully claims rewards
     * @param user The address of the user who claimed the rewards
     * @param index The distribution index from which the rewards were claimed
     * @param amount The amount of tokens claimed
     */
    event Claimed(address indexed user, uint256 indexed index, uint256 amount);

    /**
     * @notice Emitted when a new Merkle root is added for a distribution
     * @param index The distribution index for the root
     * @param root The Merkle root hash
     */
    event RootAdded(uint256 indexed index, bytes32 root);

    /**
     * @notice Emitted when a Merkle root is removed
     * @param index The distribution index of the removed root
     */
    event RootRemoved(uint256 indexed index);

    /// ERRORS
    /**
     * @notice Thrown when attempting to initialize the contract with an invalid rewards token address
     * @param token The address of the invalid token
     */
    error InvalidRewardsToken(address token);

    /**
     * @notice Thrown when attempting to add a Merkle root for an index that already has one
     * @param index The distribution index
     * @param root The Merkle root hash that was attempted to be added
     */
    error RootAlreadyAdded(uint256 index, bytes32 root);

    /**
     * @notice Thrown when a user cannot claim rewards due to an invalid Merkle proof
     * @param user The address of the user
     * @param index The distribution index
     * @param amount The amount attempted to claim
     * @param proof The Merkle proof provided
     */
    error UserCannotClaim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] proof
    );

    /**
     * @notice Thrown when a user attempts to claim rewards they have already claimed
     * @param user The address of the user
     * @param index The distribution index
     * @param amount The amount attempted to claim
     * @param proof The Merkle proof provided
     */
    error UserAlreadyClaimed(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] proof
    );

    /**
     * @notice Thrown when claiming multiple rewards and the arrays have mismatched lengths
     * @param indices Array of distribution indices
     * @param amounts Array of reward amounts
     * @param proofs Array of Merkle proofs
     */
    error ClaimMultipleLengthMismatch(
        uint256[] indices,
        uint256[] amounts,
        bytes32[][] proofs
    );

    /**
     * @notice Thrown when claiming multiple rewards and the provided arrays are empty
     * @param indices Array of distribution indices
     * @param amounts Array of reward amounts
     * @param proofs Array of Merkle proofs
     */
    error ClaimMultipleEmpty(
        uint256[] indices,
        uint256[] amounts,
        bytes32[][] proofs
    );

    /**
     * @notice Thrown when the caller is not Admiral's Quarters (the governor manager)
     */
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
