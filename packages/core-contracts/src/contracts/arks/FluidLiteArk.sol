// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {IEthVaultWrapperV2} from "../../interfaces/fluid/IEthVaultWrapperV2.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWETH} from "../../interfaces/misc/IWETH.sol";
import {ISteth} from "../../interfaces/lido/ISteth.sol";
import {IWithdrawalQueue} from "../../interfaces/lido/IWithdrawalQueue.sol";

/**
 * @title FluidLiteArk
 * @notice Ark contract for managing WETH by staking it into Lido stETH and
 *         depositing the stETH into a FluidLite (ERC4626) vault
 * @dev On board, WETH is unwrapped to ETH, submitted to Lido (stETH), and the
 *      resulting stETH is deposited into the vault. Withdrawals redeem stETH
 *      from the vault and exit either through the Lido withdrawal queue
 *      (requestWithdrawal / claimWithdrawal) or via a swap (withdrawUsingSwap).
 */
contract FluidLiteArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address recorded at construction for the FluidLite ETH vault
    ///         wrapper. Currently assigned but unused: boarding stakes ETH into
    ///         Lido stETH and deposits stETH directly into the vault rather than
    ///         routing through this wrapper.
    IEthVaultWrapperV2 public immutable wrapper;

    /// @notice The ERC4626-compliant vault this Ark interacts with
    IERC4626 public immutable vault;

    /// @notice WETH token address used for wrapping/unwrapping ETH
    IWETH public immutable weth;

    /// @notice StETH token address used for wrapping/unwrapping ETH
    ISteth public immutable steth;

    /// @notice The withdrawal queue used for requesting withdrawals
    IWithdrawalQueue public immutable withdrawalQueue;

    uint256 constant WITHDRAWAL_FEE = 5;

    /// @notice The request id for the withdrawal
    uint256 public withdrawalRequestId;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the supplied wrapper address is the zero address
    error InvalidWrapperAddress();
    /// @notice Thrown when the supplied WETH address is the zero address
    error InvalidWETHAddress();
    /// @notice Thrown when the Ark's configured asset is not the supplied WETH address
    error AssetMustBeWETH();
    /// @notice Thrown when the supplied stETH address is the zero address
    error InvalidStETHAddress();
    /// @notice Thrown when the supplied Lido withdrawal queue address is the zero address
    error InvalidWithdrawalQueueAddress();
    /// @notice Thrown when board authorization data is malformed
    error InvalidAuthData();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the FluidLiteArk
     * @param _wrapper Address of the FluidLite wrapper
     * @param _vault Address of the vault
     * @param _weth Address of the WETH token
     * @param _steth Address of the StETH token
     * @param _withdrawalQueue Address of the withdrawal queue
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _wrapper,
        address _vault,
        address _weth,
        address _steth,
        address _withdrawalQueue,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 15) {
        if (_wrapper == address(0)) revert InvalidWrapperAddress();
        if (_vault == address(0)) revert InvalidVaultAddress();
        if (_weth == address(0)) revert InvalidWETHAddress();
        if (_steth == address(0)) revert InvalidStETHAddress();
        if (address(config.asset) != _weth) revert AssetMustBeWETH();
        if (_withdrawalQueue == address(0))
            revert InvalidWithdrawalQueueAddress();
        wrapper = IEthVaultWrapperV2(_wrapper);
        vault = IERC4626(_vault);
        weth = IWETH(_weth);
        steth = ISteth(_steth);
        withdrawalQueue = IWithdrawalQueue(_withdrawalQueue);
    }

    /*//////////////////////////////////////////////////////////////
                                PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the vault
     * @return assets The total balance of underlying assets in the vault
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        // Get the balance of this contract's shares in the vault
        uint256 shares = vault.balanceOf(address(this));
        if (shares > 0) {
            assets += vault.convertToAssets(shares);
        }

        // Add any WETH balance held in this contract
        assets += config.asset.balanceOf(address(this));
        assets += assetsInWithdrawalQueue();
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (withdrawalRequestId == 0) {
            return 0;
        }
        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = withdrawalRequestId;
        IWithdrawalQueue.WithdrawalRequestStatus[]
            memory status = withdrawalQueue.getWithdrawalStatus(requestIds);
        return status[0].amountOfStETH;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Returns only the WETH currently held directly by this Ark. The vault
     *      position cannot be redeemed synchronously: exiting requires a
     *      keeper-initiated requestWithdrawal through the Lido withdrawal queue
     *      (claimed later) or withdrawUsingSwap, so it is not counted here.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        // Get any currently held WETH
        withdrawableAssets = config.asset.balanceOf(address(this));
    }

    /**
     * @notice Boards WETH by staking it into Lido stETH and depositing into the vault
     * @dev Unwraps WETH to ETH, submits the ETH to Lido (receiving stETH), then
     *      deposits the stETH into the FluidLite ERC4626 vault. Reverts if the
     *      received stETH is insufficient for the vault deposit.
     * @param amount The amount of WETH to deposit
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Unwrap WETH to ETH
        weth.withdraw(amount);

        // Submit ETH to StETH
        steth.submit{value: amount}(address(this));
        IERC20(address(steth)).forceApprove(address(vault), amount);
        // this would fail if amount of steth is not enough
        vault.deposit(amount, address(this));
    }

    /**
     * @notice Withdraws assets from the vault
     * @param amount The amount of WETH to withdraw
     * @param  data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata data) internal override {
        // handled by the Ark.sol
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        if (withdrawalRequestId != 0) revert WithdrawalAlreadyRequested();
        uint256 stethBalanceBefore = steth.balanceOf(address(this));

        if (amount == type(uint256).max) {
            uint256 shares = vault.maxRedeem(address(this));
            vault.redeem(shares, address(this), address(this));
        } else {
            vault.withdraw(amount, address(this), address(this));
        }
        uint256 stethBalanceAfter = steth.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](1);
        uint256 stethAmount = stethBalanceAfter - stethBalanceBefore;
        amounts[0] = stethAmount;

        IERC20(address(steth)).forceApprove(
            address(withdrawalQueue),
            stethAmount
        );
        uint256[] memory requestIds = withdrawalQueue.requestWithdrawals(
            amounts,
            address(this)
        );

        withdrawalRequestId = requestIds[0];

        emit WithdrawalRequested(stethAmount, withdrawalRequestId);
    }

    /**
     * @inheritdoc IArkWithSwap
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper {
        uint256 stethBalanceBefore = steth.balanceOf(address(this));
        vault.withdraw(amount, address(this), address(this));
        uint256 stethWithdrawn = steth.balanceOf(address(this)) -
            stethBalanceBefore;
        uint256 amountAfterFee = amount -
            (amount * WITHDRAWAL_FEE) /
            SLIPPAGE_BASE;

        // adding a 3 wei buffer to account for stETH rounding errors
        if (stethWithdrawn < amountAfterFee - 3) {
            revert WithdrawalFailed();
        }

        SwapData memory swapData = abi.decode(data, (SwapData));
        uint256 assetBought = _swap(
            address(steth),
            address(config.asset),
            swapData.router,
            stethWithdrawn,
            _applySlippage(stethWithdrawn),
            swapData.swapCalldata
        );
        emit Disembarked(msg.sender, address(config.asset), amount);
        _boardToBufferArk(assetBought);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function claimWithdrawal() external onlyKeeper {
        if (withdrawalRequestId == 0) revert NoWithdrawalToClaim();
        uint256 balanceBefore = address(this).balance;
        withdrawalQueue.claimWithdrawal(withdrawalRequestId);
        uint256 balanceAfter = address(this).balance;
        if (balanceAfter > balanceBefore) {
            weth.deposit{value: balanceAfter - balanceBefore}();
        }
        withdrawalRequestId = 0;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function isWithdrawalClaimRequired() public view returns (bool) {
        return withdrawalRequestId != 0;
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op as FluidLite vaults automatically accrue interest
     * @param /// data Additional data (unused in this implementation)
     * @return rewardTokens Empty array as there are no separately harvestable rewards
     * @return rewardAmounts Empty array as there are no separately harvestable rewards
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
     * @dev No-op: boarding does not consume any board data in this implementation
     * @param data Additional data to validate (unused in this implementation)
     */
    function _validateBoardData(bytes calldata data) internal pure override {}

    /**
     * @notice Validates the disembark data
     * @dev No validation needed for disembarking
     * @param  data Additional data to validate (unused in this implementation)
     */
    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {}

    /**
     * @dev Fallback function to accept ETH
     */
    receive() external payable {}
}
