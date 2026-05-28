// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IAdmiralsQuartersWhitelist} from "../interfaces/IAdmiralsQuartersWhitelist.sol";
import {ISummerRewardsRedeemer} from "@summerfi/rewards-contracts/interfaces/ISummerRewardsRedeemer.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IAToken} from "../interfaces/aave-v3/IAtoken.sol";
import {IPoolV3} from "../interfaces/aave-v3/IPoolV3.sol";
import {IComet} from "../interfaces/compound-v3/IComet.sol";
import {IWETH} from "../interfaces/misc/IWETH.sol";
import {ConfigurationManaged} from "@summerfi/config-contracts/contracts/ConfigurationManaged.sol";
import {ProtocolAccessManagedV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagedV2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {ProtectedMulticallWhitelist} from "./ProtectedMulticallWhitelist.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWhitelist} from "../utils/Whitelist/IWhitelist.sol";
import {Whitelist} from "../utils/Whitelist/Whitelist.sol";
import {ISignatureTransfer} from "../interfaces/permit2/IPermit2.sol";

/**
 * @title AdmiralsQuartersWhitelist
 *
 * @notice Whitelisted bundler for institutional FleetCommanders. Lets a whitelisted user atomically
 *         pull tokens from another protocol (Aave V3, Compound V3, ERC-4626), optionally swap via
 *         1inch, and deposit into a target FleetCommander — all in a single multicall transaction.
 *         A Permit2 entry path is also provided.
 *
 * @notice Whitelist gating: every fleet-touching entry point (`enterFleet`, `enterFleetWithPermit2`,
 *         `exitFleet`) checks the caller, owner, and receiver against the target FleetCommander
 *         context before invoking the fleet. The other entry points (`depositTokens`,
 *         `withdrawTokens`, `swap`, `claimMerkleRewards`, `moveFromAaveToAdmiralsQuarters`,
 *         `moveFromCompoundToAdmiralsQuarters`, `moveFromERC4626ToAdmiralsQuarters`) are not
 *         context-gated themselves — they only move tokens between the caller and this contract's
 *         transient balance. Composing them into a fleet entry/exit forces the whitelist check at
 *         the fleet step.
 *
 * @notice Reentrancy: every external entry point uses OpenZeppelin's transient-storage
 *         `nonReentrant` modifier. The `onlyMulticall` modifier additionally requires sensitive
 *         entry points to be invoked from within a top-level `multicall(bytes[])`, so external
 *         callers cannot reach them standalone.
 *
 * @dev Typical multicall usage:
 *      ```
 *      bytes[] memory calls = new bytes[](2);
 *      calls[0] = abi.encodeCall(this.depositTokens, (tokenAddress, amount));
 *      calls[1] = abi.encodeCall(this.enterFleet, (fleetCommander, amount, receiver));
 *      this.multicall(calls);
 *      ```
 *
 * @dev Security considerations:
 * - All external entry points use transient-storage `nonReentrant`.
 * - Only the contract owner (Ownable, not the Governor role) can call `rescueTokens`.
 * - The 1inch Router address provided in the constructor must be trusted; this contract performs
 *   raw calls to it with caller-supplied calldata.
 * - Tokens stranded between calls in a `multicall` (e.g. a swap that does not feed into a final
 *   `enterFleet` / `withdrawTokens`) remain in this contract until the owner rescues them.
 */
contract AdmiralsQuartersWhitelist is
    Ownable,
    ProtectedMulticallWhitelist,
    ReentrancyGuardTransient,
    IAdmiralsQuartersWhitelist,
    ProtocolAccessManagedV2,
    ConfigurationManaged
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IAToken;

    /// @notice Address of the 1inch aggregator router used by `swap` to execute on-chain trades.
    address public immutable ONE_INCH_ROUTER;
    /// @notice Sentinel address used to represent the chain's native token (e.g. ETH) in token
    ///         arguments. When supplied, the contract wraps/unwraps via `WRAPPED_NATIVE`.
    address public immutable NATIVE_PSEUDO_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @notice Address of the wrapped-native token (e.g. WETH) used to wrap incoming native ETH and
    ///         unwrap outgoing native ETH transfers.
    address public immutable WRAPPED_NATIVE;

    /// @notice Canonical Uniswap Permit2 contract address used by `enterFleetWithPermit2` to pull
    ///         tokens from signers via witness-bound transfers.
    address public constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /**
     * @notice EIP-712 witness payload bound to a Permit2 signature in `enterFleetWithPermit2`.
     * @dev The witness is hashed with `_FLEET_DEPOSIT_TYPEHASH` and supplied to
     *      `ISignatureTransfer.permitWitnessTransferFrom`, ensuring the signed token transfer can
     *      only be consumed by a deposit into the exact `fleetCommander`/`receiver` pair specified
     *      by the signer.
     * @param fleetCommander The FleetCommander the signed transfer authorizes a deposit into.
     * @param receiver The address that will receive the FleetCommander shares.
     * @param referralCode Referral code bound into the witness. This whitelisted variant ignores
     *                    referral tracking on-chain and always substitutes `bytes32(0)`; signers
     *                    MUST use `bytes32(0)` here for signature verification to succeed.
     */
    struct FleetDepositWitness {
        address fleetCommander;
        address receiver;
        bytes32 referralCode;
    }

    bytes32 internal constant _FLEET_DEPOSIT_TYPEHASH =
        keccak256(
            "FleetDepositWitness(address fleetCommander,address receiver,bytes32 referralCode)"
        );

    string internal constant _WITNESS_TYPE_STRING =
        "FleetDepositWitness witness)FleetDepositWitness(address fleetCommander,address receiver,bytes32 referralCode)TokenPermissions(address token,uint256 amount)";

    /**
     * @notice Wires the bundler to its 1inch router, configuration manager, protocol access
     *         manager, and wrapped-native token. Sets the deployer as the Ownable owner.
     * @param _oneInchRouter Address of the 1inch aggregator router used by `swap`.
     * @param _configurationManager `ConfigurationManaged` source that exposes `harborCommand()`
     *                              used to validate FleetCommander addresses.
     * @param _protocolAccessManager `ProtocolAccessManagerV2` instance that brokers the whitelist
     *                               and role hierarchy.
     * @param _wrappedNative Wrapped-native (e.g. WETH) used when callers route in/out of native ETH
     *                       via `NATIVE_PSEUDO_ADDRESS`.
     */
    constructor(
        address _oneInchRouter,
        address _configurationManager,
        address _protocolAccessManager,
        address _wrappedNative
    )
        Ownable(_msgSender())
        ConfigurationManaged(_configurationManager)
        ProtocolAccessManagedV2(_protocolAccessManager)
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
        receiver = receiver == address(0) ? _msgSender() : receiver;

        _revertIfNotWhitelisted(fleetCommander, receiver, _msgSender());
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetAsset = IERC20(fleet.asset());

        uint256 balance = fleetAsset.balanceOf(address(this));
        assets = assets == 0 ? balance : assets;

        if (assets > balance) revert InsufficientOutputAmount();

        fleetAsset.forceApprove(address(fleet), assets);
        shares = fleet.deposit(assets, receiver);

        emit FleetEntered(_msgSender(), fleetCommander, assets, shares);
    }

    /**
     * @notice Permit2 variant of `enterFleet`. Pulls `assets` of the FleetCommander's underlying
     *         from `owner` via a Permit2 witness-transfer signature and deposits into
     *         `fleetCommander` for `receiver`.
     * @dev This function intentionally omits `@inheritdoc` because its signature differs from the
     *      public (non-whitelist) `IAdmiralsQuarters.enterFleetWithPermit2` variant: the
     *      institutional build does not propagate the referral code on-chain. The supplied
     *      `referralCode` argument is therefore ignored and `bytes32(0)` is substituted into the
     *      witness payload. Off-chain signers MUST use `bytes32(0)` for the referral field or
     *      Permit2 signature verification will fail.
     * @param owner The account whose Permit2 nonce is consumed and whose underlying is pulled
     * @param fleetCommander The target FleetCommander to deposit into; must pass `_validateFleetCommander`
     * @param assets The exact amount of FleetCommander underlying to deposit; must equal
     *               `permitData.permitted.amount` (passing `0` is not supported unless the
     *               signature itself was issued for `0`)
     * @param referralCode Reserved for ABI parity with the public variant; ignored on-chain
     *                    (off-chain signers must pass `bytes32(0)`)
     * @param receiver The recipient of the FleetCommander shares
     * @param permitData Permit2 `PermitTransferFrom` payload signed by `owner`
     * @param signature `owner`'s signature over `permitData` and the witness payload
     * @return shares The FleetCommander shares minted to `receiver`
     */
    function enterFleetWithPermit2(
        address owner,
        address fleetCommander,
        uint256 assets,
        bytes calldata referralCode,
        address receiver,
        ISignatureTransfer.PermitTransferFrom calldata permitData,
        bytes calldata signature
    ) external payable onlyMulticall nonReentrant returns (uint256 shares) {
        _revertIfNotWhitelisted(fleetCommander, receiver, owner);
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetAsset = IERC20(fleet.asset());

        if (permitData.permitted.token != fleetAsset) revert InvalidToken();
        if (permitData.permitted.amount != assets) revert InvalidAmount();

        ISignatureTransfer(PERMIT2).permitWitnessTransferFrom(
            permitData,
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: assets
            }),
            owner,
            keccak256(
                abi.encode(
                    _FLEET_DEPOSIT_TYPEHASH,
                    address(fleet),
                    receiver,
                    // The whitelisted protocol variant does not utilize referral tracking.
                    // We utilize a zero-sentinel (bytes32(0)) in the witness payload to maintain
                    // architectural consistency and signature verification compatibility.
                    bytes32(0)
                )
            ),
            _WITNESS_TYPE_STRING,
            signature
        );

        fleetAsset.forceApprove(address(fleet), assets);

        shares = fleet.deposit(assets, receiver);
        emit FleetEntered(owner, fleetCommander, assets, shares);
    }

    /// @inheritdoc IAdmiralsQuartersWhitelist
    function exitFleet(
        address fleetCommander,
        uint256 assets
    ) external payable onlyMulticall nonReentrant returns (uint256 shares) {
        _revertIfNotWhitelisted(fleetCommander, _msgSender());
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

    /**
     * @dev Wires the inherited `Whitelist` helper to the same `ProtocolAccessManagerV2` instance
     *      configured for `ProtocolAccessManagedV2`.
     */
    function _getAccessManager() internal view override returns (address) {
        return address(_accessManager);
    }

    /**
     * @dev Performs a raw call to the 1inch router with caller-supplied calldata. The output amount
     *      is measured as the post-call balance delta of `toToken`, then asserted against
     *      `minTokensReceived` to bound slippage.
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param assets The amount of `fromToken` approved for the router
     * @param minTokensReceived The minimum acceptable amount of `toToken` received
     * @param swapCalldata The pre-built 1inch swap calldata
     * @return swappedAmount The actual amount of `toToken` received by this contract
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

    /// @dev Reverts with `InvalidFleetCommander` unless `fleetCommander` is registered as active in
    ///      `HarborCommand`. Prevents callers from routing funds into arbitrary addresses.
    function _validateFleetCommander(address fleetCommander) internal view {
        if (!_isFleetCommander(fleetCommander)) {
            revert InvalidFleetCommander();
        }
    }

    /// @dev Returns whether `account` is a FleetCommander currently registered with `HarborCommand`.
    function _isFleetCommander(address account) internal view returns (bool) {
        return IHarborCommand(harborCommand()).activeFleetCommanders(account);
    }

    /// @dev Rejects the zero address and any address that is itself a registered FleetCommander —
    ///      a FleetCommander's share token should never be used as a generic ERC-20 input here.
    function _validateToken(IERC20 token) internal view {
        if (address(token) == address(0) || _isFleetCommander(address(token)))
            revert InvalidToken();
    }

    /// @dev Rejects zero amounts.
    function _validateAmount(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    /// @dev Validates that the caller's declared native-token amount matches `msg.value` and that
    ///      the contract holds enough native balance to forward it (defends against accounting
    ///      mismatches when chained inside a multicall).
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
     * @notice Accepts native ETH transfers into the contract.
     * @dev Required so that `IWETH.withdraw` (called from `withdrawTokens`) can return unwrapped
     *      ETH to this contract before it is forwarded to the caller. Should not be used to fund
     *      the contract directly; stranded ETH must be reclaimed via `rescueTokens`.
     */
    receive() external payable {}

    /**
     * @notice Forwards a Merkle-rewards claim to a `SummerRewardsRedeemer`.
     * @dev Reverts with `InvalidRewardsRedeemer` if `rewardsRedeemer == address(0)`. The redeemer
     *      address is supplied per call rather than baked in, so multiple distributors are supported.
     * @param user Address to claim rewards for
     * @param indices Merkle leaf indices being claimed
     * @param amounts Reward amounts matching `indices`
     * @param proofs Merkle proofs matching `indices`
     * @param rewardsRedeemer Address of the `ISummerRewardsRedeemer` contract to call
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
        _validateToken(IERC20(vault));

        IERC4626 vaultToken = IERC4626(vault);

        // Get actual shares if 0 was passed
        shares = shares == 0 ? vaultToken.balanceOf(_msgSender()) : shares;

        vaultToken.redeem(shares, address(this), _msgSender());

        emit ERC4626PositionImported(_msgSender(), vault, shares);
    }
}
