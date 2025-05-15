// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {IOriginETH} from "../../interfaces/origin/IOriginETH.sol";
import {IArm} from "../../interfaces/origin/IArm.sol";
import {IOriginETHVault} from "../../interfaces/origin/IOriginETHVault.sol";

/**
 * @title OriginSuperOETHArk
 * @notice Ark contract for managing ETH/WETH deposits into Origin ETH protocol
 * @dev Implements strategy for depositing into Origin ETH, withdrawing tokens, and tracking yield
 */
contract OriginSuperOETHArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Origin ETH contract this Ark interacts with
    IOriginETH public immutable originETH;

    /// @notice The ARM contract this Ark interacts with
    IArm public immutable arm;

    /// @notice The Origin ETH vault address
    IOriginETHVault public immutable originETHVault;

    /// @notice The request ID for the withdrawal
    uint256 public withdrawalRequestId;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the OriginETHArk
     * @param _originETH Address of the OriginETH contract
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _originETH,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 15) {
        if (_originETH == address(0)) {
            revert InvalidOriginETHAddress();
        }

        originETH = IOriginETH(_originETH);

        address vaultAddress = originETH.vaultAddress();
        if (vaultAddress == address(0)) {
            revert InvalidOriginETHVaultAddress();
        }

        originETHVault = IOriginETHVault(vaultAddress);
        originETH.rebaseOptIn();
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the Origin ETH protocol
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
        assets += originETH.balanceOf(address(this));
        assets += assetsInWithdrawalQueue();
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (withdrawalRequestId == 0) {
            return 0;
        }
        IOriginETHVault.WithdrawalRequest
            memory withdrawalRequest = originETHVault.withdrawalRequests(
                withdrawalRequestId
            );
        return withdrawalRequest.amount;
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
            address(originETH),
            address(config.asset),
            swapData.router,
            amount,
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
        if (amount == type(uint256).max) {
            amount = originETH.balanceOf(address(this));
        }
        (uint256 requestId, ) = originETHVault.requestWithdrawal(amount);
        withdrawalRequestId = requestId;
        emit WithdrawalRequested(amount, withdrawalRequestId);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function claimWithdrawal() external onlyKeeper {
        if (withdrawalRequestId == 0) {
            revert NoWithdrawalToClaim();
        }
        originETHVault.claimWithdrawal(withdrawalRequestId);
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
     * @dev Returns the sum of the direct asset balance and the redeemable amount from Origin ETH
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
     * @notice Deposits assets into the Origin ETH protocol
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.approve(address(originETHVault), amount);
        originETHVault.mint(address(config.asset), amount, amount);
    }

    /**
     * @notice Withdraws assets from the Origin ETH protocol
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // handled by Ark.sol
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op as Origin ETH auto-compounds the rewards
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

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the asset in ArkParams doesn't match WETH
    error AssetMismatch();

    /// @notice Error thrown when an invalid Origin ETH address is provided
    error InvalidOriginETHAddress();

    /// @notice Error thrown when an invalid Origin ETH vault address is provided
    error InvalidOriginETHVaultAddress();
}
