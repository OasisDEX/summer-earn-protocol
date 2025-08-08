// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IStargatePool} from "../../interfaces/stargate/IStargatePool.sol";
import {IStargateStaking} from "../../interfaces/stargate/IStargateStaking.sol";
import {IMultiRewarder} from "../../interfaces/stargate/IMultiRewarder.sol";
import {IWETH} from "../../interfaces/misc/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../../interfaces/IERC20Extended.sol";

/**
 * @title StargateV2PoolArk
 * @notice Ark contract for managing token supply and yield generation through Stargate V2 pools and staking
 * @dev Implements strategy for depositing tokens into Stargate pools, staking LP tokens, and harvesting STG rewards
 */
contract StargateV2PoolArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Stargate pool this Ark interacts with
    IStargatePool public immutable stargatePool;

    /// @notice The Stargate staking contract
    IStargateStaking public immutable stargateStaking;

    /// @notice The LP token from the Stargate pool
    IERC20 public immutable lpToken;

    /// @notice The wrapped native token (WETH) contract
    IWETH public immutable weth;

    /// @notice The convert rate for the Ark
    uint256 public immutable convertRate;

    /// @notice Whether the asset is native ETH
    bool public immutable isNativeAsset;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidAddress(string name, address adr);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the StargateV2PoolArk
     * @param _stargatePool Address of the Stargate pool
     * @param _stargateStaking Address of the Stargate staking contract
     * @param _weth Address of the wrapped native token (WETH) contract
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _stargatePool,
        address _stargateStaking,
        address _weth,
        ArkParams memory _params
    ) Ark(_params) {
        if (_stargatePool == address(0)) {
            revert InvalidAddress("stargatePool", _stargatePool);
        }
        if (_stargateStaking == address(0)) {
            revert InvalidAddress("stargateStaking", _stargateStaking);
        }
        if (_weth == address(0)) {
            revert InvalidAddress("weth", _weth);
        }
        stargatePool = IStargatePool(_stargatePool);
        stargateStaking = IStargateStaking(_stargateStaking);
        lpToken = IERC20(stargatePool.lpToken());
        weth = IWETH(_weth);
        isNativeAsset = address(config.asset) == address(weth);

        // Approve the pool to spend the Ark's tokens
        config.asset.forceApprove(_stargatePool, Constants.MAX_UINT256);

        // Approve the staking contract to spend LP tokens
        lpToken.forceApprove(_stargateStaking, Constants.MAX_UINT256);

        convertRate =
            10 **
                uint256(
                    IERC20Extended(address(config.asset)).decimals() -
                        stargatePool.sharedDecimals()
                );
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the Stargate pool
     * @dev Since Stargate V2 LP tokens are rebasing, the staked balance directly represents underlying assets
     * @return assets The total balance of underlying assets held in the pool for this Ark
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets += stargateStaking.balanceOf(lpToken, address(this));
        assets += config.asset.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev For rebasing tokens, we need to check the maximum withdrawable amount from the pool
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 stakedLpBalance = stargateStaking.balanceOf(
            lpToken,
            address(this)
        );
        if (stakedLpBalance > 0) {
            uint256 poolBalance = stargatePool.redeemable(address(0));
            // Return the minimum of our position or available pool liquidity
            withdrawableAssets = stakedLpBalance > poolBalance
                ? poolBalance
                : stakedLpBalance;
        }
        withdrawableAssets += config.asset.balanceOf(address(this));
    }

    /**
     * @notice Deposits assets into the Stargate pool and stakes the LP tokens
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Remove dust according to shared decimals - dust stays in the ark
        amount = (amount / convertRate) * convertRate;
        if (isNativeAsset) {
            weth.withdraw(amount);
        }
        stargateStaking.deposit(
            lpToken,
            stargatePool.deposit{value: isNativeAsset ? amount : 0}(
                address(this),
                amount
            )
        );
    }

    /**
     * @notice Withdraws assets from the Stargate pool via unstaking and redeeming
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        uint tokenBalanceInArk = config.asset.balanceOf(address(this));
        if (tokenBalanceInArk < amount) {
            uint256 toPull = amount - tokenBalanceInArk;
            if (toPull > 0) {
                stargateStaking.withdraw(lpToken, toPull);
                stargatePool.redeem(toPull, address(this));
                if (isNativeAsset) {
                    weth.deposit{value: toPull}();
                }
            }
        }
    }

    /**
     * @notice Internal function for harvesting rewards from the multi-rewarder
     * @param /// data Additional data (unused in this implementation)
     * @return rewardTokens The addresses of the reward tokens
     * @return rewardAmounts The amounts of the reward tokens harvested
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // Get the rewarder from the staking contract
        IMultiRewarder rewarder = IMultiRewarder(
            address(stargateStaking.rewarder(lpToken))
        );

        // Get expected rewards before claiming
        (address[] memory expectedRewardTokens, ) = rewarder.getRewards(
            lpToken,
            address(this)
        );

        // Record balances before claiming
        uint256[] memory balancesBefore = new uint256[](
            expectedRewardTokens.length
        );
        for (uint256 i = 0; i < expectedRewardTokens.length; i++) {
            if (expectedRewardTokens[i] == address(0)) {
                // Native ETH
                balancesBefore[i] = address(this).balance;
            } else {
                // ERC20 token
                balancesBefore[i] = IERC20(expectedRewardTokens[i]).balanceOf(
                    address(this)
                );
            }
        }

        // Create array with our LP token for claiming
        IERC20[] memory lpTokens = new IERC20[](1);
        lpTokens[0] = lpToken;

        // Claim rewards from staking contract
        stargateStaking.claim(lpTokens);

        // Check actual harvested amounts and count non-zero rewards
        uint256 nonZeroCount = 0;
        uint256[] memory actualHarvested = new uint256[](
            expectedRewardTokens.length
        );

        for (uint256 i = 0; i < expectedRewardTokens.length; i++) {
            uint256 balanceAfter;
            if (expectedRewardTokens[i] == address(0)) {
                // Native ETH - wrap it to WETH
                balanceAfter = address(this).balance;
                uint256 ethHarvested = balanceAfter - balancesBefore[i];
                if (ethHarvested > 0) {
                    // Wrap the ETH to WETH
                    weth.deposit{value: ethHarvested}();
                }
                actualHarvested[i] = ethHarvested;
            } else {
                // ERC20 token
                balanceAfter = IERC20(expectedRewardTokens[i]).balanceOf(
                    address(this)
                );
                actualHarvested[i] = balanceAfter - balancesBefore[i];
            }

            if (actualHarvested[i] > 0) {
                nonZeroCount++;
            }
        }

        // Create return arrays with only non-zero rewards
        rewardTokens = new address[](nonZeroCount);
        rewardAmounts = new uint256[](nonZeroCount);

        uint256 index = 0;
        for (uint256 i = 0; i < expectedRewardTokens.length; i++) {
            if (actualHarvested[i] > 0) {
                // If original token was native ETH (address(0)), return WETH address instead
                rewardTokens[index] = expectedRewardTokens[i] == address(0)
                    ? address(weth)
                    : expectedRewardTokens[i];
                rewardAmounts[index] = actualHarvested[i];
                index++;
            }
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
     * @notice Receive function to handle native ETH rewards
     */
    receive() external payable {}
}
