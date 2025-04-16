// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IMorpho, Id, Market, MarketParams, Position} from "morpho-blue/interfaces/IMorpho.sol";

import {MarketParamsLib} from "morpho-blue/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "morpho-blue/libraries/SharesMathLib.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {IUniversalRewardsDistributor} from "../../interfaces/morpho/IUniversalRewardsDistributor.sol";
import {MorphoBalancesLib} from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoLib} from "morpho-blue/libraries/periphery/MorphoLib.sol";
import {IUrdFactory} from "morpho-blue/interfaces/IUrdFactory.sol";

/**
 * @title MorphoArk
 * @notice Ark contract for managing token supply and yield generation through the Morpho protocol.
 * @dev Implements strategy for supplying tokens, withdrawing tokens, and claiming rewards on Morpho markets.
 */
contract MorphoArk is Ark {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    error InvalidMorphoAddress();
    error InvalidMarketId();
    error InvalidUrdFactoryAddress();
    error InvalidUrdAddress();

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
    /// @notice The Morpho protocol contract
    IMorpho public immutable MORPHO;

    IUrdFactory public immutable URD_FACTORY;

    /// @notice The market ID for the Morpho market this Ark interacts with
    Id public marketId;
    /// @notice The market parameters for the Morpho market
    MarketParams public marketParams;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for MorphoArk
     * @param _morpho The Morpho protocol address
     * @param _marketId The market ID for the Morpho market
     * @param _urdFactory The address of the Universal Rewards Distributor factory
     * @param _arkParams ArkParams struct containing initialization parameters
     */
    constructor(
        address _morpho,
        Id _marketId,
        address _urdFactory,
        ArkParams memory _arkParams
    ) Ark(_arkParams) {
        if (_morpho == address(0)) {
            revert InvalidMorphoAddress();
        }
        if (Id.unwrap(_marketId) == 0) {
            revert InvalidMarketId();
        }
        if (_urdFactory == address(0)) {
            revert InvalidUrdFactoryAddress();
        }
        URD_FACTORY = IUrdFactory(_urdFactory);
        MORPHO = IMorpho(_morpho);
        marketId = _marketId;
        marketParams = MORPHO.idToMarketParams(_marketId);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the Morpho market
     * @return assets The total balance of assets supplied to the Morpho market
     */
    function totalAssets() public view override returns (uint256 assets) {
        Position memory position = MORPHO.position(marketId, address(this));
        if (position.supplyShares > 0) {
            Market memory market = MORPHO.market(marketId);
            assets = position.supplyShares.toAssetsDown(
                market.totalSupplyAssets,
                market.totalSupplyShares
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev MorphoArk is always withdrawable
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 _totalAssets = totalAssets();
        if (_totalAssets > 0) {
            Market memory market = MORPHO.market(marketId);
            uint256 availableAssets = market.totalBorrowAssets <=
                market.totalSupplyAssets
                ? market.totalSupplyAssets - market.totalBorrowAssets
                : 0;
            withdrawableAssets = _totalAssets < availableAssets
                ? _totalAssets
                : availableAssets;
        }
    }

    /**
     * @notice Supplies tokens to the Morpho market
     * @param amount The amount of tokens to supply
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        config.asset.forceApprove(address(MORPHO), amount);
        MORPHO.supply(marketParams, amount, 0, address(this), hex"");
    }

    /**
     * @notice Withdraws tokens from the Morpho market
     * @param amount The amount of tokens to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        MORPHO.withdraw(marketParams, amount, 0, address(this), address(this));
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
             * @param address(this) The address of the contract claiming the rewards (this MorphoArk)
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
