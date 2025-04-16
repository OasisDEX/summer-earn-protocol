// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStakingRewards} from "../../interfaces/sky/IStakingRewards.sol";
import {ILitePSM} from "../../interfaces/sky/ILitePSM.sol";

error InvalidLitePsmAddress();
error InvalidUsdsAddress();
error InvalidStakingRewardsAddress();
error InvalidGem();

contract SkyRewardsArk is Ark {
    using SafeERC20 for IERC20;

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
     * @dev SkyRewardsArk is always withdrawable
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

    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(litePsm), amount);
        uint256 usdsAmount = litePsm.sellGem(address(this), amount);
        usds.forceApprove(address(stakingRewards), usdsAmount);
        stakingRewards.stake(usdsAmount, lazySummerReferralCode);
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        // convert from usdc to usds decimals
        uint256 usdsAmount = amount * TO_18_DECIMALS_CONVERSION_FACTOR;
        stakingRewards.withdraw(usdsAmount);
        usds.forceApprove(address(litePsm), usdsAmount);
        litePsm.buyGem(address(this), amount);
    }

    // additional keeper data not needed for SkyRewardsArk
    function _validateBoardData(bytes calldata) internal pure override {}
    function _validateDisembarkData(bytes calldata) internal pure override {}

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
