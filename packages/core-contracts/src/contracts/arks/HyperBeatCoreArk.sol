// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

import {ArkWithWithdrawalRequest, ArkParams, IArk, Ark, IArkWithWithdrawalRequest} from "../ArkWithWithdrawalRequest.sol";
import {IHyperBeatDepositor} from "../../interfaces/hyperbeatcore/IHyperBeatDepositor.sol";
import {IHyperBeatWithdrawalQueue, WithdrawalRequest} from "../../interfaces/hyperbeatcore/IHyperBeatWithdrawalQueue.sol";
import {IHyperBeatPricer} from "../../interfaces/hyperbeatcore/IHyperBeatPricer.sol";
import {IHyperBeatVaultToken} from "../../interfaces/hyperbeatcore/IHyperBeatVaultToken.sol";
import {IHyperBeatCoreArkErrors} from "../../interfaces/hyperbeatcore/IHyperBeatCoreArkErrors.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title HyperBeatCoreArk
 * @notice Ark contract for managing token supply and yield generation through HyperBeatCore vaults
 * @dev Uses Depositor for deposits and WithdrawalQueue for withdrawals
 * @dev Uses pricer to get exchange rate in underlying ark asset
 */
contract HyperBeatCoreArk is ArkWithWithdrawalRequest, IHyperBeatCoreArkErrors {
    using SafeERC20 for IERC20;
    using SafeERC20 for IHyperBeatVaultToken;

    /*//////////////////////////////////////////////////////////////
                           CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice 100 percent with base 100
     * @dev for example, 10% will be (10 * 100)%
     */
    uint256 public constant ONE_HUNDRED_PERCENT = 100 * 100;

    /**
     * @notice Default slippage for the swap
     * @dev 50 is 50% (50/10000)
     */
    uint256 public constant DEFAULT_SLIPPAGE = 50;

    /**
     * @notice Rounding offset for HyperBeat calculations
     */
    uint256 public constant HYPERBEAT_ROUNDING_OFFSET = 1;

    /**
     * @notice Basis points denominator (10000 = 100%)
     */
    uint256 public constant BASIS_POINTS = 10000;

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    IHyperBeatDepositor public immutable depositor;
    IHyperBeatVaultToken public immutable vaultToken;
    IHyperBeatWithdrawalQueue public immutable withdrawalQueue;
    IHyperBeatPricer public immutable pricer;

    /**
     * @notice The conversion factor from the underlying asset to the vault token
     * @dev e.g. 1e12 is the conversion factor for USDC (vault tokens have 18 decimals)
     */
    uint256 public immutable TO_VAULT_TOKEN_DECIMALS;

    /*//////////////////////////////////////////////////////////////
                           MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The withdrawal request for tracking pending withdrawals
    WithdrawalRequest public withdrawalRequest;

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the HyperBeatCoreArk
     * @param _depositor Address of the HyperBeat Depositor (for deposits)
     * @param _withdrawalQueue Address of the HyperBeat WithdrawalQueue (for withdrawals)
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _depositor,
        address _withdrawalQueue,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SLIPPAGE) {
        if (_depositor == address(0))
            revert HyperBeatCoreArk__InvalidDepositor();
        if (_withdrawalQueue == address(0))
            revert HyperBeatCoreArk__InvalidWithdrawalQueue();

        depositor = IHyperBeatDepositor(_depositor);
        withdrawalQueue = IHyperBeatWithdrawalQueue(_withdrawalQueue);

        // Fetch vault token from depositor
        address vaultTokenAddress = depositor.vaultToken();
        if (vaultTokenAddress == address(0))
            revert HyperBeatCoreArk__InvalidVaultTokenAddress();

        vaultToken = IHyperBeatVaultToken(vaultTokenAddress);

        // Get pricer from depositor (both depositor and withdrawalQueue should have the same pricer)
        IHyperBeatPricer depositorPricer = depositor.pricer();
        if (address(depositorPricer) == address(0))
            revert HyperBeatCoreArk__InvalidPricer();

        // Verify pricer matches withdrawal queue pricer
        address withdrawalQueuePricer = withdrawalQueue.pricer();
        if (withdrawalQueuePricer != address(depositorPricer))
            revert HyperBeatCoreArk__InvalidPricer();

        pricer = depositorPricer;

        // Verify vault token matches withdrawal queue vault token
        address withdrawalQueueVaultToken = withdrawalQueue.vaultToken();
        if (withdrawalQueueVaultToken != address(vaultToken))
            revert HyperBeatCoreArk__InvalidVaultTokenAddress();

        // Calculate conversion factor
        // Note: Vault tokens have 18 decimals. This check ensures the asset has <= 18 decimals,
        // which is required for the conversion factor calculation. Assets with >18 decimals
        // are extremely rare and not supported by this Ark implementation.
        uint8 vaultTokenDecimals = vaultToken.decimals();
        uint8 assetDecimals = IERC20Metadata(address(config.asset)).decimals();
        if (vaultTokenDecimals < assetDecimals)
            revert HyperBeatCoreArk__InvalidVaultTokenDecimals();

        TO_VAULT_TOKEN_DECIMALS = 10 ** (vaultTokenDecimals - assetDecimals);
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark
     * @return assets Sum of withdrawable assets, shares in Ark (using pricer), and shares in withdrawal queue
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        assets += _withdrawableTotalAssets();
        assets += assetsInWithdrawalQueue();

        // Add value of shares held by Ark using pricer exchange rate
        uint256 shares = vaultToken.balanceOf(address(this));
        if (shares > 0) {
            uint256 exchangeRate = pricer.getRate();
            assets += _sharesToAssets(shares, exchangeRate);
        }
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (withdrawalRequest.nonce == 0) {
            return 0;
        }

        // Check if request is still pending (deadline not passed)
        if (withdrawalRequest.deadline < block.timestamp) {
            return 0;
        }

        // Return the base asset amount from the withdrawal request
        return withdrawalRequest.baseAssetAmount;
    }

    /**
     * @notice Gets the pricer address (similar to oracle() in MidasArk)
     * @dev Returns the pricer address - tests should use pricer.getRate() instead of oracle.getDataInBase18()
     * @return The address of the pricer
     */
    function oracle() external view returns (address) {
        return address(pricer);
    }

    /**
     * @notice Gets the withdrawal request ID (nonce)
     * @dev Returns the nonce of the current withdrawal request, or 0 if no request exists
     * @return The withdrawal request nonce
     */
    function withdrawalRequestId() external view returns (uint256) {
        return withdrawalRequest.nonce;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice HyperBeat processes withdrawals automatically
     */
    function isWithdrawalClaimRequired() public pure returns (bool) {
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL MUTABLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Request redemption of shares from the HyperBeat withdrawal queue
     * @param amount Amount of token to withdraw. A special value of uint256.max can be passed to use the total balance of the vault token that this contract holds
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        if (withdrawalRequest.nonce != 0) {
            // Check if previous request is still pending
            if (withdrawalRequest.deadline >= block.timestamp) {
                revert WithdrawalAlreadyRequested();
            }
        }

        uint256 shares;
        if (amount == type(uint256).max) {
            shares = vaultToken.balanceOf(address(this));
        } else {
            shares = _assetsToShares(amount);
        }

        vaultToken.approve(address(withdrawalQueue), shares);

        // Calculate minimum asset out (with some slippage tolerance)
        uint256 expectedAssetAmount = pricer.getAssetAmount(
            address(config.asset),
            shares
        );
        uint256 minAssetOut = (expectedAssetAmount *
            (BASIS_POINTS - DEFAULT_SLIPPAGE)) / BASIS_POINTS;

        // Create withdrawal request with deadline (minimum deadline + 1 day)
        uint64 deadline = uint64(block.timestamp + 1 days);

        WithdrawalRequest memory request = withdrawalQueue
            .createWithdrawalRequest(
                address(this),
                shares,
                minAssetOut,
                deadline
            );

        withdrawalRequest = request;

        emit WithdrawalRequested(amount, request.nonce);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice HyperBeat processes withdrawals automatically
     */
    function claimWithdrawal() external onlyKeeper {
        // no-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        uint256 shares = _assetsToShares(amount);
        SwapData memory swapData = abi.decode(data, (SwapData));

        uint256 assetBought = _swap(
            address(vaultToken),
            address(config.asset),
            swapData.router,
            shares,
            _applySlippage(amount) - HYPERBEAT_ROUNDING_OFFSET,
            swapData.swapCalldata
        );

        emit Disembarked(msg.sender, address(config.asset), amount);
        _boardToBufferArk(assetBought);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Returns the balance of the underlying asset in the Ark
     * @return withdrawableAssets Assets that can be immediately withdrawn
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        // we can only disembark the tokens that have already been processed by the withdrawal queue
        return IERC20(config.asset).balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        // Calculate vault token amount using pricer
        uint256 vaultTokenAmount = pricer.getVaultTokenAmount(
            address(config.asset),
            amount
        );

        config.asset.forceApprove(address(depositor), amount);
        depositor.deposit(
            address(config.asset),
            address(this),
            amount,
            bytes32(0)
        );
    }

    function _disembark(uint256, bytes calldata) internal override {
        // No-op: disembark is handled by Ark contract implementation
        // Withdrawals must be requested through withdrawal queue
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op as HyperBeat auto-compounds the rewards
     * @param /// data Additional data (unused in this implementation)
     * @return rewardTokens The addresses of the reward tokens (empty array in this case)
     * @return rewardAmounts The amounts of the reward tokens (empty array in this case)
     */
    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // HyperBeat can be claimed permissionlessly, we can use sweep()
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    /**
     * @notice Validates the board data
     * @dev The data can be empty as we don't use additional parameters
     * @param /// data Additional data to validate
     */
    function _validateBoardData(bytes calldata) internal pure override {}

    /**
     * @notice Validates the disembark data
     * @dev The data can be empty as we don't use additional parameters
     * @param /// data Additional data to validate
     */
    function _validateDisembarkData(bytes calldata) internal pure override {}

    /*//////////////////////////////////////////////////////////////
                           PRIVATE HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts shares to assets using the provided exchange rate
     * @param shares Amount of shares (vault tokens) to convert to assets
     * @return assets Amount of assets equivalent to shares
     */
    function _sharesToAssets(
        uint256 shares,
        uint256 /* exchangeRate */
    ) internal view returns (uint256) {
        // Use pricer to convert vault token amount to asset amount
        return pricer.getAssetAmount(address(config.asset), shares);
    }

    /**
     * @notice Converts assets to shares using the current pricer exchange rate
     * @param assets Amount of assets to convert
     * @return shares Amount of shares equivalent to assets
     */
    function _assetsToShares(uint256 assets) internal view returns (uint256) {
        return pricer.getVaultTokenAmount(address(config.asset), assets);
    }
}
