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
    error Aera__SyncDepositDisabled();
    error Aera__AsyncDepositDisabled();
    error Aera__AsyncRedeemDisabled();
    error Aera__DepositCapExceeded();
    error Aera__MinUnitsOutNotMet();
    error Aera__TokensInZero();
    error Aera__UnitsInZero();
    error Aera__UnitsOutZero();
    error Aera__MinUnitsOutZero();
    error Aera__MaxTokensInZero();
    error Aera__MaxTokensInExceeded();
    error Aera__MaxDepositRefundTimeoutExceeded();
    error Aera__DepositHashNotFound();
    error Aera__HashNotFound();
    error Aera__RefundPeriodExpired();
    error Aera__DeadlineInPast();
    error Aera__DeadlineTooFarInFuture();
    error Aera__DeadlineInFutureAndUnauthorized();
    error Aera__MinTokenOutZero();
    error Aera__HashCollision();
    error Aera__ZeroAddressPriceAndFeeCalculator();
    error Aera__ZeroAddressMultiDepositorVault();
    error Aera__DepositMultiplierTooLow();
    error Aera__DepositMultiplierTooHigh();
    error Aera__RedeemMultiplierTooLow();
    error Aera__RedeemMultiplierTooHigh();
    error Aera__DepositCapZero();
    error Aera__PriceAndFeeCalculatorVaultPaused();
    error Aera__AutoPriceSolveNotAllowed();
    error Aera__FixedPriceSolverTipNotAllowed();
    error Aera__TokenCantBePriced();
    error Aera__CallerIsVault();
    error Aera__InvalidToken();
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

    /// @notice Check if a deposit request is pending
    /// @param hash The hash of the deposit request
    /// @return True if the request is pending, false otherwise
    function asyncDepositHashes(bytes32 hash) external view returns (bool);

    /// @notice Check if a redeem request is pending
    /// @param hash The hash of the redeem request
    /// @return True if the request is pending, false otherwise
    function asyncRedeemHashes(bytes32 hash) external view returns (bool);
}
