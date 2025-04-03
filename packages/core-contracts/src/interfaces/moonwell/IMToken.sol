pragma solidity 0.8.28;

interface IMToken {
    /*** User Interface ***/

    function mint(uint mintAmount) external returns (uint);
    function mintWithPermit(
        uint mintAmount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(
        address borrower,
        uint repayAmount
    ) external returns (uint);

    function underlying() external view returns (address);
    function exchangeRateStored() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(
        address account
    ) external view returns (uint, uint, uint, uint);
    function viewUnderlyingBalanceOf(
        address account
    ) external view returns (uint);
    function accrualBlockTimestamp() external view returns (uint);
    function getCash() external view returns (uint);
    function totalBorrows() external view returns (uint);
    function totalReserves() external view returns (uint);
    function interestRateModel() external view returns (address);
    function reserveFactorMantissa() external view returns (uint);
    function totalSupply() external view returns (uint);

    function comptroller() external view returns (address);
}
