// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILitePSM {
    function sellGem(address usr, uint256 gemAmt) external returns (uint256);
    function buyGem(address usr, uint256 gemAmt) external returns (uint256);
    function to18ConversionFactor() external view returns (uint256);
}

contract SkyUsdsArk is Ark {
    using SafeERC20 for IERC20;

    uint256 public immutable TO_18_DECIMALS_CONVERSION_FACTOR;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The LitePSM contract for fleet asset -> USDS swaps
    ILitePSM public immutable litePsm;
    /// @notice The USDS token contract
    IERC20 public immutable usds;
    /// @notice The stakedUSDS vault contract
    IERC4626 public immutable stakedUsds;

    constructor(
        address _litePsm,
        address _usds,
        address _stakedUsds,
        ArkParams memory _params
    ) Ark(_params) {
        litePsm = ILitePSM(_litePsm);
        TO_18_DECIMALS_CONVERSION_FACTOR = litePsm.to18ConversionFactor();
        usds = IERC20(_usds);
        stakedUsds = IERC4626(_stakedUsds);
    }

    function totalAssets() public view override returns (uint256 assets) {
        uint256 balance = stakedUsds.balanceOf(address(this));
        if (balance > 0) {
            assets =
                stakedUsds.convertToAssets(balance) /
                TO_18_DECIMALS_CONVERSION_FACTOR;
        }
    }

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev SkyUsdsArk is always withdrawable
     * @dev TODO:  check for current psm liquidity
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = stakedUsds.balanceOf(address(this));
        if (shares > 0) {
            withdrawableAssets =
                stakedUsds.maxWithdraw(address(this)) /
                TO_18_DECIMALS_CONVERSION_FACTOR;
        }
    }

    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(litePsm), amount);
        uint256 usdsAmount = litePsm.sellGem(address(this), amount);
        usds.forceApprove(address(stakedUsds), usdsAmount);
        stakedUsds.deposit(usdsAmount, address(this));
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        uint256 usdsAmount = amount * TO_18_DECIMALS_CONVERSION_FACTOR;
        stakedUsds.withdraw(usdsAmount, address(this), address(this));
        usds.forceApprove(address(litePsm), usdsAmount);
        litePsm.buyGem(address(this), amount);
    }

    function _validateBoardData(bytes calldata) internal pure override {}
    function _validateDisembarkData(bytes calldata) internal pure override {}

    // No harvest function needed as rewards are automatically compounded in stakedUSDS
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
