// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

import {ArkWithWithdrawalRequest, ArkParams, IArk, Ark, IArkWithWithdrawalRequest} from "../ArkWithWithdrawalRequest.sol";
import {IDepositVault} from "../../interfaces/midas/IDepositVault.sol";
import {IRedemptionVault, Request, RequestStatus} from "../../interfaces/midas/IRedemptionVault.sol";
import {IMidasOracle} from "../../interfaces/midas/IMidasOracle.sol";
import {IMToken} from "../../interfaces/midas/IMToken.sol";
import {TokenConfig} from "../../interfaces/midas/IManageableVault.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error InvalidIssuanceVault();
error InvalidRedemptionVault();
error InvalidOracle();
error InvalidWithdrawalManager();
error InvalidMTokenAddress();
error InvalidDataFeed();
error InvalidMTokenDecimals();

/**
 * @title MidasArk
 * @notice Ark contract for managing token supply and yield generation through Midas vaults
 * @dev Uses separate Issuance Vault for deposits and Redemption Vault for withdrawals
 * @dev Uses oracle to get share price in underlying ark asset
 */
contract MidasArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;
    using SafeERC20 for IDepositVault;
    using SafeERC20 for IRedemptionVault;

    /*//////////////////////////////////////////////////////////////
                           CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice 100 percent with base 100
     * @dev for example, 10% will be (10 * 100)%
     */
    uint256 public constant ONE_HUNDRED_PERCENT = 100 * 100;

    /**
     * @notice Default slippage for the swap
     * @dev 50 is 50% (50/10000)
     */
    uint256 public constant DEFAULT_SLIPPAGE = 50;

    /**
     * @notice Rounding offset for Midas calculations
     */
    uint256 public constant MIDAS_ROUNDING_OFFSET = 1;

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    IDepositVault public immutable issuanceVault;
    IMToken public immutable mToken;
    IRedemptionVault public immutable redemptionVault;
    IMidasOracle public immutable oracle;

    /**
     * @notice The conversion factor from the underlying asset to the mToken
     * @dev e.g. 1e12 is the conversion factor for USDC (mTokens have 18 decimals)
     */
    uint256 public immutable TO_M_TOKEN_DECIMALS;

    /*//////////////////////////////////////////////////////////////
                           MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The request ID for the redemption
    uint256 public withdrawalRequestId;

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the MidasArk
     * @param _issuanceVault Address of the Midas Issuance Vault (for deposits)
     * @param _redemptionVault Address of the Midas Redemption Vault (for withdrawals)
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _issuanceVault,
        address _redemptionVault,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SLIPPAGE) {
        if (_issuanceVault == address(0)) revert InvalidIssuanceVault();
        if (_redemptionVault == address(0)) revert InvalidRedemptionVault();

        issuanceVault = IDepositVault(_issuanceVault);
        redemptionVault = IRedemptionVault(_redemptionVault);

        // Fetch mToken from issuance vault
        IMToken issuanceVaultMToken = issuanceVault.mToken();
        if (address(issuanceVaultMToken) == address(0))
            revert InvalidMTokenAddress();

        mToken = issuanceVaultMToken;
        oracle = IMidasOracle(issuanceVault.mTokenDataFeed());

        // Verify mToken matches redemption vault
        IMToken redemptionVaultMToken = redemptionVault.mToken();
        if (address(redemptionVaultMToken) != address(mToken))
            revert InvalidMTokenAddress();

        // Calculate conversion factor
        uint8 mTokenDecimals = mToken.decimals();
        uint8 assetDecimals = IERC20Metadata(address(config.asset)).decimals();
        if (mTokenDecimals < assetDecimals) revert InvalidMTokenDecimals();

        TO_M_TOKEN_DECIMALS = 10 ** (mTokenDecimals - assetDecimals);
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark
     * @return assets Sum of withdrawable assets, shares in Ark (using oracle), and shares in withdrawal queue
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        assets += _withdrawableTotalAssets();
        assets += assetsInWithdrawalQueue();

        // Add value of shares held by Ark using oracle price
        // Check both issuance and redemption mToken shares (they may use the same share token)
        uint256 shares = mToken.balanceOf(address(this));
        if (shares > 0) {
            uint256 price = oracle.getDataInBase18();
            assets += _sharesToAssets(shares, price);
        }
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (withdrawalRequestId == 0) {
            return 0;
        }

        Request memory request = redemptionVault.redeemRequests(
            withdrawalRequestId
        );
        if (request.status != RequestStatus.Pending) {
            return 0;
        }

        // TODO: check if we need to take into account the `tokenOutRate`
        return _sharesToAssets(request.amountMToken, request.mTokenRate);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Midas processes withdrawals automatically
     */
    function isWithdrawalClaimRequired() public pure returns (bool) {
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL MUTABLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Request redemption of shares from the Midas redemption mToken
     * @param amount Amount of token to withdraw
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        if (withdrawalRequestId > 0) {
            Request memory request = redemptionVault.redeemRequests(
                withdrawalRequestId
            );
            if (request.status == RequestStatus.Pending) {
                revert WithdrawalAlreadyRequested();
            }
        }

        uint256 shares;
        if (amount == type(uint256).max) {
            shares = mToken.balanceOf(address(this));
        } else {
            shares = _assetsToShares(amount);
        }

        mToken.approve(address(redemptionVault), shares);

        uint256 requestId = redemptionVault.redeemRequest(
            address(config.asset),
            shares
        );
        withdrawalRequestId = requestId;

        emit WithdrawalRequested(amount, requestId);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Midas processes withdrawals automatically
     */
    function claimWithdrawal() external onlyKeeper {
        // no-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        uint256 shares = _assetsToShares(amount);
        SwapData memory swapData = abi.decode(data, (SwapData));

        uint256 assetBought = _swap(
            address(address(mToken)),
            address(config.asset),
            swapData.router,
            shares,
            _applySlippage(amount) - MIDAS_ROUNDING_OFFSET,
            swapData.swapCalldata
        );

        emit Disembarked(msg.sender, address(config.asset), amount);
        _boardToBufferArk(assetBought);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Returns the balance of the underlying asset in the Ark
     * @return withdrawableAssets Assets that can be immediately withdrawn
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        // we can only disembark the tokens that have already been processed by the withdrawal manager
        return IERC20(config.asset).balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        uint256 amountScaledTo18Decimals = amount * TO_M_TOKEN_DECIMALS;
        // Calculate minimum receive amount using the oracle price
        uint256 minReceiveAmountInMTokenDecimals = _assetsToShares(amount);

        config.asset.forceApprove(address(issuanceVault), amount);
        issuanceVault.depositInstant(
            address(config.asset),
            amountScaledTo18Decimals,
            minReceiveAmountInMTokenDecimals,
            bytes32(0)
        );
    }

    function _disembark(uint256, bytes calldata) internal override {
        // No-op: disembark is handled by Ark contract implementation
        // Withdrawals must be requested through withdrawal manager
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op as Origin ETH auto-compounds the rewards
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
        // Midas can be claimed permissionlessly, we can use sweep()
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
                           PRIVATE HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts shares to assets using the provided price
     * @param shares Amount of shares to convert
     * @param price Current price from oracle in WAD
     * @return assets Amount of assets equivalent to shares
     */
    function _sharesToAssets(
        uint256 shares,
        uint256 price
    ) internal view returns (uint256) {
        return (shares * price) / (TO_M_TOKEN_DECIMALS * Constants.WAD);
    }

    /**
     * @notice Converts assets to shares using the current oracle price
     * @param assets Amount of assets to convert
     * @return shares Amount of shares equivalent to assets
     */
    function _assetsToShares(uint256 assets) internal view returns (uint256) {
        uint256 price = oracle.getDataInBase18();
        uint256 amountInMTokenDecimals = assets * TO_M_TOKEN_DECIMALS;
        return (amountInMTokenDecimals * Constants.WAD) / price;
    }
}
