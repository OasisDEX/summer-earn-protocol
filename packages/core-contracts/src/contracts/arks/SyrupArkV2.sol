// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISyrupManager} from "../../interfaces/syrup/ISyrupManager.sol";
import {ISyrupPool} from "../../interfaces/syrup/ISyrupPool.sol";
import {ISyrupRouter} from "../../interfaces/syrup/ISyrupRouter.sol";
import {ISyrupWithdrawalManagerV2} from "../../interfaces/syrup/ISyrupWithdrawalManagerV2.sol";
import {IPoolPermissionManager} from "../../interfaces/syrup/IPoolPermissionManager.sol";
import {ArkWithWithdrawalRequest} from "../ArkWithWithdrawalRequest.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {IArkWithSwap} from "../../interfaces/IArkWithSwap.sol";
import {IArkWithWithdrawalRequest} from "../../interfaces/IArkWithWithdrawalRequest.sol";
import {Ark} from "../Ark.sol";
import {ArkParams} from "../../types/ArkTypes.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error InvalidWithdrawalManager();
error InvalidManager();
error InvalidRouterAddress();
error WrongAmountOfSharesReturned();
error AlreadyWhitelisted();
error WhitelistFailed();
error InvalidPoolPermissionManagerAddress();

/**
 * @title SyrupArkV2
 * @notice Ark contract for managing token supply and yield generation through Maple Finance Syrup pools
 * @dev Implements strategy for depositing tokens with signature authorization and managing withdrawals
 */
contract SyrupArkV2 is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;
    using SafeERC20 for ISyrupPool;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ISyrupPool public immutable VAULT;
    ISyrupManager public immutable MANAGER;
    ISyrupWithdrawalManagerV2 public immutable WITHDRAWAL_MANAGER;
    ISyrupRouter public immutable ROUTER;
    bytes32 public immutable SUMMER_REFERRAL_CODE;

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

        VAULT = ISyrupPool(_vault);
        ROUTER = ISyrupRouter(_router);

        // Validate vault asset matches Ark's asset
        if (address(VAULT.asset()) != address(config.asset)) {
            revert ERC4626AssetMismatch();
        }

        // Set up and validate manager references
        MANAGER = ISyrupManager(VAULT.manager());
        WITHDRAWAL_MANAGER = ISyrupWithdrawalManagerV2(
            MANAGER.withdrawalManager()
        );

        if (address(WITHDRAWAL_MANAGER) == address(0)) {
            revert InvalidWithdrawalManager();
        }
        // forge-lint: disable-next-line(unsafe-typecast)
        SUMMER_REFERRAL_CODE = bytes32("0:summer");
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
        uint256 sharesInArk = VAULT.balanceOf(address(this));
        if (sharesInArk > 0) {
            assets += VAULT.convertToExitAssets(sharesInArk);
        }
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        return _assetsInWithdrawalQueue();
    }

    /**
     * @notice Authorizes and deposits assets into the Syrup pool
     * @dev Can only be called once by the keeper when not yet whitelisted. Pulls funds from the keeper.
     */
    function authorizeAndDeposit(
        uint256 bitmap,
        uint256 deadline,
        uint8 authV,
        bytes32 authR,
        bytes32 authS,
        uint256 amount
    ) external onlyKeeper nonReentrant {
        address _poolPermissionManager = ROUTER.poolPermissionManager();
        if (_poolPermissionManager == address(0)) {
            revert InvalidPoolPermissionManagerAddress();
        }

        if (
            IPoolPermissionManager(_poolPermissionManager).hasPermission(
                address(MANAGER),
                address(this),
                "P:deposit"
            )
        ) {
            revert AlreadyWhitelisted();
        }

        // Pull funds from keeper
        IERC20(VAULT.asset()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Approve router
        IERC20(VAULT.asset()).forceApprove(address(ROUTER), amount);

        // Call authorizeAndDeposit on router
        ROUTER.authorizeAndDeposit(
            bitmap,
            deadline,
            authV,
            authR,
            authS,
            amount,
            SUMMER_REFERRAL_CODE
        );

        if (
            !IPoolPermissionManager(_poolPermissionManager).hasPermission(
                address(MANAGER),
                address(this),
                "P:deposit"
            )
        ) {
            revert WhitelistFailed();
        }

        emit Boarded(msg.sender, address(config.asset), amount);
    }

    /**
     * @notice Request redemption of shares from the Syrup pool
     * @dev limited to single request at a time
     * @param amount Amount of token to withdraw
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        if (_withdrawalRequestId() > 0) {
            revert WithdrawalAlreadyRequested();
        }
        uint256 shares = 0;
        if (amount == type(uint256).max) {
            shares = VAULT.balanceOf(address(this));
        } else {
            shares = VAULT.convertToExitShares(amount);
        }
        VAULT.requestRedeem(shares, address(this));
        emit WithdrawalRequested(
            amount,
            WITHDRAWAL_MANAGER.requestIds(address(this))
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
        return _withdrawalRequestId();
    }

    /**
     * @notice Cancels the pending withdrawal request and returns shares to the Ark
     * @dev Uses Maple's pool.removeShares to cancel the request
     */
    function cancelWithdrawal() external onlyKeeper {
        uint256 escrowedShares = WITHDRAWAL_MANAGER.userEscrowedShares(
            address(this)
        );
        if (escrowedShares == 0) {
            revert NoWithdrawalToClaim();
        }
        uint256 returnedShares = VAULT.removeShares(
            escrowedShares,
            address(this)
        );
        if (returnedShares != escrowedShares) {
            revert WrongAmountOfSharesReturned();
        }
        emit WithdrawalCancelled(escrowedShares);
    }

    /**
     * @inheritdoc IArkWithSwap
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        // conservative estimate of shares to withdraw (reflecting market knowledge of unrealized losses)
        uint256 shares = VAULT.convertToExitShares(amount);
        IArkWithSwap.SwapData memory swapData = abi.decode(
            data,
            (IArkWithSwap.SwapData)
        );
        uint256 assetBought = _swap(
            address(VAULT),
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
        return IERC20(VAULT.asset()).balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        IERC20(VAULT.asset()).forceApprove(address(ROUTER), amount);
        ROUTER.deposit(amount, SUMMER_REFERRAL_CODE);
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

    /**
     * @dev Calculates the asset value of shares escrowed in Maple's withdrawal manager.
     *      Uses the exit exchange rate (accounts for unrealizedLosses) to prevent
     *      front-running of impairment events.
     */
    function _assetsInWithdrawalQueue() internal view returns (uint256) {
        uint256 escrowedShares = WITHDRAWAL_MANAGER.userEscrowedShares(
            address(this)
        );
        if (escrowedShares == 0) {
            return 0;
        }
        return VAULT.convertToExitAssets(escrowedShares);
    }

    /**
     * @dev Returns the last withdrawal request ID for this Ark from Maple's queue-based
     *      withdrawal manager. Returns 0 if no pending request exists.
     */
    function _withdrawalRequestId() internal view returns (uint256) {
        return WITHDRAWAL_MANAGER.requestIds(address(this));
    }
}
