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

    error MoonwellMintFailed();
    error MoonwellRedeemUnderlyingFailed();
    error MoonwellAssetMismatch();
    error InvalidMoonwellAddress();
    error MoonwellRedeemFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Moonwell-compliant mToken this Ark interacts with
    IMToken public immutable mToken;
    IComptroller public immutable comptroller;
    IRewardDistributor public immutable rewardDistributor;

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
        address rewardDistributorAddress = comptroller.rewardDistributor();
        if (rewardDistributorAddress == address(0)) {
            revert InvalidMoonwellAddress();
        }
        rewardDistributor = IRewardDistributor(rewardDistributorAddress);

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
     * @dev MoonwellArk is always withdrawable
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
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op for most Moonwell vaults as they automatically accrue interest
     * @param /// data Additional data (unused in this implementation)
     * @return rewardTokens The addresses of the reward tokens
     * @return rewardAmounts The amounts of the reward tokens
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        address _raft = raft();
        address[] memory mTokens = new address[](1);
        mTokens[0] = address(address(mToken));

        comptroller.claimReward(payable(address(this)), mTokens);

        MarketConfig[] memory marketConfigs = rewardDistributor
            .getAllMarketConfigs(address(mToken));

        rewardTokens = new address[](marketConfigs.length);
        rewardAmounts = new uint256[](marketConfigs.length);
        for (uint256 i = 0; i < marketConfigs.length; i++) {
            rewardTokens[i] = marketConfigs[i].emissionToken;
            uint256 rewardBalance = IERC20(marketConfigs[i].emissionToken)
                .balanceOf(address(this));
            rewardAmounts[i] = rewardBalance;
            IERC20(marketConfigs[i].emissionToken).safeTransfer(
                _raft,
                rewardBalance
            );
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

    function _calculateNewReserves(
        uint256 reservesPrior,
        uint256 interestAccumulated
    ) internal view returns (uint256) {
        uint256 reserveFactor = mToken.reserveFactorMantissa();
        return reserveFactor.mulWadDown(interestAccumulated) + reservesPrior;
    }
}
