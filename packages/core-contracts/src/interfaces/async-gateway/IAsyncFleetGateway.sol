// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {IERC7540Operator, IERC7540Deposit, IERC7540Redeem} from "./IERC7540.sol";
import {IERC7575Minimal} from "./IERC7575Minimal.sol";
import {IAsyncFleetGatewayEnums} from "./IAsyncFleetGatewayEnums.sol";

/// @notice ERC-7540 asynchronous entry point for an ERC-4626 fleet with an external share token.
interface IAsyncFleetGateway is
    IERC7540Operator,
    IERC7540Deposit,
    IERC7540Redeem,
    IERC7575Minimal,
    IAsyncFleetGatewayEnums
{
    // ---- ERC-4626 verbs kept by ERC-7540 (2-arg claim overloads + redeem-side claims) ----
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets);
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) external returns (uint256 shares);
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) external returns (uint256 assets);

    // ---- ERC-4626 views (async semantics) ----
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function maxDeposit(address controller) external view returns (uint256);
    function maxMint(address controller) external view returns (uint256);
    function maxWithdraw(address controller) external view returns (uint256);
    function maxRedeem(address controller) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);

    // ---- gateway surface ----
    function fleet() external view returns (address);
    function currentDepositEpoch() external view returns (uint256);
    function currentRedeemEpoch() external view returns (uint256);
    function depositEpochState(
        uint256 epoch
    ) external view returns (EpochState);
    function redeemEpochState(uint256 epoch) external view returns (EpochState);
    function depositRate(uint256 epoch) external view returns (Price memory);
    function redeemRate(uint256 epoch) external view returns (Price memory);
    function depositReceiptId(uint256 epoch) external pure returns (uint256);
    function redeemReceiptId(uint256 epoch) external pure returns (uint256);

    // ---- keeper lifecycle ----
    function closeDepositEpoch() external;
    function settleDepositEpoch(uint256 epoch) external;
    function retryDepositEpoch(uint256 epoch) external;
    function closeRedeemEpoch() external;
    function settleRedeemEpoch(uint256 epoch) external;
    function retryRedeemEpoch(uint256 epoch) external;

    // ---- governor emergency ----
    function rollbackDepositEpoch(uint256 epoch) external;
    function rollbackRedeemEpoch(uint256 epoch) external;

    // ---- cancelation (non-standard extension; current open epoch only) ----
    function cancelDepositRequest(
        uint256 assets,
        address receiver,
        address owner
    ) external;
    function cancelRedeemRequest(
        uint256 shares,
        address receiver,
        address owner
    ) external;
}
