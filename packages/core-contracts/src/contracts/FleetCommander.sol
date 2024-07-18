// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, ERC20, SafeERC20, ERC4626, IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {FleetCommanderParams, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommanderEvents} from "../events/IFleetCommanderEvents.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {CooldownEnforcer} from "../utils/CooldownEnforcer/CooldownEnforcer.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "../errors/FleetCommanderErrors.sol";
import "../libraries/PercentageUtils.sol";
import {console} from "forge-std/console.sol";

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
    address[] private _activeArks;
    IArk public bufferArk;
    mapping(address => bool) _isArkActive;
    uint256 public minFundsBufferBalance;
    uint256 public depositCap;
    Percentage public maxBufferWithdrawalPercentage;

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

        minFundsBufferBalance = params.initialMinimumFundsBufferBalance;
        maxBufferWithdrawalPercentage = params.initialMaximumBufferWithdrawal;
        depositCap = params.depositCap;
        bufferArk = IArk(params.bufferArk);
        _isArkActive[address(bufferArk)] = true;
    }

    /* PUBLIC - ACCESSORS */
    /// @inheritdoc IFleetCommander
    function arks() public view returns (address[] memory) {
        return _activeArks;
    }

    /* PUBLIC - USER */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(ERC4626, IFleetCommander) returns (uint256) {
        uint256 prevQueueBalance = bufferArk.totalAssets();
        _disembark(address(bufferArk), assets);

        super.withdraw(assets, receiver, owner);
        uint256 fundsBufferBalance = bufferArk.totalAssets();
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
        uint256 prevQueueBalance = bufferArk.totalAssets();
        uint256 assets = previewRedeem(shares);
        _disembark(address(bufferArk), assets);
        super.redeem(shares, receiver, owner);
        uint256 fundsBufferBalance = bufferArk.totalAssets();
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
        uint256 totalAssetsToWithdraw = assets;
        uint256 totalSharesToWithdraw = previewWithdraw(totalAssetsToWithdraw);
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
        address[] memory allArks = new address[](sortedArks.length + 1);
        for (uint256 i = 0; i < sortedArks.length; i++) {
            allArks[i] = sortedArks[i];
        }
        allArks[sortedArks.length] = address(bufferArk);

        for (uint256 i = 0; i < allArks.length; i++) {
            uint256 assetsInArk = IArk(allArks[i]).totalAssets();
            if (assetsInArk >= assets) {
                _disembark(allArks[i], assets);
                break;
            } else if (assetsInArk > 0) {
                _disembark(allArks[i], assetsInArk);
                assets -= assetsInArk;
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

        _setLastActionTimestamp(0);

        return totalAssetsToWithdraw;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override(ERC4626, IFleetCommander) returns (uint256) {
        uint256 prevQueueBalance = bufferArk.totalAssets();
        super.deposit(assets, receiver);
        _board(address(bufferArk), assets);
        uint256 fundsBufferBalance = bufferArk.totalAssets();

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
        uint256 prevQueueBalance = bufferArk.totalAssets();
        uint256 assets = super.mint(shares, to);
        _board(address(bufferArk), assets);
        uint256 fundsBufferBalance = bufferArk.totalAssets();

        emit FundsBufferBalanceUpdated(
            msg.sender,
            prevQueueBalance,
            fundsBufferBalance
        );

        return assets;
    }

    function totalAssets()
        public
        view
        override(ERC4626, IERC4626)
        returns (uint256 total)
    {
        total = 0;
        IArk[] memory allArks = new IArk[](_activeArks.length + 1);
        for (uint256 i = 0; i < _activeArks.length; i++) {
            allArks[i] = IArk(_activeArks[i]);
        }
        allArks[_activeArks.length] = bufferArk;
        for (uint256 i = 0; i < allArks.length; i++) {
            // TODO: are we sure we can make all `totalAssets` calls that will not revert (as per ERC4626)
            total += IArk(allArks[i]).totalAssets();
        }
        total += super.totalAssets();
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
                bufferArk.totalAssets().applyPercentage(
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
                    bufferArk.totalAssets().applyPercentage(
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

        if (!_isArkActive[address(toArk)]) {
            revert FleetCommanderArkNotFound(address(toArk));
        }

        uint256 targetArkMaxAllocation = toArk.maxAllocation();
        if (targetArkMaxAllocation == 0) {
            revert FleetCommanderCantRebalanceToArk(address(toArk));
        }

        if (address(fromArk) != address(bufferArk)) {
            if (address(fromArk) == address(0)) {
                revert FleetCommanderArkNotFound(address(fromArk));
            }

            if (!_isArkActive[address(fromArk)]) {
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
        if (currentAmount < targetArkMaxAllocation) {
            availableSpace = targetArkMaxAllocation - currentAmount;
            amount = (amount < availableSpace) ? amount : availableSpace;
        } else {
            // If currentAmount >= maxAllocation, we can't add more funds
            revert FleetCommanderCantRebalanceToArk(address(toArk));
        }

        _disembark(address(fromArk), amount);
        _board(address(toArk), amount);

        return amount;
    }

    function adjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown {
        _validateRebalanceData(rebalanceData);

        uint256 excessFunds = 0;

        if (bufferArk.totalAssets() > minFundsBufferBalance) {
            excessFunds = bufferArk.totalAssets() - minFundsBufferBalance;
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
            if (data.fromArk != address(bufferArk)) {
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

    function addArk(address ark) external onlyGovernor {
        _addArk(ark);
    }

    function addArks(address[] calldata _arkAddresses) external onlyGovernor {
        for (uint256 i = 0; i < _arkAddresses.length; i++) {
            _addArk(_arkAddresses[i]);
        }
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
        if (!_isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }

        uint256 oldMaxAllocation = IArk(ark).maxAllocation();
        IArk(ark).setMaxAllocation(newMaxAllocation);

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
        IERC20(asset()).approve(ark, amount);
        IArk(ark).board(amount);
    }

    function _disembark(address ark, uint256 amount) internal {
        IArk(ark).disembark(amount);
    }

    function _move(address fromArk, address toArk, uint256 amount) internal {}

    function _setupArks(address[] memory _arkAddresses) internal {
        for (uint256 i = 0; i < _arkAddresses.length; i++) {
            _addArk(_arkAddresses[i]);
        }
    }

    function _addArk(address ark) internal {
        if (ark == address(0)) {
            revert FleetCommanderInvalidArkAddress();
        }
        if (_isArkActive[ark]) {
            revert FleetCommanderArkAlreadyExists(ark);
        }
        if (IArk(ark).maxAllocation() == 0) {
            revert FleetCommanderArkMaxAllocationZero(ark);
        }

        _isArkActive[ark] = true;
        _activeArks.push(ark);
        emit ArkAdded(ark);
    }

    function _removeArk(address ark) internal {
        if (!_isArkActive[ark]) {
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

        _isArkActive[ark] = false;
        emit ArkRemoved(ark);
    }

    /* INTERNAL - VALIDATIONS */
    function _validateArkRemoval(address ark) internal view {
        IArk _ark = IArk(ark);
        if (_ark.maxAllocation() > 0) {
            revert FleetCommanderArkMaxAllocationGreaterThanZero(ark);
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
