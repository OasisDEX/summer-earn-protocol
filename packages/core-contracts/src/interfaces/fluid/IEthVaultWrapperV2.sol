// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IEthVaultWrapperV2 {
    error EthVaultWrapper__OutputInsufficient();
    error EthVaultWrapper__UnexpectedWithdrawAmount();
    error EthVaultWrapper__InvalidInput();
    error EthVaultWrapper__OnlyWhitelisted();

    struct DepositData {
        string route;
        bytes swapCalldata;
    }

    struct WithdrawData {
        string route;
        bytes swapCalldata;
    }
    /// @notice deposits msg.value as stETH into ETH vault. returns shares amount
    /// @param route_ Route string through which swap will go, e.g. "1INCH-A"
    /// @param swapCalldata_ swap data for ETH -> stETH to call AggregationRouter with
    /// @param minStEthIn_ minimum expected stETH to be deposited
    /// @param receiver_ receiver of iToken shares from deposit
    /// @return actual amount of shares received
    function deposit(
        string calldata route_,
        bytes calldata swapCalldata_,
        uint256 minStEthIn_,
        address receiver_
    ) external payable returns (uint256);

    /// @notice withdraws amount_ of stETH from msg.sender as owner and swaps it to ETH then transfers to msg.sender
    /// @param route_ Route string through which swap will go, e.g. "1INCH-A"
    /// @param amount_ amount of stETH to withdraw
    /// @param swapCalldata_ swap data for stETH -> ETH to call AggregationRouter with
    /// @param minEthOut_ minimum expected output ETH
    /// @param receiver_ receiver of withdrawn ETH
    /// @return ethAmount_ actual output ETH
    function withdraw(
        string calldata route_,
        uint256 amount_,
        bytes calldata swapCalldata_,
        uint256 minEthOut_,
        address receiver_
    ) external returns (uint256 ethAmount_);

    /// @notice gets the amount of stETH that must be swapped to ETH via router for a withdraw
    /// @param amount_ amount of stETH to withdraw
    /// @return stEthSwapAmount_ to amount of stEth to be swapped to ETH
    function getWithdrawSwapAmount(
        uint256 amount_
    ) external view returns (uint256 stEthSwapAmount_);
}
