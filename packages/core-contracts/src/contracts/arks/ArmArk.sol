// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {IArm} from "../../interfaces/origin/IArm.sol";
import {IWETH} from "../../interfaces/misc/IWETH.sol";

/**
 * @title ArmArk
 * @notice Ark contract for managing ETH deposits into Origin ARM via the ARM contract
 * @dev Implements strategy for depositing ETH through the ARM contract, withdrawing ARM LP shares, and tracking yield
 */
contract ArmArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The ARM contract this Ark interacts with
    IArm public immutable arm;

    /// @notice The WETH contract
    IWETH public immutable weth;

    /// @notice The request ID for the withdrawal
    uint256 public withdrawalRequestId;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the ArmArk
     * @param _arm Address of the ARM contract
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _arm,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 15) {
        if (_arm == address(0)) {
            revert InvalidArmAddress();
        }

        arm = IArm(_arm);
        weth = IWETH(address(_params.asset));
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the ARM protocol
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
        assets += arm.previewRedeem(arm.balanceOf(address(this)));
        assets += assetsInWithdrawalQueue();
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (withdrawalRequestId == 0) {
            return 0;
        }
        IArm.WithdrawalRequest memory withdrawalRequest = arm
            .withdrawalRequests(withdrawalRequestId);
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
            address(arm),
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
        uint256 shares;
        if (amount == type(uint256).max) {
            shares = arm.balanceOf(address(this));
        } else {
            shares = arm.convertToShares(amount);
        }
        (uint256 requestId, ) = arm.requestRedeem(shares);
        withdrawalRequestId = requestId;
        emit WithdrawalRequested(amount, withdrawalRequestId);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice ARM appears to handle withdrawals automatically based on the withdrawal queue
     * @dev This function checks if the withdrawal has been automatically processed and resets the requestId
     */
    function claimWithdrawal() external onlyKeeper {
        if (withdrawalRequestId == 0) {
            revert NoWithdrawalToClaim();
        }
        // arm returns weth - no need to wrap
        arm.claimRedeem(withdrawalRequestId);
        withdrawalRequestId = 0;
    }

    /**
     * @notice Checks if withdrawal claim is required
     * @dev Returns true if there's an active withdrawal request that hasn't been claimed yet
     */
    function isWithdrawalClaimRequired() public view returns (bool) {
        return withdrawalRequestId != 0;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Returns the sum of the direct asset balance
     * @return withdrawableAssets Assets that can be immediately withdrawn by users or rebalanced
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        withdrawableAssets += config.asset.balanceOf(address(this));
    }

    /**
     * @notice Deposits assets into the ARM protocol via the ARM contract
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(arm), amount);
        arm.deposit(amount, address(this));
    }

    /**
     * @notice Withdraws assets from the ARM protocol via swap
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // handeled by disembark method, since only WETH can be disembarked
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev ARM auto-compounds rewards, so this is a no-op
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

    /// @notice Error thrown when an invalid ARM address is provided
    error InvalidArmAddress();
}
