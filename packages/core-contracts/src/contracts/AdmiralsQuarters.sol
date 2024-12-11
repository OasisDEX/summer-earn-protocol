// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@summerfi/dependencies/openzeppelin-next/ReentrancyGuardTransient.sol";

import {IAdmiralsQuarters} from "../interfaces/IAdmiralsQuarters.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

import {IFleetCommanderRewardsManager} from "../interfaces/IFleetCommanderRewardsManager.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";

import {IAToken} from "../interfaces/aave-v3/IAtoken.sol";
import {IPoolV3} from "../interfaces/aave-v3/IPoolV3.sol";
import {IComet} from "../interfaces/compound-v3/IComet.sol";
import {ConfigurationManaged} from "./ConfigurationManaged.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ProtectedMulticall} from "./ProtectedMulticall.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AdmiralsQuarters
 * @dev A contract for managing deposits and withdrawals to/from FleetCommander contracts,
 *      with integrated swapping functionality using 1inch Router.
 * @notice This contract uses an OpenZeppelin nonReentrant modifier with transient storage for gas
 * efficiency.
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
    ProtectedMulticall,
    ReentrancyGuardTransient,
    IAdmiralsQuarters,
    ConfigurationManaged
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IAToken;

    /// @notice The address of the 1inch Router contract used for token swaps
    /// @dev This is set during contract construction and cannot be changed
    address public immutable oneInchRouter;

    constructor(
        address _oneInchRouter,
        address _configurationManager
    ) Ownable(_msgSender()) ConfigurationManaged(_configurationManager) {
        if (_oneInchRouter == address(0)) revert InvalidRouterAddress();
        oneInchRouter = _oneInchRouter;
    }

    /// @inheritdoc IAdmiralsQuarters
    function depositTokens(
        IERC20 asset,
        uint256 amount
    ) external onlyMulticall nonReentrant {
        _validateToken(asset);
        _validateAmount(amount);

        asset.safeTransferFrom(_msgSender(), address(this), amount);
        emit TokensDeposited(_msgSender(), address(asset), amount);
    }

    /// @inheritdoc IAdmiralsQuarters
    function withdrawTokens(
        IERC20 asset,
        uint256 amount
    ) external onlyMulticall nonReentrant {
        _validateToken(asset);
        if (amount == 0) {
            amount = asset.balanceOf(address(this));
        }

        asset.safeTransfer(_msgSender(), amount);
        emit TokensWithdrawn(_msgSender(), address(asset), amount);
    }

    /// @inheritdoc IAdmiralsQuarters
    function enterFleet(
        address fleetCommander,
        IERC20 inputToken,
        uint256 assets,
        address receiver
    ) external onlyMulticall nonReentrant returns (uint256 shares) {
        _validateFleetCommander(fleetCommander);
        _validateToken(inputToken);

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetAsset = IERC20(fleet.asset());

        if (address(inputToken) != address(fleetAsset)) revert TokenMismatch();

        uint256 balance = inputToken.balanceOf(address(this));
        assets = assets == 0 ? balance : assets;
        receiver = receiver == address(0) ? _msgSender() : receiver;
        if (assets > balance) revert InsufficientOutputAmount();

        fleetAsset.forceApprove(address(fleet), assets);
        shares = fleet.deposit(assets, receiver);

        emit FleetEntered(receiver, fleetCommander, assets, shares);
    }

    /// @inheritdoc IAdmiralsQuarters
    function exitFleet(
        address fleetCommander,
        uint256 assets
    ) external onlyMulticall nonReentrant returns (uint256 shares) {
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);

        assets = assets == 0 ? type(uint256).max : assets;

        shares = fleet.withdraw(assets, address(this), _msgSender());

        emit FleetExited(_msgSender(), fleetCommander, assets, shares);
    }

    /// @inheritdoc IAdmiralsQuarters
    function stake(
        address fleetCommander,
        uint256 shares
    ) external onlyMulticall nonReentrant {
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        address rewardsManager = fleet.getConfig().stakingRewardsManager;
        _validateRewardsManager(rewardsManager);

        uint256 balance = IERC20(fleetCommander).balanceOf(address(this));
        shares = shares == 0 ? balance : shares;
        if (shares > balance) revert InsufficientOutputAmount();

        IERC20(fleetCommander).forceApprove(rewardsManager, shares);
        IFleetCommanderRewardsManager(rewardsManager).stakeOnBehalfOf(
            _msgSender(),
            shares
        );

        emit FleetSharesStaked(_msgSender(), fleetCommander, shares);
    }

    /// @inheritdoc IAdmiralsQuarters
    function unstakeAndWithdrawAssets(
        address fleetCommander,
        uint256 shares,
        bool claimRewards
    ) external onlyMulticall nonReentrant {
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        address rewardsManager = fleet.getConfig().stakingRewardsManager;
        _validateRewardsManager(rewardsManager);

        shares = shares == 0
            ? IFleetCommanderRewardsManager(rewardsManager).balanceOf(
                _msgSender()
            )
            : shares;
        IFleetCommanderRewardsManager(rewardsManager)
            .unstakeAndWithdrawOnBehalfOf(_msgSender(), shares, claimRewards);

        emit FleetSharesUnstaked(_msgSender(), fleetCommander, shares);
    }

    /// @inheritdoc IAdmiralsQuarters
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 assets,
        uint256 minTokensReceived,
        bytes calldata swapCalldata
    ) external onlyMulticall nonReentrant returns (uint256 swappedAmount) {
        if (
            address(fromToken) == address(0) || address(toToken) == address(0)
        ) {
            revert InvalidToken();
        }
        if (assets == 0) revert ZeroAmount();
        if (address(fromToken) == address(toToken)) {
            revert AssetMismatch();
        }
        swappedAmount = _swap(
            fromToken,
            toToken,
            assets,
            minTokensReceived,
            swapCalldata
        );

        emit Swapped(
            _msgSender(),
            address(fromToken),
            address(toToken),
            assets,
            swappedAmount
        );
    }

    /// @inheritdoc IAdmiralsQuarters
    function moveFromCompoundToAdmiralsQuarters(
        address cToken,
        uint256 assets
    ) external onlyMulticall nonReentrant {
        IComet token = IComet(cToken);
        address underlying = token.baseToken();

        // Get actual assets if 0 was passed
        assets = assets == 0 ? token.balanceOf(_msgSender()) : assets;

        // Calculate underlying assets
        token.withdrawFrom(_msgSender(), address(this), underlying, assets);

        emit CompoundPositionImported(_msgSender(), cToken, assets);
    }

    /// @inheritdoc IAdmiralsQuarters
    function moveFromAaveToAdmiralsQuarters(
        address aToken,
        uint256 assets
    ) external onlyMulticall nonReentrant {
        IAToken token = IAToken(aToken);
        IPoolV3 pool = IPoolV3(token.POOL());
        IERC20 underlying = IERC20(token.UNDERLYING_ASSET_ADDRESS());

        assets = assets == 0 ? token.balanceOf(_msgSender()) : assets;

        token.safeTransferFrom(_msgSender(), address(this), assets);
        pool.withdraw(address(underlying), assets, address(this));

        emit AavePositionImported(_msgSender(), aToken, assets);
    }

    /// @inheritdoc IAdmiralsQuarters
    function moveFromERC4626ToAdmiralsQuarters(
        address vault,
        uint256 shares
    ) external onlyMulticall nonReentrant {
        IERC4626 vaultToken = IERC4626(vault);

        // Get actual shares if 0 was passed
        shares = shares == 0 ? vaultToken.balanceOf(_msgSender()) : shares;

        vaultToken.redeem(shares, address(this), _msgSender());

        emit ERC4626PositionImported(_msgSender(), vault, shares);
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

    /**
     * @dev Internal function to perform a token swap using 1inch
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param assets The amount of fromToken to swap
     * @param minTokensReceived The minimum amount of toToken to receive after the swap
     * @param swapCalldata The 1inch swap calldata
     * @return swappedAmount The amount of toToken received from the swap
     */
    function _swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 assets,
        uint256 minTokensReceived,
        bytes calldata swapCalldata
    ) internal returns (uint256 swappedAmount) {
        uint256 balanceBefore = toToken.balanceOf(address(this));

        fromToken.forceApprove(oneInchRouter, assets);
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

    function _validateFleetCommander(address fleetCommander) internal view {
        if (
            !IHarborCommand(harborCommand()).activeFleetCommanders(
                fleetCommander
            )
        ) {
            revert InvalidFleetCommander();
        }
    }

    function _validateToken(IERC20 token) internal pure {
        if (address(token) == address(0)) revert InvalidToken();
    }

    function _validateAmount(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _validateRewardsManager(address rewardsManager) internal pure {
        if (rewardsManager == address(0)) revert InvalidRewardsManager();
    }
}
