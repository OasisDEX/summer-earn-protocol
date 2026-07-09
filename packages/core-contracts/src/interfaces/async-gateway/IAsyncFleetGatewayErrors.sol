// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAsyncFleetGatewayEnums} from "./IAsyncFleetGatewayEnums.sol";

interface IAsyncFleetGatewayErrors is IAsyncFleetGatewayEnums {
    /// @notice An epoch was not in the state a transition or claim requires.
    error InvalidEpochState(
        uint256 epoch,
        EpochState actual,
        EpochState expected
    );
    /// @notice retry*Epoch may only target past epochs.
    error CannotRetryCurrentEpoch(uint256 epoch, uint256 currentEpoch);
    /// @notice Caller is neither the controller nor an approved ERC-7540 operator.
    error InvalidOperator(address controller, address sender);
    /// @notice Caller may not move `owner`'s request (not owner/operator/ERC-1155-approved).
    error CallerCannotCancel(address caller, address owner);
    /// @notice Claim exceeds the controller's claimable total for that verb.
    error ExceededMaxClaim(address controller, uint256 requested, uint256 max);
    /// @notice Zero-amount request or claim.
    error ZeroAmount();
    /// @notice previewDeposit/previewMint/previewWithdraw/previewRedeem revert per ERC-7540.
    error AsyncFlowPreviewUnsupported();
}
