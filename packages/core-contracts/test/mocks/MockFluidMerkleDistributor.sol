// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFluidMerkleDistributor} from "../../src/interfaces/fluid/IFluidMerkleDistributor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockFluidMerkleDistributor is IFluidMerkleDistributor {
    using SafeERC20 for IERC20;
    address public immutable token;

    constructor(address token_) {
        token = token_;
    }

    function TOKEN() external view override returns (address) {
        return token;
    }

    function claim(
        address recipient_,
        uint256 cumulativeAmount_,
        uint8 /*positionType_*/,
        bytes32 /*positionId_*/,
        uint256 /*cycle_*/,
        bytes32[] calldata /*merkleProof_*/,
        bytes memory /*metadata_*/
    ) external override {
        if (token != address(0)) {
            IERC20(token).safeTransfer(recipient_, cumulativeAmount_);
        }
    }
}
