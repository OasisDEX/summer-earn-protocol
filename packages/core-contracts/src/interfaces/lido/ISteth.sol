// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISteth {
    /**
     * @notice Send funds to the pool with optional _referral parameter
     * @dev This function is alternative way to submit funds. Supports optional referral address.
     * @return Amount of StETH shares generated
     */
    function submit(address _referral) external payable returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
    function sharesOf(address _account) external view returns (uint256);
    function approve(address _spender, uint256 _amount) external returns (bool);
    function getPooledEthByShares(
        uint256 _shares
    ) external view returns (uint256);
    function getSharesByPooledEth(
        uint256 _ethAmount
    ) external view returns (uint256);
}
