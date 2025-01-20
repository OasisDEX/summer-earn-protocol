// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title ERC4626Ark
 * @notice Ark contract for managing token supply and yield generation through any ERC4626-compliant vault.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and tracking yield from ERC4626 vaults.
 */
contract ERC4626Ark is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The ERC4626-compliant vault this Ark interacts with
    IERC4626 public immutable vault;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the ERC4626Ark
     * @param _vault Address of the ERC4626-compliant vault
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(address _vault, ArkParams memory _params) Ark(_params) {
        if (_vault == address(0)) {
            revert InvalidVaultAddress();
        }

        vault = IERC4626(_vault);

        // Ensure the vault's asset matches the Ark's token
        if (address(vault.asset()) != address(config.asset)) {
            revert ERC4626AssetMismatch();
        }

        // Approve the vault to spend the Ark's tokens
        config.asset.forceApprove(_vault, Constants.MAX_UINT256);
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the ERC4626 vault
     * @return assets The total balance of underlying assets held in the vault for this Ark
     */
    function totalAssets() public view override returns (uint256 assets) {
        uint256 shares = vault.balanceOf(address(this));
        if (shares > 0) {
            assets = vault.convertToAssets(shares);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev ERC4626Ark is always withdrawable
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = vault.balanceOf(address(this));
        if (shares > 0) {
            withdrawableAssets = vault.maxWithdraw(address(this));
        }
    }

    /**
     * @notice Deposits assets into the ERC4626 vault
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        vault.deposit(amount, address(this));
    }

    /**
     * @notice Withdraws assets from the ERC4626 vault
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        vault.withdraw(amount, address(this), address(this));
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op for most ERC4626 vaults as they automatically accrue interest
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
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(0);
        rewardAmounts[0] = 0;
    }

    /**
     * @notice Validates the board data
     * @dev This Ark does not require any validation for board data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateBoardData(bytes calldata) internal override {}

    /**
     * @notice Validates the disembark data
     * @dev This Ark does not require any validation for disembark data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateDisembarkData(bytes calldata) internal override {}
}
