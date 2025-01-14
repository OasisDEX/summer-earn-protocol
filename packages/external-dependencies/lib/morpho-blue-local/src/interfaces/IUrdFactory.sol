pragma solidity 0.8.28;

interface IUrdFactory {
    function isUrd(address _maybeUrd) external view returns (bool);
}
