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
 * @notice Ark contract for managing ETH/WETH through FluidLite's vault via eth wrapper
 * @dev Implements strategy for depositing/withdrawing ETH/WETH through FluidLite, which requires unwrapping WETH to ETH
 */
contract FluidLiteArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Eth Wrapper used for depositing into the vault
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

    error InvalidWrapperAddress();
    error InvalidWETHAddress();
    error AssetMustBeWETH();
    error InvalidStETHAddress();
    error InvalidWithdrawalQueueAddress();
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
     * @dev FluidLiteArk stores value in shares of the vault plus any WETH held directly
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
     * @notice Deposits WETH into the vault through the router
     * @dev Unwraps WETH to ETH first, then deposits via the router
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
     * @inheritdoc IArkWithWithdrawalRequest
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
     * @dev Ensures the AuthData is properly encoded
     * @param data AuthData containing signature for deposit authorization
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
