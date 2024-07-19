// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IComet {
    event Supply(address indexed from, address indexed dst, uint amount);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Withdraw(address indexed src, address indexed to, uint amount);

    event SupplyCollateral(
        address indexed from,
        address indexed dst,
        address indexed asset,
        uint amount
    );
    event TransferCollateral(
        address indexed from,
        address indexed to,
        address indexed asset,
        uint amount
    );
    event WithdrawCollateral(
        address indexed src,
        address indexed to,
        address indexed asset,
        uint amount
    );

    /// @notice Event emitted when a borrow position is absorbed by the protocol
    event AbsorbDebt(
        address indexed absorber,
        address indexed borrower,
        uint basePaidOut,
        uint usdValue
    );

    /// @notice Event emitted when a user's collateral is absorbed by the protocol
    event AbsorbCollateral(
        address indexed absorber,
        address indexed borrower,
        address indexed asset,
        uint collateralAbsorbed,
        uint usdValue
    );

    /// @notice Event emitted when a collateral asset is purchased from the protocol
    event BuyCollateral(
        address indexed buyer,
        address indexed asset,
        uint baseAmount,
        uint collateralAmount
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
    event WithdrawReserves(address indexed to, uint amount);

    function borrowBalanceOf(address account) external view returns (uint256);

    function supply(address asset, uint256 amount) external;

    function withdraw(address asset, uint256 amount) external;

    function getSupplyRate(uint256 utilization) external view returns (uint64);

    function getUtilization() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);
}
