// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMetaMorpho} from "metamorpho/interfaces/IMetaMorpho.sol";
import {IUniversalRewardsDistributor} from "../../interfaces/morpho/IUniversalRewardsDistributor.sol";

/**
 * @title MorphoVaultArk
 * @notice This contract manages a Morpho Vaulttoken strategy within the Ark system
 */
contract MetaMorphoArk is Ark {
    using SafeERC20 for IERC20;

    struct RewardsData {
        address[] urd;
        address[] rewards;
        uint256[] claimable;
        bytes32[][] proofs;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Morpho Vault address
    IMetaMorpho public immutable metaMorpho;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for MetaMorphoArk
     * @param _metaMorpho Address of the Morpho Vault
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(address _metaMorpho, ArkParams memory _params) Ark(_params) {
        if (_metaMorpho == address(0)) {
            revert InvalidVaultAddress();
        }
        metaMorpho = IMetaMorpho(_metaMorpho);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256 assets) {
        return metaMorpho.convertToAssets(metaMorpho.balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Boards into the MetaMorpho Vault
     * @param amount The amount of tokens to board
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.token.approve(address(metaMorpho), amount);
        metaMorpho.deposit(amount, address(this));
    }

    /**
     * @notice Disembarks from the MetaMorpho Vault
     * @param amount The amount of tokens to disembark
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        metaMorpho.withdraw(amount, address(this), address(this));
    }

    /**
     * @dev Internal function to harvest rewards based on the provided claim data.
     *
     * This function decodes the claim data, iterates through the rewards, and claims them
     * from the respective rewards distributors. The claimed rewards are then transferred
     * to the configured raft address.
     *
     * @param _claimData The encoded claim data containing information about the rewards to be claimed.
     *
     * @return rewardTokens An array of addresses of the reward tokens that were claimed.
     * @return rewardAmounts An array of amounts of the reward tokens that were claimed.
     *
     * The claim data is expected to be in the following format:
     * - claimData.urd: An array of addresses of the rewards distributors.
     * - claimData.rewards: An array of addresses of the rewards tokens.
     * - claimData.claimable: An array of amounts of the rewards to be claimed.
     * - claimData.proofs: An array of Merkle proofs to claim the rewards.
     *
     * Emits an {ArkHarvested} event upon successful harvesting of rewards.
     */
    function _harvest(
        bytes calldata _claimData
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        RewardsData memory claimData = abi.decode(_claimData, (RewardsData));
        rewardTokens = new address[](claimData.rewards.length);
        rewardAmounts = new uint256[](claimData.rewards.length);
        for (uint256 i = 0; i < claimData.rewards.length; i++) {
            /**
             * @dev Calls the `claim` function of the `IUniversalRewardsDistributorBase` contract to claim rewards.
             * @param claimData.urd[i] The address of the rewards distributor to claim from.
             * @param claimData.rewards[i] The address of the rewards token to claim.
             * @param claimData.claimable[i] The amount of rewards to claim.
             * @param claimData.proofs[i] The Merkle proof to claim the rewards.
             * @param address(this) The address of the contract claiming the rewards - DPM proxy.
             */
            IUniversalRewardsDistributor(claimData.urd[i]).claim(
                address(this),
                claimData.rewards[i],
                claimData.claimable[i],
                claimData.proofs[i]
            );
            rewardTokens[i] = claimData.rewards[i];
            rewardAmounts[i] = claimData.claimable[i];
            IERC20(claimData.rewards[i]).safeTransfer(
                config.raft,
                rewardAmounts[i]
            );
        }

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /**
     * @notice Validates the board data
     * @dev MetaMorpho Ark does not require any validation for board data
     */
    function _validateBoardData(bytes calldata) internal override {}
    /**
     * @notice Validates the disembark data
     * @dev MetaMorpho Ark does not require any validation for board or disembark data
     */
    function _validateDisembarkData(bytes calldata) internal override {}
}
