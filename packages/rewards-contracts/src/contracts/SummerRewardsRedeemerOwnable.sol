// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerRewardsRedeemer} from "../interfaces/ISummerRewardsRedeemer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

/**
 * @title SummerRewardsRedeemer
 * @author Summer.fi
 * @notice Implementation of ISummerRewardsRedeemer
 */
contract SummerRewardsRedeemerOwnable is ISummerRewardsRedeemer, Ownable {
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

    /// CONSTRUCTOR
    constructor(address _rewardsToken, address _owner) Ownable(_owner) {
        if (_rewardsToken == address(0)) {
            revert InvalidRewardsToken(_rewardsToken);
        }
        rewardsToken = IERC20(_rewardsToken);
        deployedAt = block.timestamp;
    }

    /// EXTERNAL FUNCTIONS

    /// @inheritdoc ISummerRewardsRedeemer
    function addRoot(uint256 index, bytes32 root) external onlyOwner {
        if (roots[index] != bytes32(0)) {
            revert RootAlreadyAdded(index, root);
        }
        roots[index] = root;
        emit RootAdded(index, root);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function removeRoot(uint256 index) external onlyOwner {
        delete roots[index];
        emit RootRemoved(index);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function getRoot(uint256 index) external view returns (bytes32) {
        return roots[index];
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function canClaim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) external view returns (bool) {
        return
            _couldClaim(user, index, amount, proof) && !hasClaimed(user, index);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function claim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        BitMaps.BitMap storage userClaimedRoots = claimedRoots[user];

        _processClaim(user, index, amount, proof, userClaimedRoots);
        _sendRewards(user, amount);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function claimMultiple(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        _claimMultiple(user, indices, amounts, proofs);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function claimMultiple(
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        _claimMultiple(_msgSender(), indices, amounts, proofs);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /// INTERNALS

    /**
     * @notice Helper function to check if a user is included in the Merkle root for a given distribution
     * @param user The address of the user to check
     * @param index The distribution index
     * @param amount The reward amount
     * @param proof The Merkle proof verifying inclusion
     * @return bool True if the proof is valid, false otherwise
     */
    function _couldClaim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(user, amount)))
        );
        return MerkleProof.verify(proof, roots[index], leaf);
    }

    /**
     * @notice Verifies that a claim is valid and has not already been made
     * @dev Reverts if the proof is invalid or if the user already claimed
     * @param user The address of the user attempting to claim
     * @param index The distribution index
     * @param amount The reward amount to claim
     * @param proof The Merkle proof verifying inclusion
     */
    function _verifyClaim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) internal view {
        if (!_couldClaim(user, index, amount, proof)) {
            revert UserCannotClaim(user, index, amount, proof);
        }

        if (hasClaimed(user, index)) {
            revert UserAlreadyClaimed(user, index, amount, proof);
        }
    }

    /**
     * @notice Processes a single claim by verifying it, marking it as claimed in the bitmap, and emitting an event
     * @param user The address of the user claiming the reward
     * @param index The distribution index
     * @param amount The reward amount
     * @param proof The Merkle proof verifying inclusion
     * @param userClaimedRoots The bitmap tracking claimed roots for the user
     */
    function _processClaim(
        address user,
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof,
        BitMaps.BitMap storage userClaimedRoots
    ) internal {
        _verifyClaim(user, index, amount, proof);

        userClaimedRoots.set(index);

        emit Claimed(user, index, amount);
    }

    /**
     * @notice Internal helper to transfer reward tokens to a recipient
     * @param to The recipient address
     * @param amount The amount of tokens to transfer
     */
    function _sendRewards(address to, uint256 amount) internal {
        rewardsToken.safeTransfer(to, amount);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function hasClaimed(
        address user,
        uint256 index
    ) public view returns (bool) {
        return claimedRoots[user].get(index);
    }

    /**
     * @notice Processes claims for multiple distributions in a single transaction
     * @dev Reverts if there is an array length mismatch or if the arrays are empty
     * @param user The address of the user claiming the rewards
     * @param indices Array of distribution indices
     * @param amounts Array of reward amounts
     * @param proofs Matrix of Merkle proofs for each distribution
     */
    function _claimMultiple(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) internal {
        if (
            indices.length != amounts.length || amounts.length != proofs.length
        ) {
            revert ClaimMultipleLengthMismatch(indices, amounts, proofs);
        }
        if (indices.length == 0) {
            revert ClaimMultipleEmpty(indices, amounts, proofs);
        }

        uint256 total;
        BitMaps.BitMap storage userClaimedRoots = claimedRoots[user];

        for (uint256 i = 0; i < indices.length; i += 1) {
            _processClaim(
                user,
                indices[i],
                amounts[i],
                proofs[i],
                userClaimedRoots
            );

            total += amounts[i];
        }

        _sendRewards(user, total);
    }
}
