// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {IGainVault} from "../../interfaces/highgain/IGainVault.sol";
import {IGainAdapter} from "../../interfaces/highgain/IGainAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {IWETH} from "../../interfaces/misc/IWETH.sol";

error InvalidVaultAddress();
error InvalidAdapterAddress();
error ERC4626AssetMismatch();

/**
 * @title HighGainArk
 * @notice Ark contract for managing token supply and yield generation through HighGain pools (GainLendingPool)
 * @dev Implements strategy for depositing tokens via GainAdapter and managing withdrawals
 */
contract HighGainArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IGainVault public immutable vault;
    IGainAdapter public immutable adapter;
    address public immutable vaultAsset;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the HighGainArk
     * @param _vault Address of the HighGain pool (GainLendingPool)
     * @param _adapter Address of the GainAdapter
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _vault,
        address _adapter,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 15) {
        if (_vault == address(0)) revert InvalidVaultAddress();
        if (_adapter == address(0)) revert InvalidAdapterAddress();

        vault = IGainVault(_vault);
        adapter = IGainAdapter(_adapter);

        vaultAsset = vault.asset();
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
            uint256 rsETHBalance = vault.convertToAssets(sharesInArk);
            assets += adapter.getAssetValueInETH(vaultAsset, rsETHBalance);
        }
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        // HighGain protocol does not expose pending withdrawals value easily
        return 0;
    }

    /**
     * @notice Request redemption of shares from the HighGain pool
     * @param amount Amount of token to withdraw
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        uint256 shares = 0;
        if (amount == type(uint256).max) {
            shares = vault.balanceOf(address(this));
        } else {
            shares = vault.convertToShares(amount);
        }

        IERC20(address(vault)).approve(address(adapter), shares);

        // withdraw in Adapter takes shares
        adapter.withdraw(address(vault), shares, "summer");
        // emit WithdrawalRequested(amount, 0);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function claimWithdrawal() external onlyKeeper {
        // no-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function isWithdrawalClaimRequired() public view returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawalRequestId() external view returns (uint256) {
        return 0;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        uint256 shares = vault.convertToShares(amount);
        SwapData memory swapData = abi.decode(data, (SwapData));

        // Approve router to spend shares
        IERC20(address(vault)).approve(swapData.router, shares);

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

    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return config.asset.balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        // Unwrap WETH to ETH
        IWETH(address(config.asset)).withdraw(amount);
        // Deposit ETH
        adapter.depositETH{value: amount}(address(vault), "summer");
    }

    function _disembark(uint256, bytes calldata) internal override {
        // No-op: disembark is handled by Ark contract implementation via requestWithdrawal or withdrawUsingSwap
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

    function _validateBoardData(bytes calldata) internal override {
        // No additional validation needed
    }

    function _validateDisembarkData(bytes calldata) internal override {}

    /**
     * @notice Receive ETH and wrap it to WETH (unless from WETH contract itself)
     */
    receive() external payable {
        if (msg.sender != address(config.asset)) {
            IWETH(address(config.asset)).deposit{value: msg.value}();
        }
    }
}
