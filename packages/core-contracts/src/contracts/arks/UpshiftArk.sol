// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUpshiftVault} from "../../interfaces/upshift/IUpshiftVault.sol";
import "../ArkWithWithdrawalRequest.sol";

error PendingWithdrawalExists();
error NotSupported();

/**
 * @title UpshiftArk
 * @notice Ark contract for managing token supply and yield generation through an Upshift TokenizedAccount.
 * @dev Implements strategy for depositing tokens, requesting withdrawals, and claiming if necessary.
 */
contract UpshiftArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IUpshiftVault public immutable vault;

    uint16 public pendingClaimYear;
    uint8 public pendingClaimMonth;
    uint8 public pendingClaimDay;
    bool public hasPendingClaim;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the UpshiftArk
     * @param _vault Address of the Upshift TokenizedAccount
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _vault,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 0) {
        if (_vault == address(0)) revert InvalidVaultAddress();

        vault = IUpshiftVault(_vault);

        // Ensure the vault's asset matches the Ark's token
        if (address(vault.asset()) != address(config.asset)) {
            revert ERC4626AssetMismatch();
        }

        // Approve vault to spend Ark's tokens
        config.asset.forceApprove(_vault, Constants.MAX_UINT256);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark
     * @return assets Sum of withdrawable assets, shares in Ark, and assets in withdrawal queue
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
     * @notice Returns the underlying assets claimable in the pending withdrawal request.
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        return _getClaimableAmount();
    }

    /**
     * @notice Request redemption of shares from the Upshift pool
     * @param amount Amount of token to withdraw
     * @dev Only one withdrawal request can be active at a time to maintain strict atomicity.
     *      A new request can only be submitted once the previous claimable amount drops to 0.
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        // If there is an active pending claim, we cannot request another one.
        // We consider a claim "active" if it still has a non-zero claimable amount.
        // Once the amount drops to 0, it means the operator processed it, and we can overwrite the state.
        uint256 claimable = _getClaimableAmount();
        if (claimable > 0) {
            revert PendingWithdrawalExists();
        }

        uint256 shares = vault.convertToShares(amount);

        // Get the cluster BEFORE requesting redeem
        (uint256 year, uint256 month, uint256 day, ) = vault
            .getWithdrawalEpoch();

        // Request redeem
        vault.requestRedeem(shares, address(this), address(this));

        // Store the state
        pendingClaimYear = uint16(year);
        pendingClaimMonth = uint8(month);
        pendingClaimDay = uint8(day);

        emit WithdrawalRequested(amount, 0);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Claims an existing pending withdrawal
     * @dev As long as the the withdrawal time has passed, the keeper can claim funds that haven't
     *      been processed automatically by the Upshift operator.
     */
    function claimWithdrawal() external onlyKeeper {
        // Note: Upshift vault claim can optionally revert if TooEarly.
        // Keeper should only call this if `isWithdrawalClaimRequired()` is true.
        uint256 claimable = _getClaimableAmount();

        if (claimable > 0) {
            vault.claim(
                pendingClaimYear,
                pendingClaimMonth,
                pendingClaimDay,
                address(this)
            );
        }
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function isWithdrawalClaimRequired() public view returns (bool) {
        uint256 claimable = _getClaimableAmount();

        // If it's already 0, it was processed automatically; no explicit claim required.
        if (claimable == 0) return false;

        // Check if we reached the claimable epoch. Fallback to operator.
        (, uint256 executionEpoch) = vault.getScheduledTransactionsByDate(
            pendingClaimYear,
            pendingClaimMonth,
            pendingClaimDay
        );

        // A 5 minutes buffer is applied internally in Upshift against timestamp manipulation.
        // executionEpoch defines the standard required epoch.
        return block.timestamp >= executionEpoch;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawalRequestId() external pure returns (uint256) {
        return 0; // The UpshiftArk only tracks one active withdrawal at a time, so IDs are not used
    }

    /**
     * @inheritdoc IArkSwapProvider
     */
    function withdrawUsingSwap(uint256, bytes calldata) external pure {
        revert NotSupported();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getClaimableAmount() internal view returns (uint256) {
        return
            vault.getClaimableAmountByReceiver(
                pendingClaimYear,
                pendingClaimMonth,
                pendingClaimDay,
                address(this)
            );
    }

    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        // we can only disembark the tokens that have already been deposited into the Ark directly
        // via a completed claim/transfer. Pending ones are covered by assetsInWithdrawalQueue.
        return config.asset.balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        vault.deposit(amount, address(this));
    }

    function _disembark(uint256, bytes calldata) internal override {
        // No-op: disembark is handled by Ark contract implementation
        // Withdrawals must be requested through keeper
    }

    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    function _validateBoardData(bytes calldata) internal override {}

    function _validateDisembarkData(bytes calldata) internal override {}
}
