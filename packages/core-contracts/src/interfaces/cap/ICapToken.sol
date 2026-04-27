// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ICapToken
 * @notice Interface for the Cap Vault (cUSD)
 */
interface ICapToken is IERC20 {
    function mint(
        address _asset,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        uint256 _deadline
    ) external returns (uint256 amountOut);

    function burn(
        address _asset,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        uint256 _deadline
    ) external returns (uint256 amountOut);

    function getMintAmount(
        address _user,
        address _asset,
        uint256 _amountIn
    ) external view returns (uint256 amountOut, uint256 fee);

    function getBurnAmount(
        address _asset,
        uint256 _amountIn
    ) external view returns (uint256 amountOut, uint256 fee);

    function availableBalance(address _asset) external view returns (uint256);

    function assets() external view returns (address[] memory);
}
