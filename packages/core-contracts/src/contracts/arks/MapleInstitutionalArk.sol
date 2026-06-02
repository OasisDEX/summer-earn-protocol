// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISyrupManager} from "../../interfaces/syrup/ISyrupManager.sol";
import {ISyrupPool} from "../../interfaces/syrup/ISyrupPool.sol";
import {ISyrupWithdrawalManagerV2} from "../../interfaces/syrup/ISyrupWithdrawalManagerV2.sol";
import "../ArkWithWithdrawalRequest.sol";

error InvalidWithdrawalManager();
error WrongAmountOfSharesReturned();

/**
 * @title MapleInstitutionalArk
 * @notice Ark contract for managing token supply and yield generation through Maple Finance Institutional pools
 * @dev Implements strategy for direct depositing tokens via IERC4626 and managing withdrawals
 */
contract MapleInstitutionalArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;
    using SafeERC20 for ISyrupPool;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ISyrupPool public immutable vault;
    ISyrupManager public immutable manager;
    ISyrupWithdrawalManagerV2 public immutable withdrawalManager;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the MapleInstitutionalArk
     * @param _vault Address of the Maple Institutional pool
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _vault,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 15) {
        if (_vault == address(0)) revert InvalidVaultAddress();

        vault = ISyrupPool(_vault);

        // Validate vault asset matches Ark's asset
        if (address(vault.asset()) != address(config.asset)) {
            revert ERC4626AssetMismatch();
        }

        // Set up and validate manager references
        manager = ISyrupManager(vault.manager());
        withdrawalManager = ISyrupWithdrawalManagerV2(
            manager.withdrawalManager()
        );

        if (address(withdrawalManager) == address(0)) {
            revert InvalidWithdrawalManager();
        }
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
        assets += _assetsInWithdrawalQueue();

        // Add value of shares held by Ark
        uint256 sharesInArk = vault.balanceOf(address(this));
        if (sharesInArk > 0) {
            assets += vault.convertToExitAssets(sharesInArk);
        }
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        return _assetsInWithdrawalQueue();
    }

    /**
     * @notice Request redemption of shares from the Maple pool
     * @dev limited to single request at a time
     * @param amount Amount of token to withdraw
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        if (_withdrawalRequestId() > 0) {
            revert WithdrawalAlreadyRequested();
        }
        uint256 shares = 0;
        if (amount == type(uint256).max) {
            shares = vault.balanceOf(address(this));
        } else {
            shares = vault.convertToExitShares(amount);
        }
        vault.requestRedeem(shares, address(this));
        emit WithdrawalRequested(amount, _withdrawalRequestId());
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Maple processes withdrawals automatically
     */
    function claimWithdrawal() external onlyKeeper {
        // no-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Maple processes withdrawals automatically
     */
    function isWithdrawalClaimRequired() public view returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawalRequestId() external view returns (uint256) {
        return _withdrawalRequestId();
    }

    /**
     * @notice Cancels the pending withdrawal request and returns shares to the Ark
     * @dev Uses Maple's pool.removeShares to cancel the request
     */
    function cancelWithdrawal() external onlyKeeper {
        uint256 escrowedShares = withdrawalManager.userEscrowedShares(
            address(this)
        );
        if (escrowedShares == 0) {
            revert NoWithdrawalToClaim();
        }
        uint256 returnedShares = vault.removeShares(
            escrowedShares,
            address(this)
        );
        if (returnedShares != escrowedShares) {
            revert WrongAmountOfSharesReturned();
        }
        emit WithdrawalCancelled(escrowedShares);
    }

    /**
     * @inheritdoc IArkSwapProvider
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        // conservative estimate of shares to withdraw (reflecting market knowledge of unrealized losses)
        uint256 shares = vault.convertToExitShares(amount);
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

    /**
     * @dev Returns the underlying asset balance held directly by the Ark.
     *      Only includes tokens already processed by Maple's withdrawal manager
     *      and sent back to the Ark — not shares or escrowed amounts.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return IERC20(vault.asset()).balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        IERC20(vault.asset()).forceApprove(address(vault), amount);
        vault.deposit(amount, address(this));
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
        // Maple can be claimed permissionlessly, we can use sweep()
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    function _validateBoardData(bytes calldata) internal override {
        // No additional validation needed
    }

    function _validateDisembarkData(bytes calldata) internal override {}

    /**
     * @dev Calculates the asset value of shares escrowed in Maple's withdrawal manager.
     *      Uses the exit exchange rate (accounts for unrealizedLosses) to prevent
     *      front-running of impairment events.
     */
    function _assetsInWithdrawalQueue() internal view returns (uint256) {
        uint256 escrowedShares = withdrawalManager.userEscrowedShares(
            address(this)
        );
        if (escrowedShares == 0) {
            return 0;
        }
        return vault.convertToExitAssets(escrowedShares);
    }

    /**
     * @dev Returns the last withdrawal request ID for this Ark from Maple's queue-based
     *      withdrawal manager. Returns 0 if no pending request exists.
     */
    function _withdrawalRequestId() internal view returns (uint256) {
        return withdrawalManager.requestIds(address(this));
    }
}
