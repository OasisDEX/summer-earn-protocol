// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "../Ark.sol";
import {IBaseSwapArkEvents} from "../../events/arks/IBaseSwapArkEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PercentageUtils, Percentage, PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {IBaseSwapArk} from "../../interfaces/arks/IBaseSwapArk.sol";
/**
 * @title BaseSwapArk
 * @notice Base contract for swap-based Ark strategies
 * @dev This contract contains common functionality for Arks that use token swaps
 */
abstract contract BaseSwapArk is Ark, IBaseSwapArk {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /**
     * @notice Struct to hold swap call data
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param fromTokenAmount The amount of tokens to swap
     * @param minTokensReceived The minimum amount of tokens to receive
     * @param swapCalldata The calldata for the swap
     */
    struct SwapCallData {
        IERC20 fromToken;
        IERC20 toToken;
        uint256 fromTokenAmount;
        uint256 minTokensReceived;
        bytes swapCalldata;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the 1inch router
    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    /// @notice Maximum allowed slippage percentage
    Percentage public constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The token used by the Ark
    IERC20 public arkToken;
    /// @notice Slippage tolerance for operations
    Percentage public slippagePercentage;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for BaseSwapArk
     * @param _params ArkParams struct containing initialization parameters
     * @param _arkToken Address of the Ark token
     */
    constructor(ArkParams memory _params, address _arkToken) Ark(_params) {
        if (_arkToken == address(0)) revert InvalidArkTokenAddress();
        arkToken = IERC20(_arkToken);
        slippagePercentage = PercentageUtils.fromFraction(25, 100000); // 0.025% default
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the slippage tolerance
     * @param _slippagePercentage New slippage tolerance
     */
    function setSlippagePercentage(
        Percentage _slippagePercentage
    ) external onlyGovernor {
        if (_slippagePercentage > MAX_SLIPPAGE_PERCENTAGE) {
            revert SlippagePercentageTooHigh(
                _slippagePercentage,
                MAX_SLIPPAGE_PERCENTAGE
            );
        }
        slippagePercentage = _slippagePercentage;
        emit SlippageUpdated(_slippagePercentage);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits assets into the Ark
     * @param amount Amount of assets to deposit
     * @param swapCalldata Calldata for the swap operation
     */
    function _board(
        uint256 amount,
        bytes calldata swapCalldata
    ) internal override {
        SwapCallData memory swapData = abi.decode(swapCalldata, (SwapCallData));
        // Swap config.token to arkToken
        _swap(
            config.token,
            arkToken,
            swapData.fromTokenAmount,
            swapData.minTokensReceived,
            swapData.swapCalldata
        );

        emit Boarded(msg.sender, address(config.token), amount);
    }

    /**
     * @notice Withdraws assets from the Ark
     * @param amount Amount of assets to withdraw
     * @param swapCalldata Calldata for the swap operation
     */
    function _disembark(
        uint256 amount,
        bytes calldata swapCalldata
    ) internal override {
        SwapCallData memory swapData = abi.decode(swapCalldata, (SwapCallData));
        uint256 actualAmountToSwap = _underlyingToArkTokens(amount)
            .addPercentage(slippagePercentage);
        // Swap arkToken back to config.token
        uint256 swappedAmount = _swap(
            arkToken,
            config.token,
            actualAmountToSwap,
            swapData.minTokensReceived,
            swapData.swapCalldata
        );

        if (swappedAmount < amount) revert InsufficientOutputAmount();

        emit Disembarked(msg.sender, address(config.token), swappedAmount);
    }

    /**
     * @notice Performs a token swap
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amount The amount of tokens to swap
     * @param minTokensReceived The minimum amount of tokens to receive
     * @param swapCalldata The calldata for the swap
     * @return swappedAmount The amount of tokens received from the swap
     */
    function _swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 minTokensReceived,
        bytes memory swapCalldata
    ) internal returns (uint256 swappedAmount) {
        uint256 balanceBefore = toToken.balanceOf(address(this));

        fromToken.forceApprove(ONE_INCH_ROUTER, 10 * amount);
        (bool success, ) = ONE_INCH_ROUTER.call(swapCalldata);
        if (!success) revert SwapFailed();

        uint256 balanceAfter = toToken.balanceOf(address(this));
        swappedAmount = balanceAfter - balanceBefore;

        if (swappedAmount < minTokensReceived)
            revert InsufficientOutputAmount();
    }

    /**
     * @notice Validates the board data
     * @param data The data to validate
     */
    function _validateBoardData(bytes calldata data) internal pure override {
        if (data.length == 0) revert SwapDataRequired();
    }

    /**
     * @notice Validates the disembark data
     * @param data The data to validate
     */
    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {
        if (data.length == 0) revert SwapDataRequired();
    }

    /**
     * @notice Converts underlying tokens to Ark tokens
     * @param underlyingAmount The amount of underlying tokens
     * @return The equivalent amount of Ark tokens
     */
    function _underlyingToArkTokens(
        uint256 underlyingAmount
    ) internal view returns (uint256) {
        uint256 configTokenDecimals = ERC20(address(config.token)).decimals();
        uint256 arkTokenDecimals = ERC20(address(arkToken)).decimals();
        uint256 exchangeRate = getExchangeRate();

        // Convert underlying amount to ark token amount
        uint256 rawArkTokenAmount = (underlyingAmount *
            (10 ** arkTokenDecimals) *
            1e18) /
            (10 ** configTokenDecimals) /
            exchangeRate;

        return rawArkTokenAmount;
    }

    /**
     * @notice Converts Ark tokens to underlying tokens
     * @param arkTokenAmount The amount of Ark tokens
     * @return The equivalent amount of underlying tokens
     */
    function _arkTokensToUnderlying(
        uint256 arkTokenAmount
    ) internal view returns (uint256) {
        uint256 configTokenDecimals = ERC20(address(config.token)).decimals();
        uint256 arkTokenDecimals = ERC20(address(arkToken)).decimals();
        uint256 exchangeRate = getExchangeRate();

        // Convert ark token amount to underlying amount
        uint256 rawUnderlyingAmount = (arkTokenAmount *
            (10 ** configTokenDecimals) *
            exchangeRate) /
            (10 ** arkTokenDecimals) /
            1e18;

        return rawUnderlyingAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            ABSTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the current exchange rate between Ark tokens and underlying tokens
     * @return The current exchange rate
     */
    function getExchangeRate() public view virtual returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the total assets held by the Ark
     * @return The total assets in underlying token
     */
    function totalAssets() public view override returns (uint256) {
        uint256 arkTokenBalance = arkToken.balanceOf(address(this));
        return
            _arkTokensToUnderlying(arkTokenBalance).subtractPercentage(
                slippagePercentage
            );
    }
}