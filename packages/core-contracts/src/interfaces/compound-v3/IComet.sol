// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IComet
 * @notice Minimal interface for a Compound V3 (Comet) market
 */
interface IComet {
    /// @notice Emitted when base tokens are supplied to the market
    event Supply(address indexed from, address indexed dst, uint256 amount);
    /// @notice Emitted when base token balance is transferred between accounts
    event Transfer(address indexed from, address indexed to, uint256 amount);
    /// @notice Emitted when base tokens are withdrawn from the market
    event Withdraw(address indexed src, address indexed to, uint256 amount);

    /// @notice Emitted when a collateral asset is supplied to the market
    event SupplyCollateral(
        address indexed from,
        address indexed dst,
        address indexed asset,
        uint256 amount
    );
    /// @notice Emitted when a collateral asset is transferred between accounts
    event TransferCollateral(
        address indexed from,
        address indexed to,
        address indexed asset,
        uint256 amount
    );
    /// @notice Emitted when a collateral asset is withdrawn from the market
    event WithdrawCollateral(
        address indexed src,
        address indexed to,
        address indexed asset,
        uint256 amount
    );

    /// @notice Event emitted when a borrow position is absorbed by the protocol
    event AbsorbDebt(
        address indexed absorber,
        address indexed borrower,
        uint256 basePaidOut,
        uint256 usdValue
    );

    /// @notice Event emitted when a user's collateral is absorbed by the protocol
    event AbsorbCollateral(
        address indexed absorber,
        address indexed borrower,
        address indexed asset,
        uint256 collateralAbsorbed,
        uint256 usdValue
    );

    /// @notice Event emitted when a collateral asset is purchased from the protocol
    event BuyCollateral(
        address indexed buyer,
        address indexed asset,
        uint256 baseAmount,
        uint256 collateralAmount
    );

    /// @notice Event emitted when an action is paused/unpaused
    event PauseAction(
        bool supplyPaused,
        bool transferPaused,
        bool withdrawPaused,
        bool absorbPaused,
        bool buyPaused
    );

    /// @notice Event emitted when reserves are withdrawn by the governor
    event WithdrawReserves(address indexed to, uint256 amount);

    /**
     * @notice Authorizes or revokes a spender to manage the caller's account
     * @param spender The address being authorized or revoked
     * @param isAllowed True to authorize, false to revoke
     */
    function allow(address spender, bool isAllowed) external;

    /**
     * @notice Returns the current borrow balance of an account in base token units
     * @param account The account to query
     * @return The outstanding borrow balance
     */
    function borrowBalanceOf(address account) external view returns (uint256);

    /**
     * @notice Supplies an asset to the market for the caller
     * @param asset The asset to supply (base or collateral)
     * @param amount The amount to supply
     */
    function supply(address asset, uint256 amount) external;

    /**
     * @notice Withdraws an asset from the caller's position
     * @param asset The asset to withdraw (base or collateral)
     * @param amount The amount to withdraw
     */
    function withdraw(address asset, uint256 amount) external;

    /**
     * @notice Withdraws an asset from one account to another, subject to permissions
     * @param from The account to withdraw from
     * @param to The recipient of the withdrawn asset
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     */
    function withdrawFrom(
        address from,
        address to,
        address asset,
        uint256 amount
    ) external;

    /**
     * @notice Returns the per-second supply interest rate for a given utilization
     * @param utilization The market utilization, scaled by 1e18
     * @return The supply rate per second
     */
    function getSupplyRate(uint256 utilization) external view returns (uint64);

    /**
     * @notice Returns the current market utilization, scaled by 1e18
     * @return The current utilization
     */
    function getUtilization() external view returns (uint256);

    /**
     * @notice Returns the base token balance (supplied position) of an account
     * @param owner The account to query
     * @return The base token balance
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @notice Returns the address of the market's base token
     * @return The base token address
     */
    function baseToken() external view returns (address);

    /**
     * @notice Returns whether a manager is permitted to act on behalf of an owner
     * @param owner The account owner
     * @param manager The potential manager
     * @return True if the manager is authorized
     */
    function hasPermission(
        address owner,
        address manager
    ) external view returns (bool);

    /**
     * @notice Returns whether withdrawals are currently paused
     * @return True if withdrawals are paused
     */
    function isWithdrawPaused() external view returns (bool);
}
