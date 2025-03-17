// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {ISilo} from "../../interfaces/silo/ISilo.sol";
import {ISiloIncentivesController, AccruedRewards} from "../../interfaces/silo/ISiloIncentivesController.sol";
import {ISiloConfig, ConfigData} from "../../interfaces/silo/ISiloConfig.sol";
import {IGaugeHookReceiver} from "../../interfaces/silo/IGaugeHookReceiver.sol";
error InvalidSiloAddress();
error InvalidIncentivesControllerAddress();

/**
 * @title SiloVaultArk
 * @notice Ark contract for managing token supply and yield generation through Silo vaults.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and claiming rewards from Silo vaults.
 */
contract SiloVaultArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Silo this Ark interacts with
    ISilo public immutable silo;

    /// @notice The Silo Incentives Controller for claiming rewards
    ISiloIncentivesController public immutable incentivesController;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the SiloVaultArk
     * @param _silo Address of the silo
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(address _silo, ArkParams memory _params) Ark(_params) {
        if (_silo == address(0)) {
            revert InvalidSiloAddress();
        }

        // Verify that the silo's asset matches the configured asset
        if (ISilo(_silo).asset() != _params.asset) {
            revert ERC4626AssetMismatch();
        }

        silo = ISilo(_silo);

        address _gauge = IGaugeHookReceiver(
            ISiloConfig(silo.siloConfig()).getConfig(_silo).hookReceiver
        ).configuredGauges(_silo);

        if (_gauge == address(0)) {
            revert InvalidGaugeAddress();
        }

        incentivesController = ISiloIncentivesController(_gauge);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the silo
     * @return assets The total balance of underlying assets held in the silo for this Ark
     */
    function totalAssets() public view override returns (uint256 assets) {
        uint256 shares = silo.balanceOf(address(this));
        if (shares > 0) {
            assets = silo.convertToAssets(shares);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev SiloVaultArk is always withdrawable up to maxWithdraw
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = silo.balanceOf(address(this));
        if (shares > 0) {
            withdrawableAssets = silo.maxWithdraw(address(this));
        }
    }

    /**
     * @notice Deposits assets into the silo
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(silo), amount);
        silo.deposit(amount, address(this));
    }

    /**
     * @notice Withdraws assets from the silo
     * @param amount The amount of assets to withdraw
     * @param /// data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        if (amount == totalAssets()) {
            silo.redeem(
                silo.balanceOf(address(this)),
                address(this),
                address(this)
            );
        } else {
            silo.withdraw(amount, address(this), address(this));
        }
    }

    /**
     * @notice Internal function to harvest rewards using the Silo Incentives Controller
     * @dev This function will be implemented to handle Silo-specific reward claiming
     * @return rewardTokens Array of reward token addresses
     * @return rewardAmounts Array of claimed reward amounts
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        AccruedRewards[] memory accruedRewards = incentivesController
            .claimRewards(address(this));
        rewardTokens = new address[](accruedRewards.length);
        rewardAmounts = new uint256[](accruedRewards.length);
        for (uint256 i = 0; i < accruedRewards.length; i++) {
            rewardTokens[i] = accruedRewards[i].rewardToken;
            rewardAmounts[i] = accruedRewards[i].amount;
            if (rewardAmounts[i] > 0) {
                IERC20(rewardTokens[i]).safeTransfer(raft(), rewardAmounts[i]);
            }
        }
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
