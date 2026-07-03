// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Request} from "./Types.sol";
import {TokenDetails} from "./Types.sol";

/// @title IProvisioner
/// @notice Interface for the contract that can mint and burn vault units in exchange for tokens
interface IProvisioner {
    /// @notice Emitted when a user deposits tokens directly into the vault
    /// @param user The address of the depositor
    /// @param token The token being deposited
    /// @param tokensIn The amount of tokens deposited
    /// @param unitsOut The amount of units minted
    /// @param depositHash Unique identifier for this deposit
    event Deposited(
        address indexed user,
        IERC20 indexed token,
        uint256 tokensIn,
        uint256 unitsOut,
        bytes32 depositHash
    );

    /// @notice Emitted when a deposit is refunded
    /// @param depositHash The hash of the deposit being refunded
    event DepositRefunded(bytes32 indexed depositHash);

    /// @notice Emitted when a direct (sync) deposit is refunded
    /// @param depositHash The hash of the deposit being refunded
    event DirectDepositRefunded(bytes32 indexed depositHash);

    /// @notice Emitted when a user creates a deposit request
    /// @param user The address requesting the deposit
    /// @param token The token being deposited
    /// @param tokensIn The amount of tokens to deposit
    /// @param minUnitsOut The minimum amount of units expected
    /// @param solverTip The tip offered to the solver in deposit token terms
    /// @param deadline Timestamp until which the request is valid
    /// @param maxPriceAge Maximum age of price data that solver can use
    /// @param isFixedPrice Whether the request is a fixed price request
    /// @param depositRequestHash The hash of the deposit request
    event DepositRequested(
        address indexed user,
        IERC20 indexed token,
        uint256 tokensIn,
        uint256 minUnitsOut,
        uint256 solverTip,
        uint256 deadline,
        uint256 maxPriceAge,
        bool isFixedPrice,
        bytes32 depositRequestHash
    );

    /// @notice Emitted when a user creates a redeem request
    /// @param user The address requesting the redemption
    /// @param token The token requested in return for units
    /// @param minTokensOut The minimum amount of tokens the user expects to receive
    /// @param unitsIn The amount of units being redeemed
    /// @param solverTip The tip offered to the solver in redeem token terms
    /// @param deadline The timestamp until which this request is valid
    /// @param maxPriceAge Maximum age of price data that solver can use
    /// @param isFixedPrice Whether the request is a fixed price request
    /// @param redeemRequestHash The hash of the redeem request
    event RedeemRequested(
        address indexed user,
        IERC20 indexed token,
        uint256 minTokensOut,
        uint256 unitsIn,
        uint256 solverTip,
        uint256 deadline,
        uint256 maxPriceAge,
        bool isFixedPrice,
        bytes32 redeemRequestHash
    );

    /// @notice Emitted when a deposit request is solved successfully
    /// @param depositHash The unique identifier of the deposit request that was solved
    event DepositSolved(bytes32 indexed depositHash);

    /// @notice Emitted when a redeem request is solved successfully
    /// @param redeemHash The unique identifier of the redeem request that was solved
    event RedeemSolved(bytes32 indexed redeemHash);

    /// @notice Emitted when an unrecognized async deposit hash is used
    /// @param depositHash The deposit hash that was not found in async records
    event InvalidRequestHash(bytes32 indexed depositHash);

    /// @notice Emitted when async deposits are disabled and a deposit request cannot be processed
    /// @param index The index of the deposit request that was rejected
    event AsyncDepositDisabled(uint256 indexed index);

    /// @notice Emitted when async redeems are disabled and a redeem request cannot be processed
    /// @param index The index of the redeem request that was rejected
    event AsyncRedeemDisabled(uint256 indexed index);

    /// @notice Emitted when the price age exceeds the maximum allowed for a request
    /// @param index The index of the request that was rejected
    event PriceAgeExceeded(uint256 indexed index);

    /// @notice Emitted when a deposit exceeds the vault's configured deposit cap
    /// @param index The index of the request that was rejected
    event DepositCapExceeded(uint256 indexed index);

    /// @notice Emitted when there are not enough tokens to cover the required solver tip
    /// @param index The index of the request that was rejected
    event InsufficientTokensForTip(uint256 indexed index);

    /// @notice Emitted when the output units are less than the amount requested
    /// @param index The index of the request that was rejected
    /// @param amount The actual amount
    /// @param bound The minimum amount
    event AmountBoundExceeded(
        uint256 indexed index,
        uint256 amount,
        uint256 bound
    );

    /// @notice Emitted when a redeem request is refunded due to expiration or cancellation
    /// @param redeemHash The unique identifier of the redeem request that was refunded
    event RedeemRefunded(bytes32 indexed redeemHash);

    /// @notice Emitted when the vault's deposit limits are updated
    /// @param depositCap The new maximum total value that can be deposited into the vault
    /// @param depositRefundTimeout The new time window during which deposits can be refunded
    event DepositDetailsUpdated(
        uint256 depositCap,
        uint256 depositRefundTimeout
    );

    /// @notice Emitted when a token's deposit/withdrawal settings are updated
    /// @param token The token whose settings are being updated
    /// @param tokensDetails The new token details
    event TokenDetailsSet(IERC20 indexed token, TokenDetails tokensDetails);

    /// @notice Emitted when a token is removed from the provisioner
    /// @param token The token that was removed
    event TokenRemoved(IERC20 indexed token);
    /// @notice Thrown when a synchronous (direct) deposit is attempted while sync deposits are disabled
    error Aera__SyncDepositDisabled();
    /// @notice Thrown when an async deposit request is attempted while async deposits are disabled
    error Aera__AsyncDepositDisabled();
    /// @notice Thrown when an async redeem request is attempted while async redeems are disabled
    error Aera__AsyncRedeemDisabled();
    /// @notice Thrown when a deposit would exceed the vault deposit cap
    error Aera__DepositCapExceeded();
    /// @notice Thrown when the minted units are below the requested minimum
    error Aera__MinUnitsOutNotMet();
    /// @notice Thrown when the tokens-in amount is zero
    error Aera__TokensInZero();
    /// @notice Thrown when the units-in amount is zero
    error Aera__UnitsInZero();
    /// @notice Thrown when the units-out amount is zero
    error Aera__UnitsOutZero();
    /// @notice Thrown when the minimum units-out is zero
    error Aera__MinUnitsOutZero();
    /// @notice Thrown when the maximum tokens-in is zero
    error Aera__MaxTokensInZero();
    /// @notice Thrown when the tokens required exceed the caller-specified maximum
    error Aera__MaxTokensInExceeded();
    /// @notice Thrown when the configured deposit refund timeout exceeds the allowed maximum
    error Aera__MaxDepositRefundTimeoutExceeded();
    /// @notice Thrown when the referenced deposit hash does not exist
    error Aera__DepositHashNotFound();
    /// @notice Thrown when the referenced request hash does not exist
    error Aera__HashNotFound();
    /// @notice Thrown when a refund is attempted after the refund period has expired
    error Aera__RefundPeriodExpired();
    /// @notice Thrown when the supplied deadline is in the past
    error Aera__DeadlineInPast();
    /// @notice Thrown when the supplied deadline is too far in the future
    error Aera__DeadlineTooFarInFuture();
    /// @notice Thrown when the deadline is in the future and the caller is not authorized to act early
    error Aera__DeadlineInFutureAndUnauthorized();
    /// @notice Thrown when the minimum tokens-out is zero
    error Aera__MinTokenOutZero();
    /// @notice Thrown when a computed request hash collides with an existing one
    error Aera__HashCollision();
    /// @notice Thrown when the price and fee calculator address is the zero address
    error Aera__ZeroAddressPriceAndFeeCalculator();
    /// @notice Thrown when the MultiDepositorVault address is the zero address
    error Aera__ZeroAddressMultiDepositorVault();
    /// @notice Thrown when the deposit multiplier is below the allowed minimum
    error Aera__DepositMultiplierTooLow();
    /// @notice Thrown when the deposit multiplier is above the allowed maximum
    error Aera__DepositMultiplierTooHigh();
    /// @notice Thrown when the redeem multiplier is below the allowed minimum
    error Aera__RedeemMultiplierTooLow();
    /// @notice Thrown when the redeem multiplier is above the allowed maximum
    error Aera__RedeemMultiplierTooHigh();
    /// @notice Thrown when the deposit cap is set to zero
    error Aera__DepositCapZero();
    /// @notice Thrown when the price and fee calculator reports the vault as paused
    error Aera__PriceAndFeeCalculatorVaultPaused();
    /// @notice Thrown when an auto-price solve is attempted but not allowed for the request
    error Aera__AutoPriceSolveNotAllowed();
    /// @notice Thrown when a solver tip is supplied for a fixed-price request, which is not allowed
    error Aera__FixedPriceSolverTipNotAllowed();
    /// @notice Thrown when the token cannot be priced by the calculator
    error Aera__TokenCantBePriced();
    /// @notice Thrown when the caller is the vault, which is not permitted for this action
    error Aera__CallerIsVault();
    /// @notice Thrown when the supplied token is not supported by the provisioner
    error Aera__InvalidToken();
    ////////////////////////////////////////////////////////////
    //                         Functions                      //
    ////////////////////////////////////////////////////////////
    /// @notice Returns the address of the MultiDepositorVault this provisioner serves
    /// @return The MultiDepositorVault address
    function MULTI_DEPOSITOR_VAULT() external view returns (address);
    /// @notice Returns the address of the price and fee calculator
    /// @return The PriceAndFeeCalculator address
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
    /// @param isFixedPrice Whether the request is a fixed price request
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

    /// @notice Check if a deposit request is pending
    /// @param hash The hash of the deposit request
    /// @return True if the request is pending, false otherwise
    function asyncDepositHashes(bytes32 hash) external view returns (bool);

    /// @notice Check if a redeem request is pending
    /// @param hash The hash of the redeem request
    /// @return True if the request is pending, false otherwise
    function asyncRedeemHashes(bytes32 hash) external view returns (bool);
}
