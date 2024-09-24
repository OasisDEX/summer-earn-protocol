// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMetaMorpho} from "metamorpho/interfaces/IMetaMorpho.sol";

/**
 * @title MorphoVaultArk
 * @notice This contract manages a Morpho Vaulttoken strategy within the Ark system
 */
contract MetaMorphoArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Morpho Vault address
    IMetaMorpho public immutable metaMorpho;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for MetaMorphoArk
     * @param _metaMorpho Address of the Morpho Vault
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(address _metaMorpho, ArkParams memory _params) Ark(_params) {
        if (_metaMorpho == address(0)) {
            revert InvalidVaultAddress();
        }
        metaMorpho = IMetaMorpho(_metaMorpho);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256 assets) {
        return metaMorpho.convertToAssets(metaMorpho.balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Boards into the MetaMorpho Vault
     * @param amount The amount of tokens to board
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.token.approve(address(metaMorpho), amount);
        metaMorpho.deposit(amount, address(this));
        this.poke();
    }

    /**
     * @notice Disembarks from the MetaMorpho Vault
     * @param amount The amount of tokens to disembark
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        metaMorpho.withdraw(amount, address(this), address(this));
        this.poke();
    }

    // todo implement
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {}

    /**
     * @notice Validates the board data
     * @dev MetaMorpho Ark does not require any validation for board data
     */
    function _validateBoardData(bytes calldata) internal override {}
    /**
     * @notice Validates the disembark data
     * @dev MetaMorpho Ark does not require any validation for board or disembark data
     */
    function _validateDisembarkData(bytes calldata) internal override {}
}
