// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, ERC20, SafeERC20, ERC4626, IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {FleetCommanderParams, ArkConfiguration, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommanderEvents} from "../events/IFleetCommanderEvents.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {CooldownEnforcer} from "../utils/CooldownEnforcer/CooldownEnforcer.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "../errors/FleetCommanderErrors.sol";
import "../libraries/PercentageUtils.sol";
import {TipAccruer} from "./TipAccruer.sol";

/**
 * @custom:see IFleetCommander
 */
contract FleetCommander is
    IFleetCommander,
    ERC4626,
    ProtocolAccessManaged,
    CooldownEnforcer
{
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    mapping(address => ArkConfiguration) private _arks;
    address[] private _activeArks;
    uint256 public fundsBufferBalance;
    uint256 public minFundsBufferBalance;
    uint256 public depositCap;
    Percentage public maxBufferWithdrawalPercentage;

    ITipAccruer public immutable tipAccruer;

    uint256 public constant MAX_REBALANCE_OPERATIONS = 10;

    constructor(
        FleetCommanderParams memory params
    )
        ERC4626(IERC20(params.asset))
        ERC20(params.name, params.symbol)
        ProtocolAccessManaged(params.accessManager)
        CooldownEnforcer(params.initialRebalanceCooldown, false)
    {
        _setupArks(params.initialArks);

        tipAccruer = TipAccruer(params.initialTipRate, params.initialTipJar, address(this));
        minFundsBufferBalance = params.initialMinimumFundsBufferBalance;
        maxBufferWithdrawalPercentage = params.initialMaximumBufferWithdrawal;
        depositCap = params.depositCap;
    }

    /* PUBLIC - ACCESSORS */
    /// @inheritdoc IFleetCommander
    function arks(
        address _address
    ) external view override returns (ArkConfiguration memory) {
        return _arks[_address];
    }

    /* PUBLIC - USER */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(ERC4626, IFleetCommander) returns (uint256) {
        tip();
        super.withdraw(assets, receiver, owner);

        uint256 prevQueueBalance = fundsBufferBalance;
        fundsBufferBalance = fundsBufferBalance - assets;

        emit FundsBufferBalanceUpdated(
            msg.sender,
            prevQueueBalance,
            fundsBufferBalance
        );

        return assets;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override(ERC4626, IERC4626) returns (uint256) {
        tip();
        uint256 assets = super.redeem(shares, receiver, owner);
        uint256 prevQueueBalance = fundsBufferBalance;
        fundsBufferBalance = fundsBufferBalance - assets;

        emit FundsBufferBalanceUpdated(
            msg.sender,
            prevQueueBalance,
            fundsBufferBalance
        );

        return assets;
    }

    function forceWithdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(IFleetCommander) returns (uint256) {
        tip();
        uint256 totalAssetsToWithdraw = assets;
        uint256 totalSharesToWithdraw = previewWithdraw(totalAssetsToWithdraw);
        uint256 assetsToWithdrawFromArks = totalAssetsToWithdraw -
            fundsBufferBalance;
        address[] memory sortedArks = new address[](_activeArks.length);
        uint256[] memory rates = new uint256[](_activeArks.length);

        // Collect rates and corresponding addresses
        for (uint256 i = 0; i < _activeArks.length; i++) {
            rates[i] = IArk(_activeArks[i]).rate();
            sortedArks[i] = _activeArks[i];
        }

        for (uint256 i = 0; i < rates.length; i++) {
            for (uint256 j = i + 1; j < rates.length; j++) {
                if (rates[i] > rates[j]) {
                    // Swap rates
                    uint256 tempRate = rates[i];
                    rates[i] = rates[j];
                    rates[j] = tempRate;

                    // Swap corresponding arks
                    address tempArk = sortedArks[i];
                    sortedArks[i] = sortedArks[j];
                    sortedArks[j] = tempArk;
                }
            }
        }

        for (uint256 i = 0; i < sortedArks.length; i++) {
            uint256 assetsInArk = IArk(sortedArks[i]).totalAssets();
            if (assetsInArk >= assetsToWithdrawFromArks) {
                _disembark(sortedArks[i], assetsToWithdrawFromArks);
                break;
            } else if (assetsInArk > 0) {
                _disembark(sortedArks[i], assetsInArk);
                assetsToWithdrawFromArks -= assetsInArk;
            } else {
                continue;
            }
        }

        _withdraw(
            _msgSender(),
            receiver,
            owner,
            totalAssetsToWithdraw,
            totalSharesToWithdraw
        );
        fundsBufferBalance -= totalAssetsToWithdraw;

        _setLastActionTimestamp(0);

        return totalAssetsToWithdraw;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override(ERC4626, IFleetCommander) returns (uint256) {
        tip();
        super.deposit(assets, receiver);

        uint256 prevQueueBalance = fundsBufferBalance;
        fundsBufferBalance = fundsBufferBalance + assets;

        emit FundsBufferBalanceUpdated(
            msg.sender,
            prevQueueBalance,
            fundsBufferBalance
        );

        return assets;
    }

    function mint(
        uint256 shares,
        address to
    ) public override(ERC4626, IERC4626) returns (uint256) {
        tip();
        uint256 assets = super.mint(shares, to);
        uint256 prevQueueBalance = fundsBufferBalance;
        fundsBufferBalance = fundsBufferBalance + assets;

        emit FundsBufferBalanceUpdated(
            msg.sender,
            prevQueueBalance,
            fundsBufferBalance
        );

        return assets;
    }

    function tip() {
        tipAccruer.accrueTip();
    }

    function totalAssets()
        public
        view
        override(ERC4626, IERC4626)
        returns (uint256 total)
    {
        total = 0;
        for (uint256 i = 0; i < _activeArks.length; i++) {
            // TODO: are we sure we can make all `totalAssets` calls that will not revert (as per ERC4626)
            total += IArk(_activeArks[i]).totalAssets();
        }
        total += fundsBufferBalance;
    }

    function maxDeposit(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 maxAssets = totalAssets() > depositCap
            ? 0
            : depositCap - totalAssets();

        return Math.min(maxAssets, IERC20(asset()).balanceOf(owner));
    }

    function maxMint(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 maxAssets = totalAssets() > depositCap
            ? 0
            : depositCap - totalAssets();
        return
            previewDeposit(
                Math.min(maxAssets, IERC20(asset()).balanceOf(owner))
            );
    }

    function maxWithdraw(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        return
            Math.min(
                fundsBufferBalance.applyPercentage(
                    maxBufferWithdrawalPercentage
                ),
                previewRedeem(balanceOf(owner))
            );
    }

    function maxRedeem(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        return
            Math.min(
                previewWithdraw(
                    fundsBufferBalance.applyPercentage(
                        maxBufferWithdrawalPercentage
                    )
                ),
                balanceOf(owner)
            );
    }

    /* EXTERNAL - KEEPER */
    function rebalance(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown {
        tip();
        _rebalance(rebalanceData);
    }

    function _reallocateAssets(
        RebalanceData memory data
    ) internal returns (uint256) {
        IArk toArk = IArk(data.toArk);
        IArk fromArk = IArk(data.fromArk);
        uint256 amount = data.amount;
        if (address(toArk) == address(0)) {
            revert FleetCommanderArkNotFound(address(toArk));
        }
        if (address(fromArk) == address(0)) {
            revert FleetCommanderArkNotFound(address(fromArk));
        }
        if (amount == 0) {
            revert FleetCommanderRebalanceAmountZero(address(toArk));
        }
        ArkConfiguration memory targetArkConfiguration = _arks[address(toArk)];

        if (
            targetArkConfiguration.ark == address(0) ||
            targetArkConfiguration.maxAllocation == 0
        ) {
            revert FleetCommanderArkNotFound(address(toArk));
        }

        if (targetArkConfiguration.maxAllocation == 0) {
            revert FleetCommanderCantRebalanceToArk(address(toArk));
        }

        if (address(fromArk) != address(this)) {
            ArkConfiguration memory sourceArkConfiguration = _arks[
                address(fromArk)
            ];
            if (sourceArkConfiguration.ark == address(0)) {
                revert FleetCommanderArkNotFound(address(fromArk));
            }

            uint256 targetArkRate = toArk.rate();
            uint256 sourceArkRate = fromArk.rate();

            if (targetArkRate < sourceArkRate) {
                revert FleetCommanderTargetArkRateTooLow(
                    address(toArk),
                    targetArkRate,
                    sourceArkRate
                );
            }
        }

        uint256 currentAmount = toArk.totalAssets();
        uint256 availableSpace;
        if (currentAmount < targetArkConfiguration.maxAllocation) {
            availableSpace =
                targetArkConfiguration.maxAllocation -
                currentAmount;
            amount = (amount < availableSpace) ? amount : availableSpace;
        } else {
            // If currentAmount >= maxAllocation, we can't add more funds
            revert FleetCommanderCantRebalanceToArk(address(toArk));
        }

        if (address(fromArk) == address(this)) {
            // rebalance from the funds buffer
            _board(address(toArk), amount);
        } else {
            // rebalance from one ark to another
            _disembark(address(fromArk), amount);
            _board(address(toArk), amount);
        }

        return amount;
    }

    function adjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown {
        tip();
        _validateRebalanceData(rebalanceData);

        uint256 excessFunds = 0;

        if (fundsBufferBalance > minFundsBufferBalance) {
            excessFunds = fundsBufferBalance - minFundsBufferBalance;
        } else {
            revert FleetCommanderNoExcessFunds();
        }

        uint256 totalMoved = 0;
        for (
            uint256 i = 0;
            i < rebalanceData.length && totalMoved < excessFunds;
            i++
        ) {
            RebalanceData memory data = rebalanceData[i];
            if (data.fromArk != address(this)) {
                revert FleetCommanderInvalidSourceArk(data.fromArk);
            }

            uint256 remainingExcess = excessFunds - totalMoved;
            uint256 amountToMove = (data.amount < remainingExcess)
                ? data.amount
                : remainingExcess;
            RebalanceData memory adjustedData = RebalanceData({
                fromArk: data.fromArk,
                toArk: data.toArk,
                amount: amountToMove
            });

            uint256 moved = _reallocateAssets(adjustedData);
            totalMoved += moved;
        }

        if (totalMoved == 0) {
            revert FleetCommanderNoFundsMoved();
        }

        if (totalMoved > excessFunds) {
            revert FleetCommanderMovedMoreThanAvailable();
        }

        emit FleetCommanderBufferAdjusted(msg.sender, totalMoved);
    }

    /* EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external onlyGovernor {
        depositCap = newCap;
        emit DepositCapUpdated(newCap);
    }

    function setFeeAddress(address newAddress) external onlyGovernor {}

    function addArk(address ark, uint256 maxAllocation) external onlyGovernor {
        _addArk(ark, maxAllocation);
    }

    function removeArk(address ark) external onlyGovernor {
        _removeArk(ark);
    }

    function setMaxAllocation(
        address ark,
        uint256 newMaxAllocation
    ) external onlyGovernor {
        if (newMaxAllocation == 0) {
            revert FleetCommanderArkMaxAllocationZero(ark);
        }
        if (_arks[ark].ark == address(0)) {
            revert FleetCommanderArkNotFound(ark);
        }

        uint256 oldMaxAllocation = _arks[ark].maxAllocation;
        _arks[ark].maxAllocation = newMaxAllocation;

        // Update _activeArks if necessary
        bool wasActive = oldMaxAllocation > 0;
        bool isNowActive = newMaxAllocation > 0;

        if (!wasActive && isNowActive) {
            _activeArks.push(ark);
        } else if (wasActive && !isNowActive) {
            for (uint256 i = 0; i < _activeArks.length; i++) {
                if (_activeArks[i] == ark) {
                    _activeArks[i] = _activeArks[_activeArks.length - 1];
                    _activeArks.pop();
                    break;
                }
            }
        }

        emit ArkMaxAllocationUpdated(ark, newMaxAllocation);
    }

    function setMinBufferBalance(uint256 newBalance) external onlyGovernor {
        minFundsBufferBalance = newBalance;
        emit FleetCommanderMinFundsBufferBalanceUpdated(newBalance);
    }

    function updateRebalanceCooldown(
        uint256 newCooldown
    ) external onlyGovernor {
        _updateCooldown(newCooldown);
    }

    function forceRebalance(
        RebalanceData[] calldata rebalanceData
    ) external onlyGovernor {
        _rebalance(rebalanceData);
    }

    function emergencyShutdown() external onlyGovernor {}

    /* PUBLIC - FEES */
    function mintSharesAsFees() public {}

    /* PUBLIC - ERC20 */
    function transfer(
        address,
        uint256
    ) public pure override(IERC20, ERC20) returns (bool) {
        revert FleetCommanderTransfersDisabled();
    }

    /* INTERNAL - REBALANCE */
    function _rebalance(RebalanceData[] calldata rebalanceData) internal {
        _validateRebalanceData(rebalanceData);
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            _reallocateAssets(rebalanceData[i]);
        }
        emit Rebalanced(msg.sender, rebalanceData);
    }

    /* INTERNAL - ARK */
    function _board(address ark, uint256 amount) internal {
        fundsBufferBalance -= amount;
        IERC20(asset()).approve(ark, amount);
        IArk(ark).board(amount);
    }

    function _disembark(address ark, uint256 amount) internal {
        fundsBufferBalance += amount;
        IArk(ark).disembark(amount);
    }

    function _move(address fromArk, address toArk, uint256 amount) internal {}

    function _setupArks(ArkConfiguration[] memory _arkConfigurations) internal {
        for (uint256 i = 0; i < _arkConfigurations.length; i++) {
            _addArk(
                _arkConfigurations[i].ark,
                _arkConfigurations[i].maxAllocation
            );
        }
    }

    function _addArk(address ark, uint256 maxAllocation) internal {
        if (ark == address(0)) {
            revert FleetCommanderInvalidArkAddress();
        }
        if (_arks[ark].ark != address(0)) {
            revert FleetCommanderArkAlreadyExists(ark);
        }
        if (maxAllocation == 0) {
            revert FleetCommanderArkMaxAllocationZero(ark);
        }

        _arks[ark] = ArkConfiguration(ark, maxAllocation);
        _activeArks.push(ark);
        emit ArkAdded(ark, maxAllocation);
    }

    function _removeArk(address ark) internal {
        if (_arks[ark].ark == address(0)) {
            revert FleetCommanderArkNotFound(ark);
        }

        // Remove from _activeArks if present
        for (uint256 i = 0; i < _activeArks.length; i++) {
            if (_activeArks[i] == ark) {
                _validateArkRemoval(ark);
                _activeArks[i] = _activeArks[_activeArks.length - 1];
                _activeArks.pop();
                break;
            }
        }

        delete _arks[ark];
        emit ArkRemoved(ark);
    }

    /* INTERNAL - VALIDATIONS */
    function _validateArkRemoval(address ark) internal view {
        IArk _ark = IArk(ark);
        if (_ark.depositCap() > 0) {
            revert FleetCommanderArkDepositCapGreaterThanZero(ark);
        }

        if (_ark.totalAssets() != 0) {
            revert FleetCommanderArkAssetsNotZero(ark);
        }
    }

    function _validateRebalanceData(
        RebalanceData[] calldata rebalanceData
    ) internal pure {
        if (rebalanceData.length > MAX_REBALANCE_OPERATIONS) {
            revert FleetCommanderRebalanceTooManyOperations(
                rebalanceData.length
            );
        }
        if (rebalanceData.length == 0) {
            revert FleetCommanderRebalanceNoOperations();
        }
    }
}
