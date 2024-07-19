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
        uint256 shares = previewWithdraw(assets);
        if (
            _msgSender() != owner &&
            IERC20(address(this)).allowance(owner, _msgSender()) < shares
        ) {
            revert FleetCommanderUnauthorizedWithdrawal(_msgSender(), owner);
        }

        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        _disembark(address(bufferArk), assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            bufferArk.totalAssets()
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

        if (
            _msgSender() != owner &&
            IERC20(address(this)).allowance(owner, _msgSender()) < shares
        ) {
            revert FleetCommanderUnauthorizedRedemption(_msgSender(), owner);
        }

        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        _disembark(address(bufferArk), assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            bufferArk.totalAssets()
        );

        return assets;
    }

    function forceWithdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(IFleetCommander) returns (uint256) {
        if (
            _msgSender() != owner &&
            IERC20(address(this)).allowance(owner, _msgSender()) < assets
        ) {
            revert FleetCommanderUnauthorizedWithdrawal(_msgSender(), owner);
        }
        uint256 maxAssets = maxForceWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

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

        uint256 maxAssets = maxDeposit(_msgSender());
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(_msgSender(), assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        _board(address(bufferArk), assets);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            bufferArk.totalAssets()
        );

        return assets;
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override(ERC4626, IERC4626) returns (uint256) {
        uint256 prevQueueBalance = bufferArk.totalAssets();

        uint256 maxShares = maxMint(_msgSender());
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(_msgSender(), shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        _board(address(bufferArk), assets);
        uint256 fundsBufferBalance = bufferArk.totalAssets();

        emit FundsBufferBalanceUpdated(
            _msgSender(),
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
            Math.min(bufferArk.totalAssets(), previewRedeem(balanceOf(owner)));
    }

    function maxForceWithdraw(address owner) public view returns (uint256) {
        return previewRedeem(balanceOf(owner));
    }

    function maxRedeem(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        return
            Math.min(
                previewWithdraw(bufferArk.totalAssets()),
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
        uint256 toArkMaxAllocation = toArk.maxAllocation();

        if (address(toArk) != address(bufferArk)) {
            uint256 toArkRate = toArk.rate();
            uint256 fromArkRate = fromArk.rate();

            if (toArkRate < fromArkRate) {
                revert FleetCommanderTargetArkRateTooLow(
                    address(toArk),
                    toArkRate,
                    fromArkRate
                );
            }
        }

        uint256 toArkAllocation = toArk.totalAssets();
        uint256 availableAllocation;
        if (toArkAllocation < toArkMaxAllocation) {
            availableAllocation = toArkMaxAllocation - toArkAllocation;
            amount = (amount < availableAllocation)
                ? amount
                : availableAllocation;
        } else {
            // If toArkAllocation >= maxAllocation, we can't add more funds
            revert FleetCommanderCantRebalanceToArk(address(toArk));
        }
        _move(address(fromArk), address(toArk), amount);

        return amount;
    }

    function adjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown {
        _validateAdjustBufferData(rebalanceData);

        uint256 totalMoved = _rebalance(rebalanceData);

        uint256 finalBufferBalance = bufferArk.totalAssets();
        if (finalBufferBalance < minFundsBufferBalance) {
            revert FleetCommanderInsufficientBuffer();
        }

        emit FleetCommanderBufferAdjusted(_msgSender(), totalMoved);
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
    function _rebalance(
        RebalanceData[] calldata rebalanceData
    ) internal returns (uint256 totalMoved) {
        _validateRebalanceData(rebalanceData);
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            totalMoved += _reallocateAssets(rebalanceData[i]);
        }
        emit Rebalanced(_msgSender(), rebalanceData);
    }

    /* INTERNAL - ARK */
    function _board(address ark, uint256 amount) internal {
        IERC20(asset()).approve(ark, amount);
        IArk(ark).board(amount);
    }

    function _disembark(address ark, uint256 amount) internal {
        IArk(ark).disembark(amount, address(this));
    }

    function _move(address fromArk, address toArk, uint256 amount) internal {
        IArk(fromArk).disembark(amount, toArk);
    }

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

    /**
     * @notice Validates if an Ark can be safely removed from the Fleet Commander
     * @dev This function checks two conditions:
     *      1. The Ark's max allocation must be zero
     *      2. The Ark must not hold any assets
     * These conditions ensure that the Ark is effectively decommissioned before removal
     * @param ark The address of the Ark to be removed
     * @custom:error FleetCommanderArkMaxAllocationGreaterThanZero Thrown when the Ark's max allocation is not zero
     * @custom:error FleetCommanderArkAssetsNotZero Thrown when the Ark still holds assets
     */
    function _validateArkRemoval(address ark) internal view {
        IArk _ark = IArk(ark);
        if (_ark.maxAllocation() > 0) {
            revert FleetCommanderArkMaxAllocationGreaterThanZero(ark);
        }

        if (_ark.totalAssets() != 0) {
            revert FleetCommanderArkAssetsNotZero(ark);
        }
    }

    /**
     * @notice Validates the data for adjusting the buffer
     * @dev This function checks if all operations in the rebalance data are consistent
     *      (either all moving to buffer or all moving from buffer) and ensures that
     *      the buffer balance remains above the minimum required balance
     * @param rebalanceData An array of RebalanceData structs containing the rebalance operations
     * @custom:error FleetCommanderInvalidBufferAdjustment Thrown when operations are inconsistent (all operations need to move funds in one direction)
     * @custom:error FleetCommanderNoExcessFunds Thrown when trying to move funds out of an already minimum buffer
     * @custom:error FleetCommanderInsufficientBuffer Thrown when trying to move more funds than available excess
     */
    function _validateAdjustBufferData(
        RebalanceData[] calldata rebalanceData
    ) internal view {
        bool isMovingToBuffer = rebalanceData[0].toArk == address(bufferArk);
        uint256 initialBufferBalance = bufferArk.totalAssets();
        uint256 totalToMove;
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            totalToMove += rebalanceData[i].amount;
            if (isMovingToBuffer) {
                if (rebalanceData[i].toArk != address(bufferArk)) {
                    revert FleetCommanderInvalidBufferAdjustment();
                }
            } else {
                if (rebalanceData[i].fromArk != address(bufferArk)) {
                    revert FleetCommanderInvalidBufferAdjustment();
                }
            }
        }

        if (!isMovingToBuffer) {
            if (initialBufferBalance <= minFundsBufferBalance) {
                revert FleetCommanderNoExcessFunds();
            }
            uint256 excessFunds = initialBufferBalance - minFundsBufferBalance;
            if (totalToMove > excessFunds) {
                revert FleetCommanderInsufficientBuffer();
            }
        }
    }

    /**
     * @notice Validates the rebalance data for correctness and consistency
     * @dev This function checks various conditions of the rebalance operations:
     *      - Number of operations is within limits
     *      - Each operation has valid amounts and addresses
     *      - Arks involved in the operations are active and have proper allocations
     * @param rebalanceData An array of RebalanceData structs containing the rebalance operations
     * @custom:error FleetCommanderRebalanceTooManyOperations Thrown when the number of operations exceeds the maximum allowed
     * @custom:error FleetCommanderRebalanceNoOperations Thrown when the rebalance data array is empty
     * @custom:error FleetCommanderRebalanceAmountZero Thrown when one of the amounts to move is zero
     * @custom:error FleetCommanderArkNotFound Thrown when either the source or destination Ark address is zero
     * @custom:error FleetCommanderArkNotActive Thrown when either the source or destination Ark is not active
     * @custom:error FleetCommanderCantRebalanceToArk Thrown when trying to rebalance to an Ark with zero max allocation
     */
    function _validateRebalanceData(
        RebalanceData[] calldata rebalanceData
    ) internal view {
        if (rebalanceData.length > MAX_REBALANCE_OPERATIONS) {
            revert FleetCommanderRebalanceTooManyOperations(
                rebalanceData.length
            );
        }
        if (rebalanceData.length == 0) {
            revert FleetCommanderRebalanceNoOperations();
        }

        for (uint256 i = 0; i < rebalanceData.length; i++) {
            if (rebalanceData[i].amount == 0) {
                revert FleetCommanderRebalanceAmountZero(
                    rebalanceData[i].toArk
                );
            }
            if (address(rebalanceData[i].toArk) == address(0)) {
                revert FleetCommanderArkNotFound(rebalanceData[i].toArk);
            }
            if (address(rebalanceData[i].fromArk) == address(0)) {
                revert FleetCommanderArkNotFound(rebalanceData[i].fromArk);
            }
            if (!_isArkActive[address(rebalanceData[i].toArk)]) {
                revert FleetCommanderArkNotActive(rebalanceData[i].toArk);
            }
            if (!_isArkActive[address(rebalanceData[i].fromArk)]) {
                revert FleetCommanderArkNotActive(rebalanceData[i].fromArk);
            }
            if (IArk(rebalanceData[i].toArk).maxAllocation() == 0) {
                revert FleetCommanderCantRebalanceToArk(
                    address(rebalanceData[i].toArk)
                );
            }
        }
    }
}
