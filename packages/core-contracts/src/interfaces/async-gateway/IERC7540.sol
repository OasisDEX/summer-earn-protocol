// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @notice Operator management, per ERC-7540. ERC-165 id 0xe3bc4e65.
interface IERC7540Operator {
    /// @notice `controller` set the approval status of `operator` to `approved`.
    event OperatorSet(
        address indexed controller,
        address indexed operator,
        bool approved
    );

    /// @notice Grants or revokes `operator`'s permission to manage Requests for `msg.sender`.
    function setOperator(
        address operator,
        bool approved
    ) external returns (bool success);

    /// @notice Returns true if `operator` is approved as an operator for `controller`.
    function isOperator(
        address controller,
        address operator
    ) external view returns (bool status);
}

/// @notice Asynchronous deposit flow, per ERC-7540. ERC-165 id 0xce3bbe50.
interface IERC7540Deposit {
    /// @notice `owner` locked `assets` to Request a deposit controlled by `controller`.
    event DepositRequest(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 assets
    );

    /// @notice Transfers `assets` from `owner` into the vault and submits a deposit Request.
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external returns (uint256 requestId);

    /// @notice Assets in Pending state for `controller` under `requestId`.
    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 pendingAssets);

    /// @notice Assets in Claimable state for `controller` under `requestId`.
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 claimableAssets);

    /// @notice Claims `assets` worth of shares from `controller`'s Claimable deposit Requests.
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external returns (uint256 shares);

    /// @notice Claims exactly `shares` from `controller`'s Claimable deposit Requests.
    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) external returns (uint256 assets);
}

/// @notice Asynchronous redemption flow, per ERC-7540. ERC-165 id 0x620ee8e4.
interface IERC7540Redeem {
    /// @notice `sender` locked `shares` owned by `owner` to Request a redemption controlled by `controller`.
    event RedeemRequest(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 shares
    );

    /// @notice Assumes control of `shares` from `owner` and submits a redeem Request.
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external returns (uint256 requestId);

    /// @notice Shares in Pending state for `controller` under `requestId`.
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 pendingShares);

    /// @notice Shares in Claimable state for `controller` under `requestId`.
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 claimableShares);
}
