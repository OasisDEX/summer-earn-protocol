// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IAdmiralsQuartersWhitelist} from "../interfaces/IAdmiralsQuartersWhitelist.sol";
import {ISummerRewardsRedeemer} from "@summerfi/rewards-contracts/interfaces/ISummerRewardsRedeemer.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAToken} from "../interfaces/aave-v3/IAtoken.sol";
import {IPoolV3} from "../interfaces/aave-v3/IPoolV3.sol";
import {IComet} from "../interfaces/compound-v3/IComet.sol";
import {IWETH} from "../interfaces/misc/IWETH.sol";
import {ConfigurationManaged} from "./ConfigurationManaged.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {ProtectedMulticallWhitelist} from "./ProtectedMulticallWhitelist.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWhitelist} from "../utils/Whitelist/IWhitelist.sol";

/**
 * @title AdmiralsQuarters
 * @dev A contract for managing deposits and withdrawals to/from FleetCommander contracts,
 *      with integrated swapping functionality using 1inch Router.
 * @notice This contract uses an OpenZeppelin nonReentrant modifier with transient storage for gas
 * efficiency.
 * @notice Whitelist gating: All external functions are invoked via `multicall` in
 * `ProtectedMulticallWhitelist`, which enforces `onlyWhitelisted(_msgSender())`. If the
 * underlying whitelist is set to open mode by whitelisting `address(0)`, any caller is treated as
 * whitelisted and may use `multicall`.
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
contract AdmiralsQuartersWhitelist is
    Ownable,
    ProtectedMulticallWhitelist,
    ReentrancyGuardTransient,
    IAdmiralsQuartersWhitelist,
    ProtocolAccessManaged,
    ConfigurationManaged
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IAToken;

    address public immutable ONE_INCH_ROUTER;
    address public immutable NATIVE_PSEUDO_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WRAPPED_NATIVE;

    constructor(
        address _oneInchRouter,
        address _configurationManager,
        address _protocolAccessManager,
        address _wrappedNative
    )
        Ownable(_msgSender())
        ConfigurationManaged(_configurationManager)
        ProtocolAccessManaged(_protocolAccessManager)
    {
        if (_oneInchRouter == address(0)) revert InvalidRouterAddress();
        ONE_INCH_ROUTER = _oneInchRouter;
        if (_wrappedNative == address(0)) revert InvalidNativeTokenAddress();
        WRAPPED_NATIVE = _wrappedNative;
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function depositTokens(
        IERC20 asset,
        uint256 amount
    ) external payable onlyMulticall nonReentrant {
        _validateToken(asset);
        _validateAmount(amount);

        if (address(asset) == NATIVE_PSEUDO_ADDRESS) {
            _validateNativeAmount(amount, msg.value);
            IWETH(WRAPPED_NATIVE).deposit{value: amount}();
        } else {
            asset.safeTransferFrom(_msgSender(), address(this), amount);
        }
        emit TokensDeposited(_msgSender(), address(asset), amount);
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function withdrawTokens(
        IERC20 asset,
        uint256 amount
    ) external payable onlyMulticall nonReentrant {
        _validateToken(asset);

        if (address(asset) == NATIVE_PSEUDO_ADDRESS) {
            if (amount == 0) {
                amount = IWETH(WRAPPED_NATIVE).balanceOf(address(this));
            }
            IWETH(WRAPPED_NATIVE).withdraw(amount);
            payable(_msgSender()).transfer(amount);
        } else {
            if (amount == 0) {
                amount = asset.balanceOf(address(this));
            }
            asset.safeTransfer(_msgSender(), amount);
        }

        emit TokensWithdrawn(_msgSender(), address(asset), amount);
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function enterFleet(
        address fleetCommander,
        uint256 assets,
        address receiver
    ) external payable onlyMulticall nonReentrant returns (uint256 shares) {
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetAsset = IERC20(fleet.asset());

        uint256 balance = fleetAsset.balanceOf(address(this));
        assets = assets == 0 ? balance : assets;
        receiver = receiver == address(0) ? _msgSender() : receiver;
        if (assets > balance) revert InsufficientOutputAmount();

        fleetAsset.forceApprove(address(fleet), assets);
        shares = fleet.deposit(assets, receiver);

        emit FleetEntered(_msgSender(), fleetCommander, assets, shares);
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function exitFleet(
        address fleetCommander,
        uint256 assets
    ) external payable onlyMulticall nonReentrant returns (uint256 shares) {
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);

        assets = assets == 0 ? Constants.MAX_UINT256 : assets;

        shares = fleet.withdraw(assets, address(this), _msgSender());

        emit FleetExited(_msgSender(), fleetCommander, assets, shares);
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 assets,
        uint256 minTokensReceived,
        bytes calldata swapCalldata
    )
        external
        payable
        onlyMulticall
        nonReentrant
        returns (uint256 swappedAmount)
    {
        _validateToken(fromToken);
        _validateToken(toToken);
        _validateAmount(assets);

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

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function claimMerkleRewards(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs,
        address rewardsRedeemer
    ) external onlyMulticall nonReentrant {
        _claimMerkleRewards(user, indices, amounts, proofs, rewardsRedeemer);
    }

    /// ADMIN

    ///@inheritdoc IWhitelist
    function setWhitelisted(
        address account,
        bool allowed
    ) external override onlyGovernor {
        _setWhitelisted(account, allowed);
    }

    ///@inheritdoc IWhitelist
    function setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) external override onlyGovernor {
        _setWhitelistedBatch(accounts, allowed);
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

        fromToken.forceApprove(ONE_INCH_ROUTER, assets);
        (bool success, ) = ONE_INCH_ROUTER.call(swapCalldata);
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

    function _validateNativeAmount(
        uint256 amount,
        uint256 msgValue
    ) internal view {
        if (amount != msgValue) revert InvalidNativeAmount();
        // https://github.com/Uniswap/v3-periphery/issues/52
        if (msgValue > address(this).balance) revert InsufficientNativeAmount();
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function rescueTokens(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (address(token) == NATIVE_PSEUDO_ADDRESS) {
            uint256 ethAmount = amount == 0 ? address(this).balance : amount;
            (bool success, ) = payable(to).call{value: ethAmount}("");
            if (!success) revert ETHTransferFailed();
            emit TokensRescued(NATIVE_PSEUDO_ADDRESS, to, ethAmount);
        } else {
            token.safeTransfer(to, amount);
            emit TokensRescued(address(token), to, amount);
        }
    }

    /**
     * @dev Required to receive ETH when unwrapping WETH
     */
    receive() external payable {}

    /**
     * @dev Claims rewards from merkle distributor
     * @param user Address to claim rewards for
     * @param indices Array of merkle proof indices
     * @param amounts Array of merkle proof amounts
     * @param proofs Array of merkle proof data
     * @param rewardsRedeemer Address of the rewards redeemer contract
     */
    function _claimMerkleRewards(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs,
        address rewardsRedeemer
    ) internal {
        if (rewardsRedeemer == address(0)) {
            revert InvalidRewardsRedeemer();
        }

        // We can now directly pass the arrays to the redeemer
        ISummerRewardsRedeemer(rewardsRedeemer).claimMultiple(
            user,
            indices,
            amounts,
            proofs
        );
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
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

    /// @inheritdoc IAdmiralsQuartersWhitelist
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

    /// @inheritdoc IAdmiralsQuartersWhitelist
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
}
