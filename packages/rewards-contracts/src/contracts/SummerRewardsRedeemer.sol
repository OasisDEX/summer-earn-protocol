// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ISummerRewardsRedeemer} from "../interfaces/ISummerRewardsRedeemer.sol";

/**
 * @title SummerRewardsRedeemer
 * @author Summer.fi
 * @notice Implementation of ISummerRewardsRedeemer
 */
contract SummerRewardsRedeemer is
    ISummerRewardsRedeemer,
    ProtocolAccessManaged
{
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

    /// @inheritdoc ISummerRewardsRedeemer
    function addRoot(uint256 index, bytes32 root) external onlyGovernor {
        if (roots[index] != bytes32(0)) {
            revert RootAlreadyAdded(index, root);
        }
        roots[index] = root;
        emit RootAdded(index, root);
    }

    /// @inheritdoc ISummerRewardsRedeemer
    function removeRoot(uint256 index) external onlyGovernor {
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
    ) external onlyGovernor {
        IERC20(token).safeTransfer(to, amount);
    }

    /// INTERNALS

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
