// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniversalRewardsDistributor} from "../../src/interfaces/morpho/IUniversalRewardsDistributor.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockUniversalRewardsDistributor is IUniversalRewardsDistributor {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public claimed;
    bytes32 public root;

    function setRoot(bytes32 _root, bytes32) external {
        root = _root;
    }

    function claim(
        address account,
        address reward,
        uint256 claimable,
        bytes32[] calldata proof
    ) external returns (uint256 amount) {
        require(root != bytes32(0), "ROOT_NOT_SET");
        require(
            _verifyProof(
                proof,
                root,
                keccak256(abi.encode(account, reward, claimable))
            ),
            "INVALID_PROOF_OR_EXPIRED"
        );
        require(claimable > claimed[account][reward], "CLAIMABLE_TOO_LOW");
        amount = claimable - claimed[account][reward];
        claimed[account][reward] = claimable;
        IERC20(reward).safeTransfer(account, amount);
        emit Claimed(account, reward, amount);
    }

    // Simple mock of MerkleProof.verify for testing purposes
    function _verifyProof(
        bytes32[] memory,
        bytes32,
        bytes32
    ) internal pure returns (bool) {
        return true;
    }
}
