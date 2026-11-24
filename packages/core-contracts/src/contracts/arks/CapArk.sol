// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICapToken} from "../../interfaces/cap/ICapToken.sol";
import {IStakedCap} from "../../interfaces/cap/IStakedCap.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {ICapArk} from "../../interfaces/arks/ICapArk.sol";
import {ArkParams} from "../../types/ArkTypes.sol";
import {Ark} from "../Ark.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

/**
 * @title CapArk
 * @notice Ark contract for managing token supply and yield generation through Cap.app (stcUSD).
 */
contract CapArk is Ark, ICapArk {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SLIPPAGE_PRECISION = 10000;
    uint256 public constant DEFAULT_SLIPPAGE = 50; // 0.5%

    uint256 public constant BURN_ESTIMATE_PRECISION = 1000;
    uint256 public constant BURN_ESTIMATE_BUFFER = 1; // 0.1%

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ICapToken public immutable cUSD;
    IStakedCap public immutable stcUSD;
    uint256 public immutable ASSET_DECIMALS;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _cUSD,
        address _stcUSD,
        ArkParams memory _params
    ) Ark(_params) {
        if (_cUSD == address(0)) revert InvalidVaultAddress();
        if (_stcUSD == address(0)) revert InvalidVaultAddress();

        cUSD = ICapToken(_cUSD);
        stcUSD = IStakedCap(_stcUSD);

        config.asset.forceApprove(_cUSD, Constants.MAX_UINT256);
        IERC20(_cUSD).forceApprove(_stcUSD, Constants.MAX_UINT256);

        ASSET_DECIMALS = _getAssetDecimals();
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        uint256 assetBalance = config.asset.balanceOf(address(this));
        uint256 cUSDBalance = cUSD.balanceOf(address(this));
        uint256 stcUSDShares = stcUSD.balanceOf(address(this));

        if (stcUSDShares > 0) {
            cUSDBalance += stcUSD.convertToAssets(stcUSDShares);
        }

        uint256 cUSDValueInAsset = 0;
        if (cUSDBalance > 0) {
            (cUSDValueInAsset, ) = cUSD.getBurnAmount(
                address(config.asset),
                cUSDBalance
            );
        }

        assets = assetBalance + cUSDValueInAsset;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc Ark
     */
    function _board(uint256 amount, bytes calldata) internal override {
        (uint256 expectedCUSD, ) = cUSD.getMintAmount(
            address(this),
            address(config.asset),
            amount
        );
        uint256 minCUSD = (expectedCUSD *
            (SLIPPAGE_PRECISION - DEFAULT_SLIPPAGE)) / SLIPPAGE_PRECISION;

        uint256 cUSDAmount = cUSD.mint(
            address(config.asset),
            amount,
            minCUSD,
            address(this),
            block.timestamp
        );

        stcUSD.deposit(cUSDAmount, address(this));
    }

    /**
     * @inheritdoc Ark
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        uint256 stcUSDSharesBalance = stcUSD.balanceOf(address(this));
        if (stcUSDSharesBalance == 0) return;

        uint256 cUSDToWithdraw;

        if (amount == totalAssets()) {
            cUSDToWithdraw = stcUSD.redeem(
                stcUSDSharesBalance,
                address(this),
                address(this)
            );
        } else {
            uint256 cUSDNeeded = (amount * Constants.WAD) /
                (10 ** ASSET_DECIMALS);

            (uint256 previewAmount, ) = cUSD.getBurnAmount(
                address(config.asset),
                cUSDNeeded
            );

            if (previewAmount < amount) {
                cUSDNeeded = (amount * cUSDNeeded) / previewAmount;
                cUSDNeeded =
                    (cUSDNeeded *
                        (BURN_ESTIMATE_PRECISION + BURN_ESTIMATE_BUFFER)) /
                    BURN_ESTIMATE_PRECISION;
            }

            uint256 sharesToRedeem = stcUSD.convertToShares(cUSDNeeded);
            if (sharesToRedeem > stcUSDSharesBalance) {
                sharesToRedeem = stcUSDSharesBalance;
            }

            cUSDToWithdraw = stcUSD.redeem(
                sharesToRedeem,
                address(this),
                address(this)
            );
        }

        (uint256 expectedAsset, ) = cUSD.getBurnAmount(
            address(config.asset),
            cUSDToWithdraw
        );

        cUSD.burn(
            address(config.asset),
            cUSDToWithdraw,
            expectedAsset,
            address(this),
            block.timestamp
        );
    }

    /**
     * @inheritdoc Ark
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
     * @inheritdoc Ark
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 total = totalAssets();
        if (total == 0) return 0;

        uint256 availableInVault = cUSD.availableBalance(address(config.asset));

        withdrawableAssets = total < availableInVault
            ? total
            : availableInVault;
    }

    function _getAssetDecimals() internal view returns (uint8) {
        return IERC20Metadata(address(config.asset)).decimals();
    }

    function _validateBoardData(bytes calldata) internal pure override {}

    function _validateDisembarkData(bytes calldata) internal pure override {}
}
