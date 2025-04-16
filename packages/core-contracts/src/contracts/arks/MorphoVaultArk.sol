// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniversalRewardsDistributor} from "../../interfaces/morpho/IUniversalRewardsDistributor.sol";
import "../Ark.sol";
import {IMetaMorpho} from "metamorpho/interfaces/IMetaMorpho.sol";
import {IUrdFactory} from "morpho-blue/interfaces/IUrdFactory.sol";

error InvalidUrdAddress();
error InvalidUrdFactoryAddress();

/**
 * @title MorphoVaultArk
 * @notice Ark contract for managing token supply and yield generation through MetaMorpho vaults.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and claiming rewards from MetaMorpho vaults.
 */
contract MorphoVaultArk is Ark {
    using SafeERC20 for IERC20;

    /**
     * @notice Struct to hold data for claiming rewards
     * @param urd Array of Universal Rewards Distributor addresses
     * @param rewards Array of reward token addresses
     * @param claimable Array of claimable reward amounts
     * @param proofs Array of Merkle proofs for claiming rewards
     */
    struct RewardsData {
        address[] urd;
        address[] rewards;
        uint256[] claimable;
        bytes32[][] proofs;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The MetaMorpho vault this Ark interacts with
    IMetaMorpho public immutable metaMorpho;

    /// @notice The URD factory this Ark interacts with
    IUrdFactory public immutable URD_FACTORY;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the MorphoVaultArk
     * @param _metaMorpho Address of the MetaMorpho vault
     * @param _urdFactory Address of the URD factory
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _metaMorpho,
        address _urdFactory,
        ArkParams memory _params
    ) Ark(_params) {
        if (_metaMorpho == address(0)) {
            revert InvalidVaultAddress();
        }
        if (_urdFactory == address(0)) {
            revert InvalidUrdFactoryAddress();
        }
        URD_FACTORY = IUrdFactory(_urdFactory);
        metaMorpho = IMetaMorpho(_metaMorpho);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the MetaMorpho vault
     * @return assets The total balance of underlying assets held in the vault for this Ark
     */
    function totalAssets() public view override returns (uint256 assets) {
        uint256 shares = metaMorpho.balanceOf(address(this));
        if (shares > 0) {
            assets = metaMorpho.convertToAssets(shares);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev MetaMorphoArk is always withdrawable
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = metaMorpho.balanceOf(address(this));
        if (shares > 0) {
            withdrawableAssets = metaMorpho.maxWithdraw(address(this));
        }
    }

    /**
     * @notice Deposits assets into the MetaMorpho vault
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(metaMorpho), amount);
        metaMorpho.deposit(amount, address(this));
    }

    /**
     * @notice Withdraws assets from the MetaMorpho vault
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        if (amount == totalAssets()) {
            metaMorpho.redeem(
                metaMorpho.balanceOf(address(this)),
                address(this),
                address(this)
            );
        } else {
            metaMorpho.withdraw(amount, address(this), address(this));
        }
    }

    /**
     * @notice Internal function to harvest rewards based on the provided claim data
     * @dev This function decodes the claim data, iterates through the rewards, and claims them
     *      from the respective Universal Rewards Distributors. The claimed rewards are then
     *      transferred to the configured raft address.
     *
     * @param _claimData Encoded RewardsData struct containing information about the rewards to be claimed
     *
     * @return rewardTokens An array of addresses of the reward tokens that were claimed
     * @return rewardAmounts An array of amounts of the reward tokens that were claimed
     *
     * The RewardsData struct is expected to contain:
     * - urd: An array of Universal Rewards Distributor addresses
     * - rewards: An array of reward token addresses
     * - claimable: An array of claimable reward amounts
     * - proofs: An array of Merkle proofs for claiming rewards
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
            if (!URD_FACTORY.isUrd(claimData.urd[i])) {
                revert InvalidUrdAddress();
            }
            /**
             * @dev Claims rewards from the Universal Rewards Distributor
             * @param address(this) The address of the contract claiming the rewards (this MorphoVaultArk)
             * @param claimData.rewards[i] The address of the reward token to claim
             * @param claimData.claimable[i] The amount of rewards to claim
             * @param claimData.proofs[i] The Merkle proof required to claim the rewards
             */
            uint256 claimed = IUniversalRewardsDistributor(claimData.urd[i])
                .claim(
                    address(this),
                    claimData.rewards[i],
                    claimData.claimable[i],
                    claimData.proofs[i]
                );
            rewardTokens[i] = claimData.rewards[i];
            rewardAmounts[i] = claimed;
            IERC20(claimData.rewards[i]).safeTransfer(raft(), claimed);
        }

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /**
     * @notice Validates the board data
     * @dev This Ark does not require any validation for board data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateBoardData(bytes calldata) internal override {}

    /**
     * @notice Validates the disembark data
     * @dev This Ark does not require any validation for disembark data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateDisembarkData(bytes calldata) internal override {}
}
