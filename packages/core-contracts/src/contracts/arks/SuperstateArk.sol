// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../ArkWithWithdrawalRequest.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";

/**
 * @title Standard ERC20 Interface
 * @notice Includes standard functions required for USDC, USTB, and USCC interactions.
 */
interface IERC20Standard is IERC20Metadata {
    function balanceOf(address account) external view override returns (uint256);
    function transfer(address to, uint256 value) external override returns (bool);
    function approve(address spender, uint256 value) external override returns (bool);
    function transferFrom(address from, address to, uint256 value) external override returns (bool);
}

/**
 * @title Superstate Subscribe Interface
 * @notice Interface for the Superstate subscription mechanism.
 */
interface ISuperstateSubscribe {
    /**
     * @notice Subscribes USDC to mint Superstate Fund Tokens to a designated address.
     * @dev The caller MUST be on the Superstate on-chain Allowlist, and the `to` address must be allowlisted.
     * @param amount The amount of USDC to subscribe.
     * @param to The address to receive the minted fund tokens.
     */
    function subscribe(uint256 amount, address to) external;
}

/**
 * @title Superstate Redeem Interface
 * @notice Interface for the Superstate redemption mechanism.
 */
interface ISuperstateRedeem {
    /**
     * @notice Redeems Superstate Fund Tokens for USDC.
     * @dev The caller MUST be on the Superstate on-chain Allowlist, and the `to` address must be allowlisted.
     * @param amount The amount of fund tokens to redeem.
     * @param to The address to receive the USDC payout.
     */
    function redeem(uint256 amount, address to) external;
}

/**
 * @title Superstate Continuous Price Oracle Interface
 * @notice Interface to read the current NAV (share price) from Superstate's Oracle or Chainlink.
 */
interface ISuperstateOracle {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function decimals() external view returns (uint8);
}

/**
 * @title SuperstateArk
 * @notice Integration contract for programmatically interacting with Superstate's Tokenized Funds (USTB and USCC).
 * @dev 
 * **Allowlist Requirements:**
 * Superstate funds are regulated securities. The address interacting with the Superstate Subscribe/Redeem
 * contracts (this Ark) MUST be on the Superstate on-chain Allowlist. If not, transaction calls will revert.
 * 
 * **Timing Nuances & Settlement:**
 * - USTB (Short Duration US Gov Securities): Processes nearly instantly during US market hours.
 * - USCC (Crypto Carry Fund): Operates on a T+1 NAV strike and T+2 mint/payout schedule.
 * 
 * Because of the T+1/T+2 delays with USCC (and occasionally USTB), this contract utilizes a pending deposit
 * and pending withdrawal architecture (based on WisdomTreeArk) to account for asynchronous settlement.
 * Deposits and Withdrawals are initiated, and a Keeper clears them once the actual assets/shares arrive.
 */
contract SuperstateArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20Standard;
    using SafeERC20 for IERC20;
    using PriceUtils for Price;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;
    Percentage public constant MAX_SWEEP_SLIPPAGE = Percentage.wrap(PERCENTAGE_FACTOR / 2);
    Percentage public constant MAX_DEPOSIT_SLIPPAGE = Percentage.wrap(PERCENTAGE_FACTOR / 2);
    uint256 public constant ORACLE_HEARTBEAT_TIMEOUT = 24 hours;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidOracleAddress();
    error InvalidShareTokenAddress();
    error InvalidSubscribeAddress();
    error InvalidRedeemAddress();

    error OraclePriceNotPositive();
    error StaleOraclePrice();
    error InsufficientPendingDeposit();
    error PendingDepositActive();
    error ArkIsFrozen();
    error InvalidDepositSlippage(Percentage newSlippage, Percentage maxSlippage);
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    error InsufficientAssetsReturned(uint256 receivedAssets, uint256 expectedShares, uint256 receivedShares);
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);
    error NotAllowlisted();
    error InsufficientYield();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionExecuted(uint256 usdcAmount, address target);
    event RedemptionExecuted(uint256 shareAmount, uint256 expectedUsdc);
    event PendingDepositCleared(uint256 amountCleared);
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);
    event SweepSlippageUpdated(Percentage oldSweepSlippage, Percentage newSweepSlippage);
    event DepositSlippageUpdated(Percentage oldDepositSlippage, Percentage newDepositSlippage);

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Superstate fund token contract (USTB or USCC)
    IERC20Standard public immutable shareToken;

    /// @notice The Superstate Subscribe contract
    ISuperstateSubscribe public immutable superstateSubscribe;

    /// @notice The Superstate Redeem contract
    ISuperstateRedeem public immutable superstateRedeem;

    /// @notice Superstate/Chainlink price feed: price of 1 Superstate share denominated in USDC
    ISuperstateOracle public immutable oracle;

    uint8 public immutable oracleDecimals;
    uint8 public immutable assetDecimals;
    uint8 public immutable shareDecimals;
    uint256 public immutable ONE_ASSET;

    /// @notice Validated USDC amounts subscribed, awaiting minting of fund tokens (handles T+1/T+2 delays)
    uint256 public pendingDepositAssets;

    /// @notice Frozen share balance used while deposits are pending to prevent double-counting
    uint256 public cachedShareBalance;

    /// @notice Expected returning USDC amount equivalent to redeemed shares (handles T+1/T+2 delays)
    uint256 public pendingWithdrawalShares;

    bool public isArkFrozen;
    Percentage public sweepSlippage;
    Percentage public depositSlippage;
    uint256 private _frozenTotalAssets;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _shareToken,
        address _superstateSubscribe,
        address _superstateRedeem,
        address _oracle,
        Percentage _sweepSlippage,
        Percentage _depositSlippage,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SWAP_SLIPPAGE) {
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();
        if (_superstateSubscribe == address(0)) revert InvalidSubscribeAddress();
        if (_superstateRedeem == address(0)) revert InvalidRedeemAddress();
        if (_oracle == address(0)) revert InvalidOracleAddress();

        shareToken = IERC20Standard(_shareToken);
        superstateSubscribe = ISuperstateSubscribe(_superstateSubscribe);
        superstateRedeem = ISuperstateRedeem(_superstateRedeem);
        oracle = ISuperstateOracle(_oracle);

        if (_sweepSlippage > MAX_SWEEP_SLIPPAGE) {
            revert InvalidSweepSlippage(_sweepSlippage, MAX_SWEEP_SLIPPAGE);
        }
        if (_depositSlippage > MAX_DEPOSIT_SLIPPAGE) {
            revert InvalidDepositSlippage(_depositSlippage, MAX_DEPOSIT_SLIPPAGE);
        }
        sweepSlippage = _sweepSlippage;
        depositSlippage = _depositSlippage;

        oracleDecimals = ISuperstateOracle(_oracle).decimals();
        shareDecimals = IERC20Standard(_shareToken).decimals();
        assetDecimals = IERC20Standard(_params.asset).decimals();
        ONE_ASSET = 10 ** assetDecimals;
    }

    modifier onlyNotFrozen() {
        if (isArkFrozen) revert ArkIsFrozen();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override(Ark, IArk) returns (uint256 assets) {
        if (isArkFrozen) {
            return _frozenTotalAssets;
        }

        uint256 currentShares = pendingDepositAssets > 0
            ? cachedShareBalance
            : shareToken.balanceOf(address(this));
        uint256 totalShares = currentShares + pendingWithdrawalShares;
        assets = _sharesToAssets(totalShares) + pendingDepositAssets;
    }

    function assetsInWithdrawalQueue() public view override returns (uint256) {
        return _sharesToAssets(pendingWithdrawalShares);
    }

    function withdrawalRequestId() external pure override returns (uint256) {
        return 0;
    }

    function isWithdrawalClaimRequired() external pure override returns (bool) {
        return false;
    }

    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                          KEEPER & LIFECYCLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Removes a fulfilled deposit amount from `pendingDepositAssets`.
     * @dev Called by the keeper after Superstate issues shares (T+1/T+2) to this contract.
     */
    function clearPendingDeposit() external onlyKeeper {
        _validateReceivedShares(pendingDepositAssets);
        _clearPendingDeposit(pendingDepositAssets);
    }

    /**
     * @notice Removes a fulfilled partial deposit amount from `pendingDepositAssets`.
     */
    function clearPendingDeposit(uint256 amount) external onlyKeeper {
        _validateReceivedShares(amount);
        _clearPendingDeposit(amount);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Queries the on-chain Oracle to calculate expected USDC, and burns fund tokens via Redeem function.
     *      Ensures the resulting USDC is routed back to the caller's whitelisted Payout Destination (tracked via pendingWithdrawalShares).
     */
    function requestWithdrawal(uint256 amount) external override onlyKeeper onlyNotFrozen {
        if (pendingDepositAssets > 0) revert PendingDepositActive();

        uint256 sharesToRedeem = _assetsToShares(amount);

        pendingWithdrawalShares += sharesToRedeem;

        // Approve and execute redemption call to burn tokens and receive USDC
        shareToken.forceApprove(address(superstateRedeem), sharesToRedeem);
        superstateRedeem.redeem(sharesToRedeem, address(this));

        emit RedemptionExecuted(sharesToRedeem, amount);
        emit WithdrawalRequested(amount, 0);
    }

    function claimWithdrawal() external override onlyKeeper {
        // No-op: Superstate asynchronous process delivers USDC directly.
    }

    function withdrawUsingSwap(uint256, bytes calldata) external override onlyKeeper nonReentrant {
        // No-op
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Sweeps returned USDC to buffer and clears `pendingWithdrawalShares`.
     * @dev Called by keeper after Superstate returns the USDC equivalent for the retired shares (T+1/T+2).
     */
    function sweep() public override onlyKeeper nonReentrant returns (address[] memory sweptTokens, uint256[] memory sweptAmounts) {
        IERC20 asset = config.asset;

        uint256 returnedAssets = asset.balanceOf(address(this));
        uint256 returnedShares = _assetsToShares(returnedAssets);

        uint256 pendingWithdrawalSharesMinusSlippage = pendingWithdrawalShares.subtractPercentage(sweepSlippage);

        if (returnedShares < pendingWithdrawalSharesMinusSlippage) {
            revert InsufficientAssetsReturned(returnedAssets, pendingWithdrawalShares, returnedShares);
        }

        return _sweep(returnedAssets);
    }

    function emergencySweep() external onlyGovernor nonReentrant returns (address[] memory sweptTokens, uint256[] memory sweptAmounts) {
        uint256 returnedAssets = config.asset.balanceOf(address(this));
        return _sweep(returnedAssets);
    }

    function emergencyClearPendingDeposit(uint256 amount) external onlyGovernor {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        _clearPendingDeposit(amount);
    }

    function setArkFrozen(bool _isArkFrozen, uint256 frozenTotalAssets) external onlyKeeper {
        if (_isArkFrozen) {
            _frozenTotalAssets = frozenTotalAssets == type(uint256).max ? totalAssets() : frozenTotalAssets;
        }
        isArkFrozen = _isArkFrozen;
        emit ArkIsFrozenUpdated(_isArkFrozen, _frozenTotalAssets);
    }

    function setSweepSlippage(Percentage newSweepSlippage) external onlyKeeper {
        if (newSweepSlippage > MAX_SWEEP_SLIPPAGE) revert InvalidSweepSlippage(newSweepSlippage, MAX_SWEEP_SLIPPAGE);
        emit SweepSlippageUpdated(sweepSlippage, newSweepSlippage);
        sweepSlippage = newSweepSlippage;
    }

    function setDepositSlippage(Percentage newDepositSlippage) external onlyKeeper {
        if (newDepositSlippage > MAX_DEPOSIT_SLIPPAGE) revert InvalidDepositSlippage(newDepositSlippage, MAX_DEPOSIT_SLIPPAGE);
        emit DepositSlippageUpdated(depositSlippage, newDepositSlippage);
        depositSlippage = newDepositSlippage;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _board(uint256 amount, bytes calldata) internal override onlyNotFrozen {
        if (pendingDepositAssets > 0) {
            revert PendingDepositActive();
        }

        cachedShareBalance = shareToken.balanceOf(address(this));
        pendingDepositAssets += amount;

        IERC20Standard(address(config.asset)).forceApprove(address(superstateSubscribe), amount);
        superstateSubscribe.subscribe(amount, address(this));

        emit SubscriptionExecuted(amount, address(this));
    }

    function _disembark(uint256, bytes calldata) internal view override onlyNotFrozen {}

    function _withdrawableTotalAssets() internal pure override returns (uint256) {
        return 0;
    }

    function _harvest(bytes calldata) internal pure override returns (address[] memory rewardTokens, uint256[] memory rewardAmounts) {
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    function _validateBoardData(bytes calldata) internal override {}
    function _validateDisembarkData(bytes calldata) internal override {}

    function _sweep(uint256 amountToSweep) internal returns (address[] memory sweptTokens, uint256[] memory sweptAmounts) {
        IERC20 asset = config.asset;

        sweptTokens = new address[](1);
        sweptAmounts = new uint256[](1);

        sweptTokens[0] = address(asset);
        sweptAmounts[0] = amountToSweep;

        pendingWithdrawalShares = 0;

        address bufferArk = address(IFleetCommander(config.commander).bufferArk());
        emit Disembarked(msg.sender, address(asset), sweptAmounts[0]);

        if (sweptAmounts[0] > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, sweptAmounts[0]);
            IArk(bufferArk).board(sweptAmounts[0], bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }

    /*//////////////////////////////////////////////////////////////
                            ORACLE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        if (shares == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.invert().quote(shares);
    }

    function _assetsToShares(uint256 assetAmount) internal view returns (uint256) {
        if (assetAmount == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.quote(assetAmount);
    }

    function _fetchOracleAssetPerSharePrice() internal view returns (Price memory) {
        (, int256 answer, , uint256 updatedAt, ) = oracle.latestRoundData();
        if (answer <= 0) revert OraclePriceNotPositive();

        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT_TIMEOUT) {
            revert StaleOraclePrice();
        }

        return toPriceFromOraclePrice(
            10 ** shareDecimals,
            answer,
            oracleDecimals,
            assetDecimals
        );
    }

    function _clearPendingDeposit(uint256 amountCleared) internal {
        pendingDepositAssets -= amountCleared;
        cachedShareBalance = shareToken.balanceOf(address(this));
        emit PendingDepositCleared(amountCleared);
    }

    function _validateReceivedShares(uint256 amount) internal view {
        if (amount > pendingDepositAssets) revert InsufficientPendingDeposit();
        uint256 currentShares = shareToken.balanceOf(address(this));
        uint256 newlyArrivedShares = currentShares - cachedShareBalance;
        uint256 expectedShares = _assetsToShares(amount);
        uint256 expectedSharesMinusSlippage = expectedShares.subtractPercentage(depositSlippage);

        if (newlyArrivedShares < expectedSharesMinusSlippage) {
            revert SharesNotArrived(expectedShares, newlyArrivedShares);
        }
    }
}
