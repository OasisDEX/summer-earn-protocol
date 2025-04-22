// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IEthVaultWrapperV2} from "../../interfaces/fluid/IEthVaultWrapperV2.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWETH} from "../../interfaces/misc/IWETH.sol";
import {ISteth} from "../../interfaces/lido/ISteth.sol";

/**
 * @title FluidLiteArk
 * @notice Ark contract for managing ETH/WETH through FluidLite's vault via eth wrapper
 * @dev Implements strategy for depositing/withdrawing ETH/WETH through FluidLite, which requires unwrapping WETH to ETH
 */
contract FluidLiteArk is Ark {
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

    /// @notice base fee to apply to the amount
    uint256 public constant FEE_BASE = 10000;

    /// @notice The fee to apply to the amount
    uint256 public immutable fee;

    /// @notice The slippage to apply to the amount
    uint256 public slippage;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidWrapperAddress();
    error InvalidWETHAddress();
    error AssetMustBeWETH();
    error ETHTransferFailed();
    error InvalidStETHAddress();
    error StETHSubmissionFailed();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the FluidLiteArk
     * @param _wrapper Address of the FluidLite wrapper
     * @param _vault Address of the vault
     * @param _weth Address of the WETH token
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _wrapper,
        address _vault,
        address _weth,
        address _steth,
        ArkParams memory _params
    ) Ark(_params) {
        if (_wrapper == address(0)) revert InvalidWrapperAddress();
        if (_vault == address(0)) revert InvalidVaultAddress();
        if (_weth == address(0)) revert InvalidWETHAddress();
        if (_steth == address(0)) revert InvalidStETHAddress();
        if (address(config.asset) != _weth) revert AssetMustBeWETH();

        wrapper = IEthVaultWrapperV2(_wrapper);
        vault = IERC4626(_vault);
        weth = IWETH(_weth);
        steth = ISteth(_steth);
        fee = 5;
        slippage = 6;
    }

    /*//////////////////////////////////////////////////////////////
                                PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the vault
     * @return assets The total balance of underlying assets in the vault
     */
    function totalAssets() public view override returns (uint256 assets) {
        // Get the balance of this contract's shares in the vault
        uint256 shares = vault.balanceOf(address(this));
        if (shares > 0) {
            assets = vault.convertToAssets(shares);
        }

        // Add any WETH balance held in this contract
        assets += config.asset.balanceOf(address(this));
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

        // Add withdrawable assets from the vault
        uint256 shares = vault.balanceOf(address(this));
        if (shares > 0) {
            withdrawableAssets += vault.maxWithdraw(address(this));
        }
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
        IEthVaultWrapperV2.WithdrawData memory withdrawData = abi.decode(
            data,
            (IEthVaultWrapperV2.WithdrawData)
        );
        vault.approve(address(wrapper), amount);
        wrapper.withdraw(
            withdrawData.route,
            amount,
            withdrawData.swapCalldata,
            applyFeeAndSlippage(amount),
            address(this)
        );
    }

    /**
     * @notice Applies fee and slippage to the amount
     * @param amount The amount to apply fee and slippage to
     * @return The amount after applying fee and slippage
     */
    function applyFeeAndSlippage(
        uint256 amount
    ) internal view returns (uint256) {
        return (amount * (FEE_BASE - fee - slippage)) / FEE_BASE;
    }

    function setSlippage(
        uint256 _slippage
    ) external onlyCurator(config.commander) {
        slippage = _slippage;
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
    function _validateBoardData(bytes calldata data) internal pure override {
        // if (data.length == 0) {
        //     revert InvalidAuthData();
        // }
        // // Try to decode the AuthData to ensure it's properly formatted
        // abi.decode(data, (IEthVaultWrapperV2.DepositData));
    }

    /**
     * @notice Validates the disembark data
     * @dev No validation needed for disembarking
     * @param  data Additional data to validate (unused in this implementation)
     */
    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {
        if (data.length == 0) {
            revert InvalidAuthData();
        }

        // Try to decode the AuthData to ensure it's properly formatted
        abi.decode(data, (IEthVaultWrapperV2.WithdrawData));
    }

    /**
     * @dev Fallback function to accept ETH
     */
    receive() external payable {}

    /**
     * @dev Error for invalid authentication data
     */
    error InvalidAuthData();
}
