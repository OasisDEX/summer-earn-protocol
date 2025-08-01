// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @title IProvisioner
/// @notice Interface for the contract that can mint and burn vault units in exchange for tokens
interface IProvisioner {
    ////////////////////////////////////////////////////////////
    //                         Functions                      //
    ////////////////////////////////////////////////////////////
    function MULTI_DEPOSITOR_VAULT() external view returns (address);
    function PRICE_FEE_CALCULATOR() external view returns (address);
    /// @notice Deposit tokens directly into the vault
    /// @param token The token to deposit
    /// @param tokensIn The amount of tokens to deposit
    /// @param minUnitsOut The minimum amount of units expected
    /// @dev MUST revert if tokensIn is 0, minUnitsOut is 0, or sync deposits are disabled
    /// @return unitsOut The amount of shares minted to the receiver
    function deposit(
        IERC20 token,
        uint256 tokensIn,
        uint256 minUnitsOut
    ) external returns (uint256 unitsOut);

    /// @notice Mint exact amount of units by depositing required tokens
    /// @param token The token to deposit
    /// @param unitsOut The exact amount of units to mint
    /// @param maxTokensIn Maximum amount of tokens willing to deposit
    /// @return tokensIn The amount of tokens used to mint the requested shares
    function mint(
        IERC20 token,
        uint256 unitsOut,
        uint256 maxTokensIn
    ) external returns (uint256 tokensIn);

    /// @notice Refund a deposit within the refund period
    /// @param sender The original depositor
    /// @param token The deposited token
    /// @param tokenAmount The amount of tokens deposited
    /// @param unitsAmount The amount of units minted
    /// @param refundableUntil Timestamp until which refund is possible
    /// @dev Only callable by authorized addresses
    function refundDeposit(
        address sender,
        IERC20 token,
        uint256 tokenAmount,
        uint256 unitsAmount,
        uint256 refundableUntil
    ) external;

    /// @notice Refund an expired deposit or redeem request
    /// @param token The token involved in the request
    /// @param request The request to refund
    /// @dev Can only be called after request deadline has passed
    function refundRequest(IERC20 token, Request calldata request) external;

    /// @notice Create a new deposit request to be solved by solvers
    /// @param token The token to deposit
    /// @param tokensIn The amount of tokens to deposit
    /// @param minUnitsOut The minimum amount of units expected
    /// @param solverTip The tip offered to the solver
    /// @param deadline Duration in seconds for which the request is valid
    /// @param maxPriceAge Maximum age of price data that solver can use
    /// @param isFixedPrice Whether the request is a fixed price request
    function requestDeposit(
        IERC20 token,
        uint256 tokensIn,
        uint256 minUnitsOut,
        uint256 solverTip,
        uint256 deadline,
        uint256 maxPriceAge,
        bool isFixedPrice
    ) external;

    /// @notice Create a new redeem request to be solved by solvers
    /// @param token The token to receive
    /// @param unitsIn The amount of units to redeem
    /// @param minTokensOut The minimum amount of tokens expected
    /// @param solverTip The tip offered to the solver
    /// @param deadline Duration in seconds for which the request is valid
    /// @param maxPriceAge Maximum age of price data that solver can use
    function requestRedeem(
        IERC20 token,
        uint256 unitsIn,
        uint256 minTokensOut,
        uint256 solverTip,
        uint256 deadline,
        uint256 maxPriceAge,
        bool isFixedPrice
    ) external;

    /// @notice Solve multiple requests using vault's liquidity
    /// @param token The token for which to solve requests
    /// @param requests Array of requests to solve
    /// @dev Only callable by authorized addresses
    function solveRequestsVault(
        IERC20 token,
        Request[] calldata requests
    ) external;

    /// @notice Solve multiple requests using solver's own liquidity
    /// @param token The token for which to solve requests
    /// @param requests Array of requests to solve
    function solveRequestsDirect(
        IERC20 token,
        Request[] calldata requests
    ) external;

    /// @notice Update token parameters
    /// @param token The token to update
    /// @param tokensDetails The new token details
    function setTokenDetails(
        IERC20 token,
        TokenDetails calldata tokensDetails
    ) external;

    /// @notice Removes token from provisioner
    /// @param token The token to be removed
    function removeToken(IERC20 token) external;

    /// @notice Update deposit parameters
    /// @param depositCap_ New maximum total value that can be deposited
    /// @param depositRefundTimeout_ New time window for deposit refunds
    function setDepositDetails(
        uint256 depositCap_,
        uint256 depositRefundTimeout_
    ) external;

    /// @notice Return maximum amount that can still be deposited
    /// @return Amount of deposit capacity remaining
    function maxDeposit() external view returns (uint256);

    /// @notice Check if a user's units are currently locked
    /// @param user The address to check
    /// @return True if user's units are locked, false otherwise
    function areUserUnitsLocked(address user) external view returns (bool);

    /// @notice Computes the hash for a sync deposit
    /// @param user The address making the deposit
    /// @param token The token being deposited
    /// @param tokenAmount The amount of tokens to deposit
    /// @param unitsAmount Minimum amount of units to receive
    /// @param refundableUntil The timestamp until which the deposit is refundable
    /// @return The hash of the deposit
    function getDepositHash(
        address user,
        IERC20 token,
        uint256 tokenAmount,
        uint256 unitsAmount,
        uint256 refundableUntil
    ) external pure returns (bytes32);

    /// @notice Computes the hash for a generic request
    /// @param token The token involved in the request
    /// @param request The request struct
    /// @return The hash of the request
    function getRequestHash(
        IERC20 token,
        Request calldata request
    ) external pure returns (bytes32);
}
