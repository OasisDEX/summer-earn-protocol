pragma solidity 0.8.28;

/**
 * @title IMToken
 * @notice Minimal interface for a Moonwell/Compound-style market token (mToken)
 */
interface IMToken {
    /*** User Interface ***/

    /// @notice Supplies underlying to the market and mints mTokens to the caller
    /// @param mintAmount The amount of underlying to supply
    /// @return An error code (0 on success)
    function mint(uint mintAmount) external returns (uint);
    /// @notice Supplies underlying using an EIP-2612 permit to approve the transfer
    /// @param mintAmount The amount of underlying to supply
    /// @param deadline The permit deadline
    /// @param v The permit signature v component
    /// @param r The permit signature r component
    /// @param s The permit signature s component
    /// @return An error code (0 on success)
    function mintWithPermit(
        uint mintAmount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint);
    /// @notice Redeems mTokens in exchange for the underlying asset
    /// @param redeemTokens The number of mTokens to redeem
    /// @return An error code (0 on success)
    function redeem(uint redeemTokens) external returns (uint);
    /// @notice Redeems mTokens in exchange for a specified amount of underlying
    /// @param redeemAmount The amount of underlying to receive
    /// @return An error code (0 on success)
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    /// @notice Borrows underlying from the market
    /// @param borrowAmount The amount of underlying to borrow
    /// @return An error code (0 on success)
    function borrow(uint borrowAmount) external returns (uint);
    /// @notice Repays the caller's own borrow
    /// @param repayAmount The amount of underlying to repay
    /// @return An error code (0 on success)
    function repayBorrow(uint repayAmount) external returns (uint);
    /// @notice Repays a borrow on behalf of another borrower
    /// @param borrower The account whose borrow is repaid
    /// @param repayAmount The amount of underlying to repay
    /// @return An error code (0 on success)
    function repayBorrowBehalf(
        address borrower,
        uint repayAmount
    ) external returns (uint);

    /// @notice Returns the address of the underlying asset
    /// @return The underlying token address
    function underlying() external view returns (address);
    /// @notice Returns the most recently stored exchange rate (mToken to underlying), scaled by 1e18
    /// @return The stored exchange rate mantissa
    function exchangeRateStored() external view returns (uint);
    /// @notice Returns the mToken balance of an account
    /// @param owner The account to query
    /// @return The mToken balance
    function balanceOf(address owner) external view returns (uint);
    /// @notice Returns the underlying balance of an account, accruing interest
    /// @param owner The account to query
    /// @return The underlying balance
    function balanceOfUnderlying(address owner) external returns (uint);
    /// @notice Returns a snapshot of an account's position
    /// @param account The account to query
    /// @return An error code (0 on success)
    /// @return The mToken balance
    /// @return The borrow balance
    /// @return The exchange rate mantissa
    function getAccountSnapshot(
        address account
    ) external view returns (uint, uint, uint, uint);
    /// @notice Returns the underlying balance of an account without accruing interest (view)
    /// @param account The account to query
    /// @return The underlying balance
    function viewUnderlyingBalanceOf(
        address account
    ) external view returns (uint);
    /// @notice Returns the block timestamp of the last interest accrual
    /// @return The accrual block timestamp
    function accrualBlockTimestamp() external view returns (uint);
    /// @notice Returns the amount of underlying held by the market (cash)
    /// @return The cash amount
    function getCash() external view returns (uint);
    /// @notice Returns the total outstanding borrows
    /// @return The total borrows
    function totalBorrows() external view returns (uint);
    /// @notice Returns the total reserves held by the market
    /// @return The total reserves
    function totalReserves() external view returns (uint);
    /// @notice Returns the address of the interest rate model
    /// @return The interest rate model address
    function interestRateModel() external view returns (address);
    /// @notice Returns the reserve factor, scaled by 1e18
    /// @return The reserve factor mantissa
    function reserveFactorMantissa() external view returns (uint);
    /// @notice Returns the total supply of mTokens
    /// @return The total mToken supply
    function totalSupply() external view returns (uint);

    /// @notice Returns the address of the comptroller for this market
    /// @return The comptroller address
    function comptroller() external view returns (address);
}
