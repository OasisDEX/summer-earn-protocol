// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPSM3 {
    function previewSwapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function previewSwapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);

    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountIn);

    function pocket() external view returns (address);
}

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

    function _validateBoardData(bytes calldata) internal pure override {}
    function _validateDisembarkData(bytes calldata) internal pure override {}

    // No harvest function needed as rewards are automatically compounded in sUSDS
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
