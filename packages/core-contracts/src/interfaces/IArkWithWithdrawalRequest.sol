// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "./IArk.sol";

/**
 * @title IArkWithWithdrawalRequest
 * @notice Interface for the Ark contract, which manages funds and interacts with Rafts
 * @notice Used for protocols that require a withdrawal request
 * @dev Inherits from IArk for the Ark contract
 */
interface IArkWithWithdrawalRequest is IArk {
    /// @notice Error thrown when a withdrawal has already been requested
    error WithdrawalAlreadyRequested();

    /// @notice Error thrown when there is no withdrawal request
    error NoWithdrawalToClaim();

    /// @notice Error thrown when a withdrawal has failed
    error WithdrawalFailed();

    /**
     * @notice Sweeps all underlying assets from the Ark and boards them to bufferArk
     * @dev This function is only callable by the keeper
     * @dev This function is non-reentrant
     * @return sweptTokens The addresses of the tokens swept
     * @return sweptAmounts The amounts of the tokens swept
     */
    function sweep()
        external
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);

    /**
     * @notice Requests a withdrawal of all underlying assets from the Ark
     * @dev This function is only callable by the keeper
     * @dev This function is non-reentrant
     */
    function requestWithdrawal(uint256 amount) external;

    /**
     * @notice Claims a withdrawal of all underlying assets from the Ark
     * @dev This function is only callable by the keeper
     * @dev This function is non-reentrant
     */
    function claimWithdrawal() external;

    /**
     * @notice Returns the current withdrawal request id
     * @return The current withdrawal request id
     */
    function withdrawalRequestId() external view returns (uint256);

    /**
     * @notice Returns the assets in the withdrawal queue
     * @return The assets in the withdrawal queue
     */
    function assetsInWithdrawalQueue() external view returns (uint256);
}
