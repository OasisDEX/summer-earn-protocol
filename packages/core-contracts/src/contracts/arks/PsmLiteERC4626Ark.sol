// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPsmLite} from "../../interfaces/sky/IPsmLite.sol";
import {console} from "forge-std/console.sol";

/**
 * @title PsmLiteERC4626Ark
 * @notice Ark contract that combines PSM Lite with ERC4626 functionality
 * @dev This contract allows users to:
 *      1. Enter with USDC
 *      2. Swap to USDS via PSM Lite
 *      3. Optionally stake in sUSDS vault
 *      4. Deposit in ERC4626 vault
 *
 * The contract supports two modes:
 * - Direct USDS staking: USDC -> USDS -> ERC4626 vault
 * - sUSDS staking: USDC -> USDS -> sUSDS -> ERC4626 vault
 */
contract PsmLiteERC4626Ark is Ark {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC4626;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The LitePSM contract for USDC -> USDS swaps
    IPsmLite public immutable litePsm;
    /// @notice The USDS token contract
    IERC20 public immutable usds;
    /// @notice The susds vault contract
    IERC4626 public immutable susds;
    /// @notice The ERC4626 vault contract
    IERC4626 public immutable erc4626Vault;
    /// @notice Whether to stake USDS in sUSDS vault
    bool public immutable shouldStake;
    /// @notice Conversion factor to convert between 18 decimals and USDC decimals
    uint256 public immutable TO_18_DECIMALS_CONVERSION_FACTOR;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidPSMAddress();
    error InvalidUSDSAddress();
    error InvalidSUSDSAddress();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a new PsmLiteERC4626Ark instance
     * @param _litePsm Address of the PSM Lite contract
     * @param _usds Address of the USDS token
     * @param _susds Address of the sUSDS vault
     * @param _erc4626Vault Address of the ERC4626 vault
     * @param _shouldStake Whether to stake in sUSDS vault
     * @param _params Ark parameters
     */
    constructor(
        address _litePsm,
        address _usds,
        address _susds,
        address _erc4626Vault,
        bool _shouldStake,
        ArkParams memory _params
    ) Ark(_params) {
        if (_litePsm == address(0)) revert InvalidPSMAddress();
        if (_usds == address(0)) revert InvalidUSDSAddress();
        if (_susds == address(0)) revert InvalidSUSDSAddress();
        if (_erc4626Vault == address(0)) revert InvalidVaultAddress();

        litePsm = IPsmLite(_litePsm);
        TO_18_DECIMALS_CONVERSION_FACTOR = litePsm.to18ConversionFactor();
        usds = IERC20(_usds);
        susds = IERC4626(_susds);
        erc4626Vault = IERC4626(_erc4626Vault);
        shouldStake = _shouldStake;

        _validateVaultAsset();
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the total assets in the vault
     * @return assets Total assets in USDC terms
     */
    function totalAssets() public view override returns (uint256 assets) {
        uint256 balance = erc4626Vault.balanceOf(address(this));
        if (balance > 0) {
            assets = erc4626Vault.convertToAssets(balance);
            if (shouldStake) {
                assets =
                    susds.convertToAssets(assets) /
                    TO_18_DECIMALS_CONVERSION_FACTOR;
            } else {
                assets = assets / TO_18_DECIMALS_CONVERSION_FACTOR;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Validates that the vault's asset matches the expected token
     */
    function _validateVaultAsset() internal view {
        address expectedAsset = shouldStake ? address(susds) : address(usds);
        if (address(erc4626Vault.asset()) != expectedAsset) {
            revert ERC4626AssetMismatch();
        }
    }

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @return withdrawableAssets Amount of assets that can be withdrawn
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = erc4626Vault.balanceOf(address(this));
        if (shares > 0) {
            withdrawableAssets = erc4626Vault.maxWithdraw(address(this));
            if (shouldStake) {
                withdrawableAssets =
                    susds.previewWithdraw(withdrawableAssets) /
                    TO_18_DECIMALS_CONVERSION_FACTOR;
            } else {
                withdrawableAssets =
                    withdrawableAssets /
                    TO_18_DECIMALS_CONVERSION_FACTOR;
            }
        }
    }

    /**
     * @notice Handles the boarding process for USDS
     * @param usdsAmount Amount of USDS to deposit
     */
    function _handleUsdsBoarding(uint256 usdsAmount) internal {
        usds.forceApprove(address(erc4626Vault), usdsAmount);
        erc4626Vault.deposit(usdsAmount, address(this));
    }

    /**
     * @notice Handles the boarding process for sUSDS
     * @param usdsAmount Amount of USDS to stake
     */
    function _handleSusdsBoarding(uint256 usdsAmount) internal {
        usds.forceApprove(address(susds), usdsAmount);
        uint256 susdsAmount = susds.deposit(usdsAmount, address(this));
        susds.forceApprove(address(erc4626Vault), susdsAmount);
        erc4626Vault.deposit(susdsAmount, address(this));
    }

    /**
     * @notice Handles the disembarking process for USDS
     * @param usdsAmount Amount of USDS to withdraw
     */
    function _handleUsdsDisembarking(uint256 usdsAmount) internal {
        erc4626Vault.withdraw(usdsAmount, address(this), address(this));
        usds.forceApprove(address(litePsm), usdsAmount);
    }

    /**
     * @notice Handles the disembarking process for sUSDS
     * @param usdsAmount Amount of USDS to withdraw
     */
    function _handleSusdsDisembarking(uint256 usdsAmount) internal {
        uint256 susdsAmount = susds.previewWithdraw(usdsAmount);
        erc4626Vault.withdraw(susdsAmount, address(this), address(this));
        susds.withdraw(usdsAmount, address(this), address(this));
        usds.forceApprove(address(litePsm), usdsAmount);
    }

    /**
     * @notice Handles the boarding process
     * @param amount Amount of USDC to board
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Approve PSM to take USDC
        config.asset.forceApprove(address(litePsm), amount);

        // Swap USDC to USDS
        uint256 usdsAmount = litePsm.sellGem(address(this), amount);

        if (shouldStake) {
            _handleSusdsBoarding(usdsAmount);
        } else {
            _handleUsdsBoarding(usdsAmount);
        }
    }

    /**
     * @notice Handles the disembarking process
     * @param amount Amount of USDC to disembark
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        uint256 usdsAmount = amount * TO_18_DECIMALS_CONVERSION_FACTOR;

        if (shouldStake) {
            _handleSusdsDisembarking(usdsAmount);
        } else {
            _handleUsdsDisembarking(usdsAmount);
        }

        litePsm.buyGem(address(this), amount);
    }

    function _validateBoardData(bytes calldata) internal pure override {}
    function _validateDisembarkData(bytes calldata) internal pure override {}

    /**
     * @notice No harvest function needed as rewards are automatically compounded in susds
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
}
