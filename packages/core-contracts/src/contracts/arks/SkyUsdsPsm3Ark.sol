// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title IPSM3
/// @notice Minimal interface for the Sky PSM3 used to swap between the fleet
///         asset and sUSDS at an oracle-derived rate
interface IPSM3 {
    /// @notice Previews the output amount for an exact-input swap
    /// @param assetIn Asset being sold
    /// @param assetOut Asset being bought
    /// @param amountIn Amount of assetIn
    /// @return amountOut Amount of assetOut that would be received
    function previewSwapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    /// @notice Previews the input amount required for an exact-output swap
    /// @param assetIn Asset being sold
    /// @param assetOut Asset being bought
    /// @param amountOut Desired amount of assetOut
    /// @return amountIn Amount of assetIn that would be required
    function previewSwapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    /// @notice Swaps an exact input amount, requiring at least minAmountOut out
    /// @param assetIn Asset being sold
    /// @param assetOut Asset being bought
    /// @param amountIn Amount of assetIn to sell
    /// @param minAmountOut Minimum acceptable amount of assetOut
    /// @param receiver Recipient of assetOut
    /// @param referralCode Referral code for the swap
    /// @return amountOut Amount of assetOut received
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);

    /// @notice Swaps for an exact output amount, spending at most maxAmountIn
    /// @param assetIn Asset being sold
    /// @param assetOut Asset being bought
    /// @param amountOut Exact amount of assetOut to receive
    /// @param maxAmountIn Maximum acceptable amount of assetIn to spend
    /// @param receiver Recipient of assetOut
    /// @param referralCode Referral code for the swap
    /// @return amountIn Amount of assetIn spent
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountIn);

    /// @notice Returns the address holding the PSM's liquid asset reserves
    /// @return The pocket address
    function pocket() external view returns (address);
}

/// @title SkyUsdsPsm3Ark
/// @notice Ark that swaps the fleet asset to sUSDS via the Sky PSM3 for yield,
///         and swaps sUSDS back to the fleet asset on withdrawal
contract SkyUsdsPsm3Ark is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The PSM3 contract for fleet asset <-> sUSDS swaps
    /// @dev Uses external oracle for rate, making it manipulation resistant
    IPSM3 public immutable psm;
    /// @notice The sUSDS token contract
    IERC20 public immutable susds;

    constructor(
        address _psm,
        address _susds,
        ArkParams memory _params
    ) Ark(_params) {
        psm = IPSM3(_psm);
        susds = IERC20(_susds);
    }

    function totalAssets() public view override returns (uint256 assets) {
        uint256 balance = susds.balanceOf(address(this));
        if (balance > 0) {
            assets = psm.previewSwapExactIn(
                address(susds),
                address(config.asset),
                balance
            );
        }
    }

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev SkyUsdsPsm3Ark is withdrawable if there's enough USDC to swap for
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 _totalAssets = totalAssets();
        if (_totalAssets > 0) {
            uint256 psmUsdcBalance = config.asset.balanceOf(psm.pocket());
            withdrawableAssets = _totalAssets < psmUsdcBalance
                ? _totalAssets
                : psmUsdcBalance;
        }
    }

    /// @notice Swaps the fleet asset to sUSDS via the PSM3
    function _board(uint256 amount, bytes calldata) internal override {
        // Approve PSM to take fleet asset
        config.asset.forceApprove(address(psm), amount);

        // Preview swap to get expected sUSDS amount
        uint256 expectedSusds = psm.previewSwapExactIn(
            address(config.asset),
            address(susds),
            amount
        );
        // Perform swap with exact output as preview
        psm.swapExactIn(
            address(config.asset),
            address(susds),
            amount,
            expectedSusds,
            address(this),
            0
        );
    }

    /// @notice Swaps sUSDS back to the exact requested fleet-asset amount via the PSM3
    function _disembark(uint256 amount, bytes calldata) internal override {
        // Preview swap to get required sUSDS amount for desired USDC output
        uint256 susdsNeeded = psm.previewSwapExactOut(
            address(susds),
            address(config.asset),
            amount
        );
        // Perform swap with exact output as preview
        susds.forceApprove(address(psm), susdsNeeded);
        psm.swapExactOut(
            address(susds),
            address(config.asset),
            amount,
            susdsNeeded,
            address(this),
            0
        );
    }

    /// @notice Validates the board data (no-op; this Ark requires no board data)
    function _validateBoardData(bytes calldata) internal pure override {}
    /// @notice Validates the disembark data (no-op; this Ark requires no disembark data)
    function _validateDisembarkData(bytes calldata) internal pure override {}

    // No harvest function needed as rewards are automatically compounded in sUSDS
    /// @notice No-op harvest: yield is auto-compounded inside sUSDS, so no rewards are claimed
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
}
