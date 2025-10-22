// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFluidMerkleDistributor} from "../../interfaces/fluid/IFluidMerkleDistributor.sol";
import {ERC4626Ark} from "./ERC4626Ark.sol";
import {ArkParams} from "../../types/ArkTypes.sol";

/**
 * @title FluidFTokenArk
 * @notice Ark contract for managing token supply and yield generation through Fluid fTokens.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and tracking yield from Fluid fToken vaults.
 @dev implements harvest function to claim rewards from Fluid's Merkle distributor
 */
contract FluidFTokenArk is ERC4626Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the ERC4626Ark
     * @param _vault Address of the ERC4626-compliant vault
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _vault,
        ArkParams memory _params
    ) ERC4626Ark(_vault, _params) {}

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function for harvesting rewards from Fluid's Merkle distributor
     * @dev Decodes merkle claim data, validates inputs, claims rewards, and forwards to Raft
     * @param data ABI-encoded ClaimData
     * @return rewardTokens The addresses of the harvested reward tokens
     * @return rewardAmounts The amounts of the harvested reward tokens
     */
    function _harvest(
        bytes calldata data
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        ClaimData memory claimData = abi.decode(data, (ClaimData));

        // Basic validations
        if (claimData.merkleClaimer == address(0)) {
            revert InvalidMerkleClaimer();
        }
        if (claimData.recipient != address(this)) {
            revert InvalidRecipient(address(this), claimData.recipient);
        }

        // Resolve reward token from distributor
        address rewardToken = IFluidMerkleDistributor(claimData.merkleClaimer)
            .TOKEN();
        if (rewardToken == address(0)) revert InvalidRewardToken();

        // Claim and compute delta
        uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
        IFluidMerkleDistributor(claimData.merkleClaimer).claim(
            claimData.recipient,
            claimData.cumulativeAmount,
            claimData.positionType,
            claimData.positionId,
            claimData.cycle,
            claimData.merkleProof,
            claimData.metadata
        );
        uint256 claimedAmount = IERC20(rewardToken).balanceOf(address(this)) -
            balanceBefore;

        // Forward rewards to Raft if any
        if (claimedAmount > 0) {
            IERC20(rewardToken).safeTransfer(raft(), claimedAmount);
        }

        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);
        rewardTokens[0] = rewardToken;
        rewardAmounts[0] = claimedAmount;
    }

    /// @notice Encapsulates inputs to IFluidMerkleDistributor.claim
    struct ClaimData {
        /// @notice Address of the Fluid Merkle distributor contract to call
        address merkleClaimer;
        /// @notice Address of the recipient
        address recipient;
        /// @notice Cumulative amount of rewards to claim
        uint256 cumulativeAmount;
        /// @notice Type of position (1 = lending, 2 = vaults, 3 = smart lending, etc.)
        uint8 positionType;
        /// @notice ID of the position (fToken address for lending; vaultId for vaults)
        bytes32 positionId;
        /// @notice Cycle of the rewards
        uint256 cycle;
        /// @notice Merkle proof of the rewards
        bytes32[] merkleProof;
        /// @notice Arbitrary metadata forwarded to the distributor
        bytes metadata;
    }

    /// @dev Thrown when the provided merkle claimer address is zero
    error InvalidMerkleClaimer();
    /// @dev Thrown when the provided recipient is not this Ark (prevents siphoning)
    error InvalidRecipient(address expected, address actual);
    /// @dev Thrown when the reward token returned by the distributor is zero
    error InvalidRewardToken();
}
