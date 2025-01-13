// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title SummerRewardsRedeemer
 * @author Summer.fi
 * @notice Contract for managing and distributing token rewards using Merkle proofs
 * @dev This contract enables efficient distribution of rewards to multiple users
 *      using Merkle trees. Each distribution is identified by an index and has its
 *      own Merkle root. Users can claim their rewards by providing proofs of inclusion.
 *
 *      Security features:
 *      - Double-hashed leaves to prevent second preimage attacks
 *      - Bitmap-based claim tracking
 *      - Safe ERC20 transfers
 *      - Governance-controlled root management
 */
contract SummerRewardsRedeemer is ProtocolAccessManaged {
    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;

    /**
     * @notice Timestamp when the contract was deployed
     * @dev Used for tracking contract age and potential migrations
     */
    uint256 public deployedAt;

    /**
     * @notice Token being distributed as rewards
     * @dev Set at deployment and cannot be changed
     */
    IERC20 public immutable rewardsToken;

    /**
     * @notice Mapping of distribution indices to their Merkle roots
     * @dev Each distribution has a unique index and corresponding root hash
     */
    mapping(uint256 index => bytes32 rootHash) public roots;

    /**
     * @notice Tracks which distributions have been claimed by each user
     * @dev Uses bitmap for gas-efficient storage
     */
    mapping(address user => BitMaps.BitMap claimedRoots) private claimedRoots;

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

    /// CONSTRUCTOR
    constructor(
        address _rewardsToken,
        address _accessManager
    ) ProtocolAccessManaged(_accessManager) {
        if (_rewardsToken == address(0)) {
            revert InvalidRewardsToken(_rewardsToken);
        }
        rewardsToken = IERC20(_rewardsToken);
        deployedAt = block.timestamp;
    }

    /// EXTERNAL FUNCTIONS

    /**
     * @notice Adds a new Merkle root for a distribution
     * @param index Unique identifier for the distribution
     * @param root Merkle root hash of the distribution
     * @dev Only callable by governance
     * @dev Reverts if root already exists for the given index
     */
    function addRoot(uint256 index, bytes32 root) external onlyGovernor {
        if (roots[index] != bytes32(0)) {
            revert RootAlreadyAdded(index, root);
        }
        roots[index] = root;
        emit RootAdded(index, root);
    }

    /**
     * @notice Removes a Merkle root
     * @param index Distribution index to remove
     * @dev Only callable by governance
     * @dev Used for correcting errors or updating distributions
     */
    function removeRoot(uint256 index) external onlyGovernor {
        delete roots[index];
        emit RootRemoved(index);
    }

    function getRoot(uint256 index) external view returns (bytes32) {
        return roots[index];
    }

    /**
     * @notice Checks if a user can claim from a distribution
     * @param index Distribution index to check
     * @param amount Amount attempting to claim
     * @param proof Merkle proof to verify
     * @return bool True if claim is possible, false otherwise
     * @dev Returns false if already claimed or proof is invalid
     */
    function canClaim(
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) external view returns (bool) {
        return
            _couldClaim(index, amount, proof) &&
            !hasClaimed(_msgSender(), index);
    }

    /**
     * @notice Claims rewards for a single distribution
     * @param index Distribution index to claim from
     * @param amount Amount of tokens to claim
     * @param proof Merkle proof verifying the claim
     * @dev Verifies proof, marks claim as processed, and transfers tokens
     */
    function claim(
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        BitMaps.BitMap storage userClaimedRoots = claimedRoots[_msgSender()];

        _processClaim(index, amount, proof, userClaimedRoots);
        _sendRewards(_msgSender(), amount);
    }

    /**
     * @notice Claims rewards from multiple distributions at once
     * @param indices Array of distribution indices to claim from
     * @param amounts Array of amounts to claim from each distribution
     * @param proofs Array of Merkle proofs for each claim
     * @dev Processes multiple claims in a single transaction
     * @dev All arrays must be equal length and non-empty
     */
    function claimMultiple(
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        if (
            indices.length != amounts.length || amounts.length != proofs.length
        ) {
            revert ClaimMultipleLengthMismatch(indices, amounts, proofs);
        }
        if (indices.length == 0) {
            revert ClaimMultipleEmpty(indices, amounts, proofs);
        }

        uint256 total;
        BitMaps.BitMap storage userClaimedRoots = claimedRoots[_msgSender()];

        for (uint256 i = 0; i < indices.length; i += 1) {
            _processClaim(indices[i], amounts[i], proofs[i], userClaimedRoots);

            total += amounts[i];
        }

        _sendRewards(_msgSender(), total);
    }

    /**
     * @notice Emergency withdrawal of tokens
     * @param token Address of token to withdraw
     * @param to Address to send tokens to
     * @param amount Amount of tokens to withdraw
     * @dev Only callable by governance
     * @dev Used for recovering stuck tokens or handling emergencies
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyGovernor {
        IERC20(token).transfer(to, amount);
    }

    /// INTERNALS

    function _couldClaim(
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(_msgSender(), amount)))
        );
        return MerkleProof.verify(proof, roots[index], leaf);
    }

    function _verifyClaim(
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) internal view {
        if (!_couldClaim(index, amount, proof)) {
            revert UserCannotClaim(_msgSender(), index, amount, proof);
        }

        if (hasClaimed(_msgSender(), index)) {
            revert UserAlreadyClaimed(_msgSender(), index, amount, proof);
        }
    }

    function _processClaim(
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof,
        BitMaps.BitMap storage userClaimedRoots
    ) internal {
        _verifyClaim(index, amount, proof);

        userClaimedRoots.set(index);

        emit Claimed(_msgSender(), index, amount);
    }

    function _sendRewards(address to, uint256 amount) internal {
        rewardsToken.safeTransfer(to, amount);
    }

    /**
     * @notice Checks if a user has already claimed from a distribution
     * @param user Address to check
     * @param index Distribution index to check
     * @return bool True if already claimed, false otherwise
     */
    function hasClaimed(
        address user,
        uint256 index
    ) public view returns (bool) {
        return claimedRoots[user].get(index);
    }
}
