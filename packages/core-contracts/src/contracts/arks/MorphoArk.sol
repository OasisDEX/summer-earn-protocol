// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMorpho, Id, Market, MarketParams, Position} from "morpho-blue/interfaces/IMorpho.sol";

import {MarketParamsLib} from "morpho-blue/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "morpho-blue/libraries/SharesMathLib.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {IUniversalRewardsDistributor} from "../../interfaces/morpho/IUniversalRewardsDistributor.sol";
import {MorphoBalancesLib} from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoLib} from "morpho-blue/libraries/periphery/MorphoLib.sol";
import {IUniversalRewardsDistributor} from "../../interfaces/morpho/IUniversalRewardsDistributor.sol";

error InvalidMorphoAddress();
error InvalidMarketId();

/**
 * @title MorphoArk
 * @notice This contract manages a Morpho token strategy within the Ark system
 */
contract MorphoArk is Ark {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

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
    IMorpho public immutable MORPHO;
    /// @notice The market ID
    Id public marketId;
    /// @notice The market parameters
    MarketParams public marketParams;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for MorphoArk
     * @param _morpho The Morpho Vault address
     * @param _marketId The market ID
     */
    constructor(
        address _morpho,
        Id _marketId,
        ArkParams memory _arkParams
    ) Ark(_arkParams) {
        if (_morpho == address(0)) {
            revert InvalidMorphoAddress();
        }
        if (Id.unwrap(_marketId) == 0) {
            revert InvalidMarketId();
        }
        MORPHO = IMorpho(_morpho);
        marketId = _marketId;
        marketParams = MORPHO.idToMarketParams(_marketId);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256) {
        Position memory position = MORPHO.position(marketId, address(this));
        Market memory market = MORPHO.market(marketId);

        return
            position.supplyShares.toAssetsDown(
                market.totalSupplyAssets,
                market.totalSupplyShares
            );
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Boards tokens into the Morpho Vault
     * @param amount The amount of tokens to board
     */
    function _board(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        config.token.approve(address(MORPHO), amount);
        MORPHO.supply(marketParams, amount, 0, address(this), hex"");
    }

    /**
     * @notice Disembarks tokens from the Morpho Vault
     * @param amount The amount of tokens to disembark
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        MORPHO.withdraw(marketParams, amount, 0, address(this), address(this));
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
            IERC20(claimData.rewards[i]).safeTransfer(raft(), rewardAmounts[i]);
        }

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /**
     * @notice No-op for validateBoardData function
     * @dev MorphoArk does not require any validation for board data
     */
    function _validateBoardData(bytes calldata data) internal override {}

    /**
     * @notice No-op for validateDisembarkData function
     * @dev MorphoArk does not require any validation for disembark data
     */
    function _validateDisembarkData(bytes calldata data) internal override {}
}
