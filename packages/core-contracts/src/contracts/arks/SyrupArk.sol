// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {ISyrupPool} from "../../interfaces/syrup/ISyrupPool.sol";
import {ISyrupManager} from "../../interfaces/syrup/ISyrupManager.sol";
import {ISyrupWithdrawalManager} from "../../interfaces/syrup/ISyrupWithdrawalManager.sol";
import {ISyrupRouter} from "../../interfaces/syrup/ISyrupRouter.sol";

error InvalidWithdrawalManager();
error InvalidManager();
error InvalidRouterAddress();

/**
 * @title SyrupArk
 * @notice Ark contract for managing token supply and yield generation through Maple Finance Syrup pools
 * @dev Implements strategy for depositing tokens with signature authorization and managing withdrawals
 */
contract SyrupArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;
    using SafeERC20 for ISyrupPool;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ISyrupPool public immutable vault;
    ISyrupManager public immutable manager;
    ISyrupWithdrawalManager public immutable withdrawalManager;
    ISyrupRouter public immutable router;
    bytes32 public immutable summerReferralCode;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the SyrupArk
     * @param _vault Address of the Syrup pool
     * @param _router Address of the Syrup router
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _vault,
        address _router,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 15) {
        if (_vault == address(0)) revert InvalidVaultAddress();
        if (_router == address(0)) revert InvalidRouterAddress();

        vault = ISyrupPool(_vault);
        router = ISyrupRouter(_router);

        // Validate vault asset matches Ark's asset
        if (address(vault.asset()) != address(config.asset)) {
            revert ERC4626AssetMismatch();
        }

        // Set up and validate manager references
        manager = ISyrupManager(vault.manager());
        withdrawalManager = ISyrupWithdrawalManager(
            manager.withdrawalManager()
        );

        if (address(withdrawalManager) == address(0)) {
            revert InvalidWithdrawalManager();
        }

        // Approve vault to spend Ark's tokens
        config.asset.forceApprove(_vault, Constants.MAX_UINT256);
        summerReferralCode = bytes32("summer");
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark
     * @return assets Sum of withdrawable assets, shares in Ark, and shares in withdrawal queue
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        assets += _withdrawableTotalAssets();
        assets += assetsInWithdrawalQueue();

        // Add value of shares held by Ark
        uint256 sharesInArk = vault.balanceOf(address(this));
        if (sharesInArk > 0) {
            assets += vault.convertToAssets(sharesInArk);
        }
    }

    function assetsInWithdrawalQueue() public view returns (uint256) {
        uint128 withdrawalRequestId = withdrawalManager.requestIds(
            address(this)
        );
        if (withdrawalRequestId == 0) {
            return 0;
        }
        ISyrupWithdrawalManager.WithdrawalRequest
            memory withdrawalRequest = withdrawalManager.requests(
                withdrawalRequestId
            );
        return vault.convertToAssets(withdrawalRequest.shares);
    }

    /**
     * @notice Request redemption of shares from the Syrup pool
     * @param amount Amount of token to withdraw
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        uint256 shares = 0;
        if (amount == type(uint256).max) {
            shares = vault.balanceOf(address(this));
        } else {
            shares = vault.convertToShares(amount);
        }
        vault.requestRedeem(shares, address(this));
    }

    function claimWithdrawal() external onlyKeeper {
        // no-op
    }

    function withdrawalRequestId() external view returns (uint256) {
        return withdrawalManager.requestIds(address(this));
    }

    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        uint256 shares = vault.convertToShares(amount);
        SwapData memory swapData = abi.decode(data, (SwapData));
        uint256 assetBalanceBefore = config.asset.balanceOf(address(this));
        _swap(address(vault), swapData.router, shares, swapData.swapCalldata);
        uint256 assetBalanceAfter = config.asset.balanceOf(address(this));
        uint256 assetBought = assetBalanceAfter - assetBalanceBefore;
        if (_applySlippage(amount) > assetBought) revert WithdrawalFailed();

        _boardToBufferArk(assetBought);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        // we can only disembark the tokens that have already been processed by the withdrawal manager
        return IERC20(vault.asset()).balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        IERC20(vault.asset()).forceApprove(address(router), amount);
        router.deposit(amount, summerReferralCode);
    }

    function _disembark(uint256, bytes calldata) internal override {
        // No-op: disembark is handled by Ark contract implementation
        // Withdrawals must be requested through withdrawal manager
    }

    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // Syrup can be claimed permissionlessly, we can use sweep()
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    function _validateBoardData(bytes calldata) internal override {
        // No additional validation needed
    }

    function _validateDisembarkData(bytes calldata) internal override {}
}
