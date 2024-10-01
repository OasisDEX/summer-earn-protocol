// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title ERC4626Ark
 * @dev A generic Ark implementation for any ERC4626-compliant vault
 * @notice This contract allows the Fleet Commander to interact with any ERC4626 vault
 */
contract ERC4626Ark is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The ERC4626 vault this Ark interacts with
    IERC4626 public immutable vault;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Constructor to set up the ERC4626Ark
     * @param _vault Address of the ERC4626-compliant vault
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(address _vault, ArkParams memory _params) Ark(_params) {
        if (_vault == address(0)) {
            revert InvalidVaultAddress();
        }

        vault = IERC4626(_vault);

        // Ensure the vault's asset matches the Ark's token
        if (address(vault.asset()) != address(config.token)) {
            revert ERC4626AssetMismatch();
        }

        // Approve the vault to spend the Ark's tokens
        config.token.approve(_vault, Constants.MAX_UINT256);
    }

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256) {
        return vault.convertToAssets(vault.balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to deposit assets into the vault
     * @param amount The amount of assets to deposit
     */
    function _board(uint256 amount, bytes calldata) internal override {
        vault.deposit(amount, address(this));
    }

    /**
     * @notice Internal function to withdraw assets from the vault
     * @param amount The amount of assets to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        vault.withdraw(amount, address(this), address(this));
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op for most ERC4626 vaults as they automatically accrue interest
     * @return rewardTokens The addresses of the reward tokens
     * @return rewardAmounts The amounts of the reward tokens
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
     * @notice No-op for validateBoardData function
     */
    function _validateBoardData(bytes calldata) internal override {}

    /**
     * @notice No-op for validateDisembarkData function
     */
    function _validateDisembarkData(bytes calldata) internal override {}
}
