// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IMToken} from "../../interfaces/moonwell/IMToken.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {console} from "forge-std/console.sol";
import {IInterestRateModel} from "../../interfaces/moonwell/IInterestRateModel.sol";
import {Exponential} from "@summerfi/dependencies/moonwell/Exponential.sol";
/**
 * @title MoonwellArk
 * @notice Ark contract for managing token supply and yield generation through any Moonwell-compliant mToken.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and tracking yield from Moonwell vaults.
 */
contract MoonwellArk is Ark, Exponential {
    using SafeERC20 for IERC20;

    error MoonwellMintFailed();
    error MoonwellRedeemUnderlyingFailed();
    error MoonwellAssetMismatch();
    error InvalidMoonwellAddress();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Moonwell-compliant mToken this Ark interacts with
    IMToken public immutable mToken;

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
        if (mToken.redeemUnderlying(amount) != 0) {
            revert MoonwellRedeemUnderlyingFailed();
        }
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op for most Moonwell vaults as they automatically accrue interest
     * @param /// data Additional data (unused in this implementation)
     * @return rewardTokens The addresses of the reward tokens (empty array in this case)
     * @return rewardAmounts The amounts of the reward tokens (empty array in this case)
     */
    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(0);
        rewardAmounts[0] = 0;
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

    // Add this struct near the top of the contract
    struct AccrualInfo {
        uint256 currentBlockTimestamp;
        uint256 accrualBlockTimestamp;
        uint256 cashPrior;
        uint256 borrowsPrior;
        uint256 reservesPrior;
        uint256 totalSupply;
        uint256 borrowRateMantissa;
    }

    struct InterestCalcs {
        uint256 interestAccumulated;
        uint256 totalBorrowsNew;
        uint256 totalReservesNew;
        uint256 newExchangeRate;
    }

    /**
     * @notice Calculate interest accumulated and new borrow amount
     */
    function _calculateInterestAndBorrows(
        uint256 blockDelta,
        uint256 borrowRateMantissa,
        uint256 borrowsPrior
    )
        internal
        pure
        returns (uint256 interestAccumulated, uint256 totalBorrowsNew)
    {
        // Calculate interest factor
        (MathError err1, Exp memory simpleInterestFactor) = mulScalar(
            Exp({mantissa: borrowRateMantissa}),
            blockDelta
        );
        require(
            err1 == MathError.NO_ERROR,
            "interest factor calculation failed"
        );

        // Calculate interest accumulated
        (MathError err2, uint256 interest) = mulScalarTruncate(
            simpleInterestFactor,
            borrowsPrior
        );
        require(
            err2 == MathError.NO_ERROR,
            "interest accumulated calculation failed"
        );

        // Calculate new borrows
        (MathError err3, uint256 newBorrows) = addUInt(borrowsPrior, interest);
        require(err3 == MathError.NO_ERROR, "total borrows calculation failed");

        return (interest, newBorrows);
    }

    /**
     * @notice Calculate new reserves
     */
    function _calculateNewReserves(
        uint256 reservesPrior,
        uint256 interestAccumulated
    ) internal view returns (uint256) {
        (MathError err4, Exp memory reserveFactor) = getExp(
            mToken.reserveFactorMantissa(),
            expScale
        );
        require(
            err4 == MathError.NO_ERROR,
            "reserve factor calculation failed"
        );

        (MathError err5, uint256 reservesAccumulated) = mulScalarTruncate(
            reserveFactor,
            interestAccumulated
        );
        require(
            err5 == MathError.NO_ERROR,
            "reserves accumulated calculation failed"
        );

        (MathError err6, uint256 totalReservesNew) = addUInt(
            reservesPrior,
            reservesAccumulated
        );
        require(
            err6 == MathError.NO_ERROR,
            "total reserves calculation failed"
        );

        return totalReservesNew;
    }

    /**
     * @notice Calculate new exchange rate
     */
    function _calculateExchangeRate(
        uint256 cashPrior,
        uint256 totalBorrowsNew,
        uint256 totalReservesNew,
        uint256 totalSupply
    ) internal pure returns (uint256) {
        (MathError err7, uint256 totalCashAndBorrows) = addUInt(
            cashPrior,
            totalBorrowsNew
        );
        require(
            err7 == MathError.NO_ERROR,
            "total cash and borrows calculation failed"
        );

        (MathError err8, uint256 totalAvailable) = subUInt(
            totalCashAndBorrows,
            totalReservesNew
        );
        require(
            err8 == MathError.NO_ERROR,
            "total available calculation failed"
        );

        (MathError err9, Exp memory newExchangeRate) = getExp(
            totalAvailable,
            totalSupply
        );
        require(err9 == MathError.NO_ERROR, "exchange rate calculation failed");

        return newExchangeRate.mantissa;
    }

    /**
     * @notice Internal function to calculate new exchange rate with accrued interest
     */
    function _calculateAccruedInterest(
        AccrualInfo memory info
    ) internal view returns (uint256) {
        if (info.totalSupply == 0) {
            return 0;
        }

        // Calculate block delta
        (MathError err0, uint256 blockDelta) = subUInt(
            info.currentBlockTimestamp,
            info.accrualBlockTimestamp
        );
        require(err0 == MathError.NO_ERROR, "block delta calculation failed");

        // Calculate interest and new borrows
        (
            uint256 interestAccumulated,
            uint256 totalBorrowsNew
        ) = _calculateInterestAndBorrows(
                blockDelta,
                info.borrowRateMantissa,
                info.borrowsPrior
            );

        // Calculate new reserves
        uint256 totalReservesNew = _calculateNewReserves(
            info.reservesPrior,
            interestAccumulated
        );

        // Calculate new exchange rate
        return
            _calculateExchangeRate(
                info.cashPrior,
                totalBorrowsNew,
                totalReservesNew,
                info.totalSupply
            );
    }

    /**
     * @notice Get the underlying balance of a user with accrued interest, without modifying state
     * @param user The address of the user to check
     * @return The amount of underlying tokens the user effectively owns, including accrued interest
     */
    function balanceOfUnderlyingWithInterest(
        address user
    ) public view returns (uint256) {
        // Get current values
        (, uint256 shares, , uint256 storedExchangeRate) = mToken
            .getAccountSnapshot(user);

        AccrualInfo memory info;
        info.currentBlockTimestamp = block.timestamp;
        info.accrualBlockTimestamp = mToken.accrualBlockTimestamp();

        // If no time has passed, just use stored values
        if (info.accrualBlockTimestamp == info.currentBlockTimestamp) {
            return (shares * storedExchangeRate) / expScale;
        }

        // Get current market state
        info.cashPrior = mToken.getCash();
        info.borrowsPrior = mToken.totalBorrows();
        info.reservesPrior = mToken.totalReserves();
        info.totalSupply = mToken.totalSupply();
        info.borrowRateMantissa = IInterestRateModel(mToken.interestRateModel())
            .getBorrowRate(
                info.cashPrior,
                info.borrowsPrior,
                info.reservesPrior
            );

        // Calculate new exchange rate
        uint256 newExchangeRate = _calculateAccruedInterest(info);

        // Calculate final balance
        (MathError err, uint256 balance) = mulScalarTruncate(
            Exp({mantissa: newExchangeRate}),
            shares
        );
        require(err == MathError.NO_ERROR, "balance calculation failed");

        return balance;
    }
}
