// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IOriginUSD} from "../../interfaces/origin/IOriginUSD.sol";
import "../ArkWithWithdrawalRequest.sol";

import {IOriginUSDVault} from "../../interfaces/origin/IOriginUSDVault.sol";

/**
 * @title OriginUSDArk
 * @notice Ark contract for managing ETH/USDC deposits into Origin USD protocol
 * @dev Implements strategy for depositing into Origin USD, withdrawing tokens, and tracking yield
 */
contract OriginUSDArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The decimals offset between OUSD (18 decimals) and USDC (6 decimals)
    uint256 private constant DECIMALS_OFFSET = 1e12;

    /// @notice Default slippage for swaps
    uint256 private constant DEFAULT_SLIPPAGE = 15;

    /// @notice The Origin USD contract this Ark interacts with
    IOriginUSD public immutable originUSD;

    /// @notice The Origin USD vault address
    IOriginUSDVault public immutable originUSDVault;

    /// @notice The request ID for the withdrawal
    uint256 public withdrawalRequestId;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the OriginUSDArk
     */
    constructor(
        address _originUSD,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SLIPPAGE) {
        if (_originUSD == address(0)) {
            revert InvalidOriginUSDAddress();
        }

        originUSD = IOriginUSD(_originUSD);

        address vaultAddress = originUSD.vaultAddress();
        if (vaultAddress == address(0)) {
            revert InvalidOriginUSDVaultAddress();
        }

        originUSDVault = IOriginUSDVault(vaultAddress);

        // Origin requires rebase opt-in for smart contracts - otherwise there is no yield
        originUSD.rebaseOptIn();
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the Origin USD protocol
     * @return assets The total balance of underlying assets held in the vault for this Ark,
     *                including any pending withdrawal amounts
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        assets += config.asset.balanceOf(address(this));
        assets += fromOriginDecimals(originUSD.balanceOf(address(this)));
        assets += assetsInWithdrawalQueue();
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (withdrawalRequestId == 0) {
            return 0;
        }
        IOriginUSDVault.WithdrawalRequest
            memory withdrawalRequest = originUSDVault.withdrawalRequests(
                withdrawalRequestId
            );
        return fromOriginDecimals(withdrawalRequest.amount);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        SwapData memory swapData = abi.decode(data, (SwapData));
        uint256 assetBought = _swap(
            address(originUSD),
            address(config.asset),
            swapData.router,
            toOriginDecimals(amount),
            _applySlippage(amount),
            swapData.swapCalldata
        );
        emit Disembarked(msg.sender, address(config.asset), amount);
        _boardToBufferArk(assetBought);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        if (withdrawalRequestId > 0) {
            revert WithdrawalAlreadyRequested();
        }
        uint256 withdrawAmount;
        if (amount == type(uint256).max) {
            withdrawAmount = originUSD.balanceOf(address(this));
        } else {
            withdrawAmount = toOriginDecimals(amount);
        }
        (uint256 requestId, ) = originUSDVault.requestWithdrawal(
            withdrawAmount
        );
        withdrawalRequestId = requestId;
        emit WithdrawalRequested(withdrawAmount, withdrawalRequestId);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function claimWithdrawal() external onlyKeeper {
        if (withdrawalRequestId == 0) {
            revert NoWithdrawalToClaim();
        }
        originUSDVault.claimWithdrawal(withdrawalRequestId);
        withdrawalRequestId = 0;
    }

    function isWithdrawalClaimRequired() public view returns (bool) {
        return withdrawalRequestId != 0;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Returns the sum of the direct asset balance and the redeemable amount from Origin USD
     *      limited by the ARM balance
     * @return withdrawableAssets Assets that can be immediately withdrawn
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        withdrawableAssets = config.asset.balanceOf(address(this));
    }

    /**
     * @notice Deposits assets into the Origin USD protocol
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.approve(address(originUSDVault), amount);
        originUSDVault.mint(address(config.asset), amount, amount);
    }

    /**
     * @notice Withdraws assets from the Origin USD protocol
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {}

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op as Origin USD auto-compounds the rewards
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

    /**
     * @notice Converts an amount to Origin USD decimals
     * @param amount The amount to convert
     * @return The amount in Origin USD decimals
     */
    function toOriginDecimals(uint256 amount) internal pure returns (uint256) {
        return amount * DECIMALS_OFFSET;
    }

    /**
     * @notice Converts an amount from Origin USD decimals
     * @param amount The amount to convert
     * @return The amount in standard decimals
     */
    function fromOriginDecimals(
        uint256 amount
    ) internal pure returns (uint256) {
        return amount / DECIMALS_OFFSET;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the asset in ArkParams doesn't match USDC
    error AssetMismatch();

    /// @notice Error thrown when an invalid Origin USD address is provided
    error InvalidOriginUSDAddress();

    /// @notice Error thrown when there is insufficient asset balance
    error InsufficientAssetBalance();

    /// @notice Error thrown when an invalid Origin USD vault address is provided
    error InvalidOriginUSDVaultAddress();
}
