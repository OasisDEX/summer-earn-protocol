// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {ISyrupPool} from "../../interfaces/syrup/ISyrupPool.sol";
import {ISyrupManager} from "../../interfaces/syrup/ISyrupManager.sol";
import {ISyrupWithdrawalManager} from "../../interfaces/syrup/ISyrupWithdrawalManager.sol";
import {ISyrupRouter} from "../../interfaces/syrup/ISyrupRouter.sol";

/// @notice Thrown when the pool manager reports a zero withdrawal manager address
error InvalidWithdrawalManager();
/// @notice Thrown when the resolved pool manager address is invalid
error InvalidManager();
/// @notice Thrown when the supplied Syrup router address is the zero address
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

    /// @notice The Syrup pool (ERC4626-style vault) this Ark deposits into
    ISyrupPool public immutable vault;
    /// @notice The Syrup pool manager, used to resolve the withdrawal manager
    ISyrupManager public immutable manager;
    /// @notice The Syrup withdrawal manager that tracks redemption requests
    ISyrupWithdrawalManager public immutable withdrawalManager;
    /// @notice The Syrup router used to deposit with a referral code
    ISyrupRouter public immutable router;
    /// @notice Referral code passed to the Syrup router on deposit
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

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
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
        emit WithdrawalRequested(
            amount,
            withdrawalManager.requestIds(address(this))
        );
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Syrup processes withdrawals automatically
     */
    function claimWithdrawal() external onlyKeeper {
        // no-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Syrup processes withdrawals automatically
     */
    function isWithdrawalClaimRequired() public view returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawalRequestId() external view returns (uint256) {
        return withdrawalManager.requestIds(address(this));
    }

    /**
     * @inheritdoc IArkWithSwap
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        uint256 shares = vault.convertToShares(amount);
        SwapData memory swapData = abi.decode(data, (SwapData));
        uint256 assetBought = _swap(
            address(vault),
            address(config.asset),
            swapData.router,
            shares,
            _applySlippage(amount),
            swapData.swapCalldata
        );
        emit Disembarked(msg.sender, address(config.asset), amount);
        _boardToBufferArk(assetBought);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns only the asset balance already processed by the withdrawal manager and held by the Ark
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        // we can only disembark the tokens that have already been processed by the withdrawal manager
        return IERC20(vault.asset()).balanceOf(address(this));
    }

    /// @notice Deposits the asset into the Syrup pool via the router, passing the referral code
    function _board(uint256 amount, bytes calldata) internal override {
        IERC20(vault.asset()).forceApprove(address(router), amount);
        router.deposit(amount, summerReferralCode);
    }

    /// @notice No-op disembark hook; exits are asynchronous via requestWithdrawal through the withdrawal manager
    function _disembark(uint256, bytes calldata) internal override {
        // No-op: disembark is handled by Ark contract implementation
        // Withdrawals must be requested through withdrawal manager
    }

    /// @notice No-op harvest: the Syrup pool auto-accrues yield, so no rewards are claimed here
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

    /// @notice Validates the board data (no-op; this Ark requires no board data)
    function _validateBoardData(bytes calldata) internal override {
        // No additional validation needed
    }

    /// @notice Validates the disembark data (no-op; this Ark requires no disembark data)
    function _validateDisembarkData(bytes calldata) internal override {}
}
