// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ReentrancyGuardTransient} from "../../lib/openzeppelin-next/ReentrancyGuardTransient.sol";

import {IAdmiralsQuarters} from "../interfaces/IAdmiralsQuarters.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

/**
 * @title AdmiralsQuarters
 * @dev A contract for managing deposits and withdrawals to/from FleetCommander contracts,
 *      with integrated swapping functionality using 1inch Router.
 * @notice This contract uses an OpenZeppelin nonReentrant modifier with transient storage for gas efficiency.
 * @notice When it was developed the OpenZeppelin version was 5.0.2 ( hence the use of locally stored
 * ReentrancyGuardTransient )
 *
 * @dev How to use this contract:
 * 1. Deposit tokens: Use `depositTokens` to deposit ERC20 tokens into the contract.
 * 2. Withdraw tokens: Use `withdrawTokens` to withdraw deposited tokens.
 * 3. Enter a fleet: Use `enterFleet` to deposit tokens into a FleetCommander contract.
 * 4. Exit a fleet: Use `exitFleet` to withdraw tokens from a FleetCommander contract.
 * 5. Swap tokens: Use `swap` to exchange one token for another using the 1inch Router.
 * 6. Rescue tokens: Contract owner can use `rescueTokens` to withdraw any tokens stuck in the contract.
 *
 * @dev Multicall functionality:
 * This contract inherits from OpenZeppelin's Multicall, allowing multiple function calls to be batched into a single
 * transaction.
 * To use Multicall:
 * 1. Encode each function call you want to make as calldata.
 * 2. Pack these encoded function calls into an array of bytes.
 * 3. Call the `multicall` function with this array as the argument.
 *
 * Example Multicall usage:
 * bytes[] memory calls = new bytes[](2);
 * calls[0] = abi.encodeWithSelector(this.depositTokens.selector, tokenAddress, amount);
 * calls[1] = abi.encodeWithSelector(this.enterFleet.selector, fleetCommanderAddress, tokenAddress, amount);
 * (bool[] memory successes, bytes[] memory results) = this.multicall(calls);
 *
 * @dev Security considerations:
 * - All external functions are protected against reentrancy attacks.
 * - The contract uses OpenZeppelin's SafeERC20 for safe token transfers.
 * - Only the contract owner can rescue tokens.
 * - Ensure that the 1inch Router address provided in the constructor is correct and trusted.
 * - Since there is no data exchange between calls - make sure all the tokens are returned to the user
 */
contract AdmiralsQuarters is
    Ownable,
    Multicall,
    ReentrancyGuardTransient,
    IAdmiralsQuarters
{
    using SafeERC20 for IERC20;

    address public immutable oneInchRouter;

    constructor(address _oneInchRouter) Ownable(msg.sender) {
        if (_oneInchRouter == address(0)) revert InvalidRouterAddress();
        oneInchRouter = _oneInchRouter;
    }

    /// @inheritdoc IAdmiralsQuarters
    function depositTokens(IERC20 asset, uint256 amount) external nonReentrant {
        if (address(asset) == address(0)) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();

        asset.safeTransferFrom(msg.sender, address(this), amount);
        emit TokensDeposited(msg.sender, address(asset), amount);
    }

    /// @inheritdoc IAdmiralsQuarters
    function withdrawTokens(
        IERC20 asset,
        uint256 amount
    ) external nonReentrant {
        if (address(asset) == address(0)) revert InvalidToken();
        if (amount == 0) {
            amount = asset.balanceOf(address(this));
        }

        asset.safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, address(asset), amount);
    }

    /// @inheritdoc IAdmiralsQuarters
    function enterFleet(
        address fleetCommander,
        IERC20 inputToken,
        uint256 amount
    ) external nonReentrant returns (uint256 shares) {
        if (fleetCommander == address(0)) revert InvalidFleetCommander();
        if (address(inputToken) == address(0)) revert InvalidToken();

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetToken = IERC20(fleet.asset());

        uint256 balance = inputToken.balanceOf(address(this));
        uint256 depositAmount = amount == 0 ? balance : amount;
        if (depositAmount > balance) revert InsufficientOutputAmount();

        fleetToken.forceApprove(address(fleet), depositAmount);
        shares = fleet.deposit(depositAmount, msg.sender);

        emit FleetEntered(msg.sender, fleetCommander, depositAmount, shares);
    }

    /// @inheritdoc IAdmiralsQuarters
    function exitFleet(
        address fleetCommander,
        uint256 amount
    ) external nonReentrant returns (uint256 shares) {
        if (fleetCommander == address(0)) revert InvalidFleetCommander();

        IFleetCommander fleet = IFleetCommander(fleetCommander);

        uint256 withdrawAmount = amount == 0 ? type(uint256).max : amount;

        shares = fleet.withdraw(withdrawAmount, address(this), msg.sender);

        emit FleetExited(msg.sender, fleetCommander, withdrawAmount, shares);
    }

    /// @inheritdoc IAdmiralsQuarters
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 minTokensReceived,
        bytes calldata swapCalldata
    ) external nonReentrant returns (uint256 swappedAmount) {
        if (
            address(fromToken) == address(0) || address(toToken) == address(0)
        ) {
            revert InvalidToken();
        }
        if (amount == 0) revert ZeroAmount();
        if (address(fromToken) == address(toToken)) {
            revert AssetMismatch();
        }
        swappedAmount = _swap(
            fromToken,
            toToken,
            amount,
            minTokensReceived,
            swapCalldata
        );

        emit Swapped(
            msg.sender,
            address(fromToken),
            address(toToken),
            amount,
            swappedAmount
        );
    }

    /**
     * @dev Internal function to perform a token swap using 1inch
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amount The amount of fromToken to swap
     * @param minTokensReceived The minimum amount of toToken to receive after the swap
     * @param swapCalldata The 1inch swap calldata
     * @return swappedAmount The amount of toToken received from the swap
     */
    function _swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 minTokensReceived,
        bytes calldata swapCalldata
    ) internal returns (uint256 swappedAmount) {
        uint256 balanceBefore = toToken.balanceOf(address(this));

        fromToken.forceApprove(oneInchRouter, amount);
        (bool success, ) = oneInchRouter.call(swapCalldata);
        if (!success) {
            revert SwapFailed();
        }

        uint256 balanceAfter = toToken.balanceOf(address(this));
        swappedAmount = balanceAfter - balanceBefore;

        if (swappedAmount < minTokensReceived) {
            revert InsufficientOutputAmount();
        }
    }

    /// @inheritdoc IAdmiralsQuarters
    function rescueTokens(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(to, amount);
        emit TokensRescued(address(token), to, amount);
    }
}
