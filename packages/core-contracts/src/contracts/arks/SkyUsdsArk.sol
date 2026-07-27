// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ILitePSM
/// @notice Minimal interface for the Maker/Sky Lite Peg Stability Module used to
///         swap between the gem (the Ark's fleet asset, e.g. USDC) and USDS
interface ILitePSM {
    /// @notice Sells gem to the PSM in exchange for USDS
    /// @param usr Recipient of the USDS
    /// @param gemAmt Amount of gem (fleet asset) to sell
    /// @return The amount of USDS received
    function sellGem(address usr, uint256 gemAmt) external returns (uint256);
    /// @notice Buys gem from the PSM in exchange for USDS
    /// @param usr Recipient of the gem
    /// @param gemAmt Amount of gem (fleet asset) to buy
    /// @return The amount of USDS paid
    function buyGem(address usr, uint256 gemAmt) external returns (uint256);
    /// @notice Returns the factor that scales the gem's amount up to 18 decimals
    /// @return The 18-decimal conversion factor
    function to18ConversionFactor() external view returns (uint256);
}

/// @title SkyUsdsArk
/// @notice Ark that swaps the fleet asset to USDS via the Lite PSM and stakes
///         the USDS in the sUSDS (stakedUSDS) ERC4626 vault for yield
contract SkyUsdsArk is Ark {
    using SafeERC20 for IERC20;

    /// @notice Factor scaling the fleet asset's amount up to USDS's 18 decimals
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
     * @dev Caps the withdrawable amount by stakedUsds.maxWithdraw() (the sUSDS
     *      vault's reported limit), converted back to the fleet asset's
     *      decimals. It does NOT additionally account for available LitePSM
     *      buyGem liquidity, so a withdrawal can still fail at the PSM step if
     *      the PSM lacks gem liquidity.
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

    /// @notice Swaps the fleet asset to USDS via the Lite PSM and deposits the USDS into sUSDS
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(litePsm), amount);
        uint256 usdsAmount = litePsm.sellGem(address(this), amount);
        usds.forceApprove(address(stakedUsds), usdsAmount);
        stakedUsds.deposit(usdsAmount, address(this));
    }

    /// @notice Withdraws USDS from sUSDS and swaps it back to the fleet asset via the Lite PSM
    function _disembark(uint256 amount, bytes calldata) internal override {
        uint256 usdsAmount = amount * TO_18_DECIMALS_CONVERSION_FACTOR;
        stakedUsds.withdraw(usdsAmount, address(this), address(this));
        usds.forceApprove(address(litePsm), usdsAmount);
        litePsm.buyGem(address(this), amount);
    }

    /// @notice Validates the board data (no-op; this Ark requires no board data)
    function _validateBoardData(bytes calldata) internal pure override {}
    /// @notice Validates the disembark data (no-op; this Ark requires no disembark data)
    function _validateDisembarkData(bytes calldata) internal pure override {}

    // No harvest function needed as rewards are automatically compounded in stakedUSDS
    /// @notice No-op harvest: yield is auto-compounded inside the sUSDS vault, so no rewards are claimed
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
