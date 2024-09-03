// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PercentageUtils, Percentage, PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

abstract contract BaseSwapArk is Ark {
    error OracleNotReady();
    error InvalidAssetForSY();
    error InvalidNextMarket();
    error OracleDurationTooLow(
        uint32 providedDuration,
        uint256 minimumDuration
    );
    error SlippagePercentageTooHigh(
        Percentage providedSlippage,
        Percentage maxSlippage
    );
    error MarketExpired();

    struct SwapCallData {
        IERC20 fromToken;
        IERC20 toToken;
        uint256 fromTokenAmount;
        uint256 minTokensReceived;
        bytes swapCalldata;
    }

    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    // Constants
    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    /// @notice Maximum allowed slippage percentage
    Percentage public constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;

    // State variables
    IERC20 public arkToken;
    /// @notice Slippage tolerance for operations
    Percentage public slippagePercentage;

    constructor(ArkParams memory _params, address _arkToken) Ark(_params) {
        require(_arkToken != address(0), "Invalid ark token address");
        arkToken = IERC20(_arkToken);
        slippagePercentage = PercentageUtils.fromFraction(5, 1000); // 0.5% default
    }

    function totalAssets() public view override returns (uint256) {
        uint256 arkTokenBalance = arkToken.balanceOf(address(this));
        return
            _arkTokensToUnderlying(arkTokenBalance).subtractPercentage(
                slippagePercentage
            );
    }

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
        // emit SlippageUpdated(_slippagePercentage);
    }

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

        require(swappedAmount >= amount, "Insufficient output");

        emit Disembarked(msg.sender, address(config.token), swappedAmount);
    }

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
        require(success, "Swap failed");

        uint256 balanceAfter = toToken.balanceOf(address(this));
        swappedAmount = balanceAfter - balanceBefore;

        require(
            swappedAmount >= minTokensReceived,
            "Insufficient output amount"
        );
    }

    function _validateBoardData(bytes calldata data) internal override {
        require(data.length > 0, "Swap data required");
    }

    function _validateDisembarkData(bytes calldata data) internal override {
        require(data.length > 0, "Swap data required");
    }

    // Abstract functions to be implemented by inheriting contracts
    function getExchangeRate() public view virtual returns (uint256);

    // Optional: Add more abstract functions if needed for specific oracle implementations
}
