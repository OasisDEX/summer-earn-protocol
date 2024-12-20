// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {console} from "forge-std/console.sol";
contract SummerRewardsRedeemer is ProtocolAccessManaged {
    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;

    /// STORAGE
    uint256 public deployedAt;
    IERC20 public immutable rewardsToken;

    mapping(uint256 index => bytes32 rootHash) public roots;
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

    function addRoot(uint256 index, bytes32 root) external onlyGovernor {
        if (roots[index] != bytes32(0)) {
            revert RootAlreadyAdded(index, root);
        }
        roots[index] = root;
        emit RootAdded(index, root);
    }

    function removeRoot(uint256 index) external onlyGovernor {
        delete roots[index];
        emit RootRemoved(index);
    }

    function getRoot(uint256 index) external view returns (bytes32) {
        return roots[index];
    }

    function hasClaimed(
        address user,
        uint256 index
    ) public view returns (bool) {
        return claimedRoots[user].get(index);
    }

    function canClaim(
        uint256 index,
        uint256 amount,
        bytes32[] memory proof
    ) external view returns (bool) {
        return
            _couldClaim(index, amount, proof) &&
            !hasClaimed(_msgSender(), index);
    }

    function claim(
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        BitMaps.BitMap storage userClaimedRoots = claimedRoots[_msgSender()];

        _processClaim(index, amount, proof, userClaimedRoots);
        _sendRewards(_msgSender(), amount);
    }

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
}
