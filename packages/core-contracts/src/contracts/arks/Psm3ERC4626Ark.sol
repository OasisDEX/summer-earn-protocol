// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPsm3} from "../../interfaces/sky/IPsm3.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Psm3ERC4626Ark
 * @notice Ark contract that combines PSM3 with ERC4626 functionality
 * @dev This contract allows users to:
 *      1. Enter with USDC
 *      2. Swap to sUSDS via PSM3
 *      3. Optionally stake in sUSDS vault
 *      4. Deposit in ERC4626 vault
 *
 * The contract supports two modes:
 * - Direct USDS staking: USDC -> USDS -> ERC4626 vault
 * - sUSDS staking: USDC -> sUSDS -> ERC4626 vault
 */
contract Psm3ERC4626Ark is Ark {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC4626;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The PSM3 contract for USDC <-> sUSDS swaps
    IPsm3 public immutable psm;
    /// @notice The USDS token contract
    IERC20 public immutable usds;
    /// @notice The sUSDS token contract
    IERC20 public immutable susds;
    /// @notice The ERC4626 vault contract
    IERC4626 public immutable erc4626Vault;
    /// @notice Whether to stake USDS in sUSDS vault
    bool public immutable shouldStake;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidPSMAddress();
    error InvalidUSDSAddress();
    error InvalidSUSDSAddress();
    error InvalidGemAddress();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a new Psm3ERC4626Ark instance
     * @param _psm Address of the PSM3 contract
     * @param _usds Address of the USDS token
     * @param _susds Address of the sUSDS token
     * @param _erc4626Vault Address of the ERC4626 vault
     * @param _params Ark parameters
     */
    constructor(
        address _psm,
        address _usds,
        address _susds,
        address _erc4626Vault,
        ArkParams memory _params
    ) Ark(_params) {
        if (_psm == address(0)) revert InvalidPSMAddress();
        if (_usds == address(0)) revert InvalidUSDSAddress();
        if (_susds == address(0)) revert InvalidSUSDSAddress();
        if (_erc4626Vault == address(0)) revert InvalidVaultAddress();

        psm = IPsm3(_psm);
        usds = IERC20(_usds);
        susds = IERC20(_susds);
        erc4626Vault = IERC4626(_erc4626Vault);
        shouldStake = erc4626Vault.asset() == address(susds);

        if (psm.usdc() != _params.asset) revert InvalidGemAddress();
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
            assets = psm.previewSwapExactIn(
                address(shouldStake ? susds : usds),
                address(config.asset),
                assets
            );
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
        uint256 _totalAssets = totalAssets();
        if (_totalAssets > 0) {
            uint256 psmUsdcBalance = config.asset.balanceOf(psm.pocket());
            withdrawableAssets = _totalAssets < psmUsdcBalance
                ? _totalAssets
                : psmUsdcBalance;
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
     * @param susdsAmount Amount of sUSDS to deposit
     */
    function _handleSusdsBoarding(uint256 susdsAmount) internal {
        susds.forceApprove(address(erc4626Vault), susdsAmount);
        erc4626Vault.deposit(susdsAmount, address(this));
    }

    /**
     * @notice Handles the disembarking process for USDS
     * @param usdsAmount Amount of USDS to withdraw
     */
    function _handleUsdsDisembarking(uint256 usdsAmount) internal {
        erc4626Vault.withdraw(usdsAmount, address(this), address(this));
        usds.forceApprove(address(psm), usdsAmount);
    }

    /**
     * @notice Handles the disembarking process for sUSDS
     * @param susdsAmount Amount of sUSDS to withdraw
     */
    function _handleSusdsDisembarking(uint256 susdsAmount) internal {
        erc4626Vault.withdraw(susdsAmount, address(this), address(this));
        susds.forceApprove(address(psm), susdsAmount);
    }

    /**
     * @notice Handles the boarding process
     * @param amount Amount of USDC to board
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Approve PSM to take USDC
        config.asset.forceApprove(address(psm), amount);

        // Preview swap to get expected token amount
        uint256 expectedTokenAmount = psm.previewSwapExactIn(
            address(config.asset),
            address(shouldStake ? susds : usds),
            amount
        );

        // Perform swap with exact output as preview
        uint256 tokenAmount = psm.swapExactIn(
            address(config.asset),
            address(shouldStake ? susds : usds),
            amount,
            expectedTokenAmount,
            address(this),
            0
        );

        if (shouldStake) {
            _handleSusdsBoarding(tokenAmount);
        } else {
            _handleUsdsBoarding(tokenAmount);
        }
    }

    /**
     * @notice Handles the disembarking process
     * @param amount Amount of USDC to disembark
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // Preview swap to get required token amount for desired USDC output
        uint256 tokenNeeded = psm.previewSwapExactOut(
            address(shouldStake ? susds : usds),
            address(config.asset),
            amount
        );

        if (shouldStake) {
            _handleSusdsDisembarking(tokenNeeded);
        } else {
            _handleUsdsDisembarking(tokenNeeded);
        }

        psm.swapExactOut(
            address(shouldStake ? susds : usds),
            address(config.asset),
            amount,
            tokenNeeded,
            address(this),
            0
        );
    }

    function _validateBoardData(bytes calldata) internal pure override {}
    function _validateDisembarkData(bytes calldata) internal pure override {}

    /**
     * @notice No harvest function needed as rewards are automatically compounded in sUSDS
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
