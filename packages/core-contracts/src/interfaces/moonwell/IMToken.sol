pragma solidity 0.8.28;

interface IMToken {
    /*** User Interface ***/

    function mint(uint mintAmount) external virtual returns (uint);
    function mintWithPermit(
        uint mintAmount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual returns (uint);
    function redeem(uint redeemTokens) external virtual returns (uint);
    function redeemUnderlying(
        uint redeemAmount
    ) external virtual returns (uint);
    function borrow(uint borrowAmount) external virtual returns (uint);
    function repayBorrow(uint repayAmount) external virtual returns (uint);
    function repayBorrowBehalf(
        address borrower,
        uint repayAmount
    ) external virtual returns (uint);

    function underlying() external view virtual returns (address);
    function exchangeRateStored() external view virtual returns (uint);
    function balanceOf(address owner) external view virtual returns (uint);
    function balanceOfUnderlying(address owner) external virtual returns (uint);
    function getAccountSnapshot(
        address account
    ) external view virtual returns (uint, uint, uint, uint);
    function viewUnderlyingBalanceOf(
        address account
    ) external view virtual returns (uint);
    function accrualBlockTimestamp() external view virtual returns (uint);
    function getCash() external view virtual returns (uint);
    function totalBorrows() external view virtual returns (uint);
    function totalReserves() external view virtual returns (uint);
    function interestRateModel() external view virtual returns (address);
    function reserveFactorMantissa() external view virtual returns (uint);
    function totalSupply() external view virtual returns (uint);

    function comptroller() external view virtual returns (address);
}
