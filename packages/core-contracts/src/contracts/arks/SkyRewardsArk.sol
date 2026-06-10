// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStakingRewards} from "../../interfaces/sky/IStakingRewards.sol";
import {ILitePSM} from "../../interfaces/sky/ILitePSM.sol";

/// @notice Thrown when the supplied Lite PSM address is the zero address
error InvalidLitePsmAddress();
/// @notice Thrown when the supplied USDS address is the zero address
error InvalidUsdsAddress();
/// @notice Thrown when the supplied staking rewards address is the zero address
error InvalidStakingRewardsAddress();
/// @notice Thrown when the Lite PSM's gem does not match the Ark's configured asset
error InvalidGem();

/// @title SkyRewardsArk
/// @notice Ark that swaps the fleet asset to USDS via the Lite PSM and stakes
///         the USDS in a Sky StakingRewards contract, harvesting the reward token
contract SkyRewardsArk is Ark {
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
    /// @notice The staking rewards contract
    IStakingRewards public immutable stakingRewards;
    /// @notice the rewards token
    IERC20 public immutable rewardsToken;
    /// @notice Lazy Summer governance referral code
    uint16 public immutable lazySummerReferralCode;

    constructor(
        address _litePsm,
        address _usds,
        address _stakingRewards,
        ArkParams memory _params
    ) Ark(_params) {
        if (_litePsm == address(0)) {
            revert InvalidLitePsmAddress();
        }
        if (_usds == address(0)) {
            revert InvalidUsdsAddress();
        }
        if (_stakingRewards == address(0)) {
            revert InvalidStakingRewardsAddress();
        }
        litePsm = ILitePSM(_litePsm);
        if (litePsm.gem() != _params.asset) {
            revert InvalidGem();
        }
        TO_18_DECIMALS_CONVERSION_FACTOR = litePsm.to18ConversionFactor();
        usds = IERC20(_usds);
        stakingRewards = IStakingRewards(_stakingRewards);
        rewardsToken = stakingRewards.rewardsToken();
        lazySummerReferralCode = 1016;
    }

    function totalAssets() public view override returns (uint256 assets) {
        return _withdrawableTotalAssets();
    }

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Returns the staked USDS balance converted to the fleet asset's
     *      decimals (accrued, unclaimed rewards are intentionally excluded). It
     *      does NOT account for available LitePSM buyGem liquidity, so a
     *      withdrawal can still fail at the PSM step if the PSM lacks gem.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        // we don't treat the accrued rewards as assets
        uint256 balance = stakingRewards.balanceOf(address(this));
        if (balance > 0) {
            withdrawableAssets = balance / TO_18_DECIMALS_CONVERSION_FACTOR;
        }
    }

    /// @notice Swaps the fleet asset to USDS via the Lite PSM and stakes it in the rewards contract
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(litePsm), amount);
        uint256 usdsAmount = litePsm.sellGem(address(this), amount);
        usds.forceApprove(address(stakingRewards), usdsAmount);
        stakingRewards.stake(usdsAmount, lazySummerReferralCode);
    }

    /// @notice Unstakes USDS from the rewards contract and swaps it back to the fleet asset via the Lite PSM
    function _disembark(uint256 amount, bytes calldata) internal override {
        // convert from usdc to usds decimals
        uint256 usdsAmount = amount * TO_18_DECIMALS_CONVERSION_FACTOR;
        stakingRewards.withdraw(usdsAmount);
        usds.forceApprove(address(litePsm), usdsAmount);
        litePsm.buyGem(address(this), amount);
    }

    /// @notice Validates the board data (no-op; this Ark requires no board data)
    function _validateBoardData(bytes calldata) internal pure override {}
    /// @notice Validates the disembark data (no-op; this Ark requires no disembark data)
    function _validateDisembarkData(bytes calldata) internal pure override {}

    /// @notice Claims the staking reward token and forwards it to the raft()
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        uint256 rewardsAmountBeforeClaim = rewardsToken.balanceOf(
            address(this)
        );
        stakingRewards.getReward();
        uint256 rewardsAmountAfterClaim = rewardsToken.balanceOf(address(this));

        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(rewardsToken);
        rewardAmounts[0] = rewardsAmountAfterClaim - rewardsAmountBeforeClaim;
        rewardsToken.safeTransfer(raft(), rewardAmounts[0]);
    }
}
