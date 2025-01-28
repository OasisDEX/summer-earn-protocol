// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IComet {
    event Supply(address indexed from, address indexed dst, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed src, address indexed to, uint256 amount);

    event SupplyCollateral(
        address indexed from,
        address indexed dst,
        address indexed asset,
        uint256 amount
    );
    event TransferCollateral(
        address indexed from,
        address indexed to,
        address indexed asset,
        uint256 amount
    );
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

    function allow(address spender, bool isAllowed) external;

    function borrowBalanceOf(address account) external view returns (uint256);

    function supply(address asset, uint256 amount) external;

    function withdraw(address asset, uint256 amount) external;

    function withdrawFrom(
        address from,
        address to,
        address asset,
        uint256 amount
    ) external;

    function getSupplyRate(uint256 utilization) external view returns (uint64);

    function getUtilization() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function baseToken() external view returns (address);

    function hasPermission(
        address owner,
        address manager
    ) external view returns (bool);

    function isWithdrawPaused() external view returns (bool);
}
