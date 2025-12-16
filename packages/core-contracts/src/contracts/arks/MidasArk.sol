// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {IDepositVault} from "../../interfaces/midas/IDepositVault.sol";
import {IRedemptionVault} from "../../interfaces/midas/IRedemptionVault.sol";
import {IMidasOracle} from "../../interfaces/midas/IMidasOracle.sol";
import {Request} from "../../interfaces/midas/IRedemptionVault.sol";
import {IMToken} from "../../interfaces/midas/IMToken.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {TokenConfig} from "../../interfaces/midas/IManageableVault.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {RequestStatus} from "../../interfaces/midas/IRedemptionVault.sol";
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
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IDepositVault public immutable issuanceVault;
    IMToken public immutable mToken;
    IRedemptionVault public immutable redemptionVault;
    IMidasOracle public immutable oracle;
    /// @notice The request ID for the redemption
    uint256 public withdrawalRequestId;

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
     * @notice The conversion factor from the underlying asset to the mToken
     * @dev e.g. 1e12 is the conversion factor for USDC (mTokens have 18 decimals)
     */
    uint256 public immutable TO_M_TOKEN_DECIMALS;

    uint256 public constant MIDAS_ROUNDING_OFFSET = 1;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the MidasArk
     * @param _mToken Address of the Midas mToken (for deposits and withdrawals)
     * @param _issuanceVault Address of the Midas Issuance Vault (for deposits)
     * @param _redemptionVault Address of the Midas Redemption Vault (for withdrawals)
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _mToken,
        address _issuanceVault,
        address _redemptionVault,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SLIPPAGE) {
        if (_mToken == address(0)) revert InvalidVaultAddress();
        if (_issuanceVault == address(0)) revert InvalidIssuanceVault();
        if (_redemptionVault == address(0)) revert InvalidRedemptionVault();

        issuanceVault = IDepositVault(_issuanceVault);
        redemptionVault = IRedemptionVault(_redemptionVault);
        mToken = IMToken(_mToken);
        oracle = IMidasOracle(issuanceVault.mTokenDataFeed());

        IMToken issuanceVaultMToken = issuanceVault.mToken();
        if (address(issuanceVaultMToken) != _mToken)
            revert InvalidMTokenAddress();
        IMToken redemptionVaultMToken = redemptionVault.mToken();
        if (address(redemptionVaultMToken) != _mToken)
            revert InvalidMTokenAddress();

        uint8 mTokenDecimals = mToken.decimals();
        uint8 assetDecimals = IERC20Metadata(address(config.asset)).decimals();
        if (mTokenDecimals < assetDecimals) revert InvalidMTokenDecimals();
        TO_M_TOKEN_DECIMALS = 10 ** (mTokenDecimals - assetDecimals);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
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
        uint256 sharesFromIssuance = mToken.balanceOf(address(this));
        if (sharesFromIssuance > 0) {
            uint256 price = oracle.getDataInBase18();
            uint256 assetsFromShares = (sharesFromIssuance * price) /
                (TO_M_TOKEN_DECIMALS * Constants.WAD);
            assets += assetsFromShares;
        }
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (withdrawalRequestId > 0) {
            Request memory request = redemptionVault.redeemRequests(
                withdrawalRequestId
            );
            if (request.status != RequestStatus.Pending) {
                return 0;
            }
            // Use oracle to convert shares to assets
            // todo: do we need to take into account the `tokenOutRate`?
            return
                (request.amountMToken * request.mTokenRate) /
                (Constants.WAD * TO_M_TOKEN_DECIMALS);
        } else {
            return 0;
        }
    }

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
        uint256 amountIn18Decimals = 0;
        uint256 shares = 0;
        if (amount == type(uint256).max) {
            // Get total shares from both vaults (they may use the same share token)
            shares = mToken.balanceOf(address(this));
        } else {
            amountIn18Decimals = amount * TO_M_TOKEN_DECIMALS;
            // Use oracle to convert assets to shares
            uint256 price = oracle.getDataInBase18();
            uint256 sharesFromAssetsIn18Decimals = (amountIn18Decimals *
                Constants.WAD) / (price);
            shares = sharesFromAssetsIn18Decimals;
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
     * @notice Midas processes withdrawals automatically
     */
    function isWithdrawalClaimRequired() public view returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        // Use oracle to convert assets to shares
        uint256 price = oracle.getDataInBase18();
        uint256 shares = (amount * TO_M_TOKEN_DECIMALS * Constants.WAD) / price;
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
        uint256 price = oracle.getDataInBase18();
        uint256 amountScaledTo18Decimals = amount * TO_M_TOKEN_DECIMALS;
        uint256 minReceiveAmountIn18Decimals = (amountScaledTo18Decimals *
            Constants.WAD) / price;
        config.asset.forceApprove(address(issuanceVault), amount);
        issuanceVault.depositInstant(
            address(config.asset),
            amountScaledTo18Decimals,
            minReceiveAmountIn18Decimals,
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
}
