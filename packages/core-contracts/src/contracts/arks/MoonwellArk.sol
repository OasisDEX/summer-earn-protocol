// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IMToken} from "../../interfaces/moonwell/IMToken.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IInterestRateModel} from "../../interfaces/moonwell/IInterestRateModel.sol";
import {IComptroller} from "../../interfaces/moonwell/IComptroller.sol";
import {IRewardDistributor, MarketConfig} from "../../interfaces/moonwell/IRewardDistributor.sol";
import {FixedPointMathLib} from "@summerfi/dependencies/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title MoonwellArk
 * @notice Ark contract for managing token supply and yield generation through any Moonwell-compliant mToken.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and tracking yield from Moonwell vaults.
 */
contract MoonwellArk is Ark {
    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20;

    /// @notice Thrown when mToken.mint() returns a non-zero (failure) code while boarding
    error MoonwellMintFailed();
    /// @notice Thrown when mToken.redeem() returns a non-zero (failure) code during a full-position exit
    error MoonwellRedeemUnderlyingFailed();
    /// @notice Thrown when the mToken's underlying asset does not match the Ark's configured asset
    error MoonwellAssetMismatch();
    /// @notice Thrown when the mToken, its comptroller, or the reward distributor address is the zero address
    error InvalidMoonwellAddress();
    /// @notice Thrown when mToken.redeemUnderlying() returns a non-zero (failure) code during a partial exit
    error MoonwellRedeemFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Moonwell-compliant mToken this Ark interacts with
    IMToken public immutable mToken;
    /// @notice The Moonwell comptroller for the mToken, used to claim emission rewards on harvest
    IComptroller public immutable comptroller;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the MoonwellArk
     * @param _mToken Address of the Moonwell-compliant mToken
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(address _mToken, ArkParams memory _params) Ark(_params) {
        if (_mToken == address(0)) {
            revert InvalidMoonwellAddress();
        }

        mToken = IMToken(_mToken);

        // Ensure the mToken's asset matches the Ark's token
        if (address(mToken.underlying()) != address(config.asset)) {
            revert MoonwellAssetMismatch();
        }

        address comptrollerAddress = mToken.comptroller();
        if (comptrollerAddress == address(0)) {
            revert InvalidMoonwellAddress();
        }
        comptroller = IComptroller(comptrollerAddress);

        // Approve the mToken to spend the Ark's tokens
        config.asset.forceApprove(_mToken, Constants.MAX_UINT256);
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the Moonwell mToken
     * @return assets The total balance of underlying assets held in the mToken for this Ark
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets = balanceOfUnderlyingWithInterest(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Caps the withdrawable amount by the mToken's available cash
     *      (the underlying asset balance held by the mToken). When the market
     *      is highly utilised this can be less than the Ark's underlying
     *      balance, since borrowed assets cannot be redeemed.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 userAssets = balanceOfUnderlyingWithInterest(address(this));
        uint256 availableAssets = config.asset.balanceOf(address(mToken));
        withdrawableAssets = Math.min(userAssets, availableAssets);
    }

    /**
     * @notice Deposits assets into the Moonwell mToken
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        if (mToken.mint(amount) != 0) {
            revert MoonwellMintFailed();
        }
    }

    /**
     * @notice Withdraws assets from the Moonwell mToken
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // to avoid leaving any dust amount in the mToken, we redeem the entire balance if the amount is the same as the balance

        if (amount == balanceOfUnderlyingWithInterest(address(this))) {
            if (mToken.redeem(mToken.balanceOf(address(this))) != 0) {
                revert MoonwellRedeemUnderlyingFailed();
            }
        } else {
            if (mToken.redeemUnderlying(amount) != 0) {
                revert MoonwellRedeemFailed();
            }
        }
    }

    /**
     * @notice Internal function for harvesting Moonwell emission rewards
     * @dev Claims rewards for the mToken from the comptroller, then transfers
     *      every emission token with a non-zero balance to the raft(). The
     *      returned arrays are compacted to only include reward tokens that
     *      were actually received. Reverts with InvalidMoonwellAddress if the
     *      comptroller has no reward distributor configured.
     * @param /// data Additional data (unused in this implementation)
     * @return rewardTokens The addresses of the reward tokens transferred to the raft
     * @return rewardAmounts The amounts of each reward token transferred to the raft
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        address _raft = raft();
        address rewardDistributorAddress = comptroller.rewardDistributor();
        if (rewardDistributorAddress == address(0)) {
            revert InvalidMoonwellAddress();
        }
        IRewardDistributor rewardDistributor = IRewardDistributor(
            rewardDistributorAddress
        );

        address[] memory mTokens = new address[](1);
        mTokens[0] = address(mToken);

        comptroller.claimReward(payable(address(this)), mTokens);

        MarketConfig[] memory marketConfigs = rewardDistributor
            .getAllMarketConfigs(address(mToken));

        address[] memory allRewardTokens = new address[](marketConfigs.length);
        uint256[] memory allRewardAmounts = new uint256[](marketConfigs.length);
        for (uint256 i = 0; i < marketConfigs.length; i++) {
            allRewardTokens[i] = marketConfigs[i].emissionToken;
            uint256 rewardBalance = IERC20(marketConfigs[i].emissionToken)
                .balanceOf(address(this));
            allRewardAmounts[i] = rewardBalance;
            if (rewardBalance > 0) {
                IERC20(marketConfigs[i].emissionToken).safeTransfer(
                    _raft,
                    rewardBalance
                );
            }
        }
        uint256 nonZeroRewardAmounts = 0;
        for (uint256 i = 0; i < allRewardAmounts.length; i++) {
            if (allRewardAmounts[i] > 0) {
                nonZeroRewardAmounts++;
            }
        }
        rewardTokens = new address[](nonZeroRewardAmounts);
        rewardAmounts = new uint256[](nonZeroRewardAmounts);
        uint256 index = 0;
        for (uint256 i = 0; i < allRewardAmounts.length; i++) {
            if (allRewardAmounts[i] > 0) {
                rewardTokens[index] = allRewardTokens[i];
                rewardAmounts[index] = allRewardAmounts[i];
                index++;
            }
        }
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

    /**
     * @notice Get the underlying balance of a user with accrued interest, without modifying state
     * @param user The address of the user to check
     * @return The amount of underlying tokens the user effectively owns, including accrued interest
     */
    function balanceOfUnderlyingWithInterest(
        address user
    ) public view returns (uint256) {
        (, uint256 shares, , uint256 storedExchangeRate) = mToken
            .getAccountSnapshot(user);

        uint256 accrualBlockTimestampPrior = mToken.accrualBlockTimestamp();

        // If no time has passed, use stored rate
        if (accrualBlockTimestampPrior == block.timestamp) {
            return shares.mulWadDown(storedExchangeRate);
        }

        uint256 exchangeRate = _calculateCurrentExchangeRate();
        return shares.mulWadDown(exchangeRate);
    }

    /**
     * @notice Computes the mToken's current exchange rate including interest
     *         that has accrued since the last on-chain accrual, without
     *         mutating state
     * @return The exchange rate (underlying per mToken share, WAD-scaled)
     */
    function _calculateCurrentExchangeRate() internal view returns (uint256) {
        uint256 totalSupply = mToken.totalSupply();
        if (totalSupply == 0) {
            return mToken.exchangeRateStored();
        }

        uint256 totalCash = mToken.getCash();
        uint256 borrowsPrior = mToken.totalBorrows();
        uint256 reservesPrior = mToken.totalReserves();

        uint256 interestAccumulated = _calculateInterestAccumulated(
            totalCash,
            borrowsPrior,
            reservesPrior
        );

        uint256 totalReserves = _calculateNewReserves(
            reservesPrior,
            interestAccumulated
        );
        uint256 totalBorrows = interestAccumulated + borrowsPrior;

        uint256 _totalAssets = totalCash + totalBorrows - totalReserves;
        return _totalAssets.divWadDown(totalSupply);
    }

    /**
     * @notice Computes the interest accrued on outstanding borrows since the
     *         mToken's last accrual timestamp
     * @param totalCash The mToken's current underlying cash balance
     * @param borrowsPrior The total borrows recorded at the last accrual
     * @param reservesPrior The total reserves recorded at the last accrual
     * @return The interest accumulated over the elapsed time
     */
    function _calculateInterestAccumulated(
        uint256 totalCash,
        uint256 borrowsPrior,
        uint256 reservesPrior
    ) internal view returns (uint256) {
        uint256 borrowRateMantissa = IInterestRateModel(
            mToken.interestRateModel()
        ).getBorrowRate(totalCash, borrowsPrior, reservesPrior);

        require(borrowRateMantissa <= 0.0005e16, "RATE_TOO_HIGH");

        uint256 timeDelta = block.timestamp - mToken.accrualBlockTimestamp();
        return (borrowRateMantissa * timeDelta).mulWadDown(borrowsPrior);
    }

    /**
     * @notice Computes the mToken's total reserves after applying the reserve
     *         factor to newly accumulated interest
     * @param reservesPrior The total reserves recorded at the last accrual
     * @param interestAccumulated The interest accumulated since the last accrual
     * @return The updated total reserves
     */
    function _calculateNewReserves(
        uint256 reservesPrior,
        uint256 interestAccumulated
    ) internal view returns (uint256) {
        uint256 reserveFactor = mToken.reserveFactorMantissa();
        return reserveFactor.mulWadDown(interestAccumulated) + reservesPrior;
    }
}
