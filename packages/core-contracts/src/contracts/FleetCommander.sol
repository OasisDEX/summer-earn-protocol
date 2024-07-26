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
import {Tipper} from "./Tipper.sol";
import {ITipper} from "../interfaces/ITipper.sol";

/**
 * @custom:see IFleetCommander
 */
contract FleetCommander is
    IFleetCommander,
    ERC4626,
    ProtocolAccessManaged,
    Tipper,
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
        Tipper(params.configurationManager, params.initialTipRate)
        CooldownEnforcer(params.initialRebalanceCooldown, false)
    {
        _setupArks(params.initialArks);

        minFundsBufferBalance = params.initialMinimumFundsBufferBalance;
        depositCap = params.depositCap;
        bufferArk = IArk(params.bufferArk);
        _isArkActive[address(bufferArk)] = true;
    }

    /**
     * @dev Modifier to collect the tip before any other action is taken
     */
    modifier collectTip() {
        _accrueTip();
        _;
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
    ) public override(ERC4626, IFleetCommander) collectTip returns (uint256) {
        _validateWithdraw(assets, owner);

        uint256 prevQueueBalance = bufferArk.totalAssets();

        uint256 shares = previewWithdraw(assets);
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
    ) public override(ERC4626, IERC4626) collectTip returns (uint256) {
        _validateRedeem(shares, owner);

        uint256 prevQueueBalance = bufferArk.totalAssets();

        uint256 assets = previewRedeem(shares);
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
    ) public override(IFleetCommander) collectTip returns (uint256) {
        _validateForceWithdraw(assets, owner);
        uint256 totalSharesToWithdraw = previewWithdraw(assets);
        address[] memory sortedArks = _getSortedArks();
        _forceWithdrawFromSortedArks(sortedArks, assets);
        _withdraw(_msgSender(), receiver, owner, assets, totalSharesToWithdraw);
        _setLastActionTimestamp(0);

        // Accrue tip after withdrawal to maintain accuracy of prior convertToShares calculation
        _accrueTip();
        return assets;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override(ERC4626, IFleetCommander) collectTip returns (uint256) {
        _validateDeposit(assets, _msgSender());

        uint256 prevQueueBalance = bufferArk.totalAssets();

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
    ) public override(ERC4626, IERC4626) collectTip returns (uint256) {
        _validateMint(shares, _msgSender());

        uint256 prevQueueBalance = bufferArk.totalAssets();

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);
        _board(address(bufferArk), assets);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            bufferArk.totalAssets()
        );

        return assets;
    }

    function tip() public returns (uint256) {
        return _accrueTip();
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
        uint256 _totalAssets = totalAssets();
        uint256 maxAssets = _totalAssets > depositCap
            ? 0
            : depositCap - _totalAssets;

        return Math.min(maxAssets, IERC20(asset()).balanceOf(owner));
    }

    function maxMint(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 _totalAssets = totalAssets();
        uint256 maxAssets = _totalAssets > depositCap
            ? 0
            : depositCap - _totalAssets;
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
    ) external onlyKeeper enforceCooldown collectTip {
        _rebalance(rebalanceData);
    }

    function adjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown collectTip {
        _validateAdjustBufferData(rebalanceData);

        uint256 totalMoved = _rebalance(rebalanceData);

        uint256 finalBufferBalance = bufferArk.totalAssets();
        if (finalBufferBalance < minFundsBufferBalance) {
            revert FleetCommanderInsufficientBuffer();
        }

        emit Rebalanced(_msgSender(), rebalanceData);
        emit FleetCommanderBufferAdjusted(_msgSender(), totalMoved);
    }

    /* EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external onlyGovernor {
        depositCap = newCap;
        emit DepositCapUpdated(newCap);
    }

    function setTipJar() external onlyGovernor {
        _setTipJar();
    }

    function setTipRate(uint256 newTipRate) external onlyGovernor {
        _setTipRate(newTipRate);
    }

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
    ) external onlyGovernor collectTip {
        _rebalance(rebalanceData);
    }

    function emergencyShutdown() external onlyGovernor {}

    /* PUBLIC - ERC20 */
    function transfer(
        address,
        uint256
    ) public pure override(IERC20, ERC20) returns (bool) {
        revert FleetCommanderTransfersDisabled();
    }

    /* INTERNAL - TIPS */
    function _mintTip(
        address account,
        uint256 amount
    ) internal virtual override {
        _mint(account, amount);
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
        _disembark(fromArk, amount);
        _board(toArk, amount);
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

    /* INTERNAL */

    /**
     * @notice Reallocates assets from one Ark to another
     * @dev This function handles the reallocation of assets between Arks, considering:
     *      1. The rates of the source and destination Arks
     *      2. The maximum allocation of the destination Ark
     *      3. The current allocation of the destination Ark
     * @param data The RebalanceData struct containing information about the reallocation
     * @return uint256 The actual amount of assets reallocated
     * @custom:error FleetCommanderTargetArkRateTooLow Thrown when the destination Ark's rate is lower than the source Ark's rate
     * @custom:error FleetCommanderCantRebalanceToArk Thrown when the destination Ark is already at or above its maximum allocation
     */
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

    /**
     * @notice Retrieves and sorts the arks based on their rates
     * @dev This function creates a sorted list of all active arks plus the buffer ark
     *      arks are sorted by their rates in ascending order. Buffer ark is always the last one
     * @return A sorted array of ark addresses, with the buffer ark at the end
     */
    function _getSortedArks() internal view returns (address[] memory) {
        address[] memory sortedArks = new address[](_activeArks.length + 1);
        uint256[] memory rates = new uint256[](_activeArks.length);

        for (uint256 i = 0; i < _activeArks.length; i++) {
            rates[i] = IArk(_activeArks[i]).rate();
            sortedArks[i] = _activeArks[i];
        }

        _sortArksByRate(sortedArks, rates);
        sortedArks[_activeArks.length] = address(bufferArk);

        return sortedArks;
    }

    /**
     * @notice Sorts the arks based on their rates in ascending order
     * @dev This function implements a simple bubble sort algorithm
     * @param _arks An array of ark addresses to be sorted
     * @param rates An array of corresponding rates for each ark
     */
    function _sortArksByRate(
        address[] memory _arks,
        uint256[] memory rates
    ) internal pure {
        for (uint256 i = 0; i < rates.length; i++) {
            for (uint256 j = i + 1; j < rates.length; j++) {
                if (rates[i] > rates[j]) {
                    (rates[i], rates[j]) = (rates[j], rates[i]);
                    (_arks[i], _arks[j]) = (_arks[j], _arks[i]);
                }
            }
        }
    }

    /**
     * @notice Withdraws assets from multiple arks in a specific order
     * @dev This function attempts to withdraw the requested amount from arks,
     *      starting with the lowest rate ark and moving to higher rate arks,
     *      where buffer ark is the last one in arks array
     * @param sortedArks An array of ark addresses sorted by their rates
     * @param assets The total amount of assets to withdraw
     */
    function _forceWithdrawFromSortedArks(
        address[] memory sortedArks,
        uint256 assets
    ) internal {
        for (uint256 i = 0; i < sortedArks.length; i++) {
            uint256 assetsInArk = IArk(sortedArks[i]).totalAssets();
            if (assetsInArk >= assets) {
                _disembark(sortedArks[i], assets);
                break;
            } else if (assetsInArk > 0) {
                _disembark(sortedArks[i], assetsInArk);
                assets -= assetsInArk;
            }
        }
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

    /**
     * @notice Validates the withdraw request
     * @dev This function checks two conditions:
     *      1. The caller is authorized to withdraw on behalf of the owner
     *      2. The withdrawal amount does not exceed the maximum allowed
     * @param assets The amount of assets to withdraw
     * @param owner The address of the owner of the assets
     * @custom:error FleetCommanderUnauthorizedWithdrawal Thrown when the caller is not authorized to withdraw
     * @custom:error ERC4626ExceededMaxWithdraw Thrown when the withdrawal amount exceeds the maximum allowed
     */
    function _validateWithdraw(uint256 assets, address owner) internal view {
        if (
            _msgSender() != owner &&
            IERC20(address(this)).allowance(owner, _msgSender()) < assets
        ) {
            revert FleetCommanderUnauthorizedWithdrawal(_msgSender(), owner);
        }
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
    }

    /**
     * @notice Validates the redemption request
     * @dev This function checks two conditions:
     *      1. The caller is authorized to redeem on behalf of the owner
     *      2. The redemption amount does not exceed the maximum allowed
     * @param shares The number of shares to redeem
     * @param owner The address of the owner of the shares
     * @custom:error FleetCommanderUnauthorizedRedemption Thrown when the caller is not authorized to redeem
     * @custom:error ERC4626ExceededMaxRedeem Thrown when the redemption amount exceeds the maximum allowed
     */
    function _validateRedeem(uint256 shares, address owner) internal view {
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
    }

    /**
     * @notice Validates the deposit request
     * @dev This function checks if the requested deposit amount exceeds the maximum allowed
     * @param assets The amount of assets to deposit
     * @param owner The address of the account making the deposit
     * @custom:error ERC4626ExceededMaxDeposit Thrown when the deposit amount exceeds the maximum allowed
     */
    function _validateDeposit(uint256 assets, address owner) internal view {
        uint256 maxAssets = maxDeposit(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(owner, assets, maxAssets);
        }
    }

    /**
     * @notice Validates the mint request
     * @dev This function checks if the requested mint amount exceeds the maximum allowed
     * @param shares The number of shares to mint
     * @param owner The address of the account minting the shares
     * @custom:error ERC4626ExceededMaxMint Thrown when the mint amount exceeds the maximum allowed
     */
    function _validateMint(uint256 shares, address owner) internal view {
        uint256 maxShares = maxMint(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(owner, shares, maxShares);
        }
    }

    /**
     * @notice Validates the force withdraw request
     * @dev This function checks two conditions:
     *      1. The caller is authorized to withdraw on behalf of the owner
     *      2. The withdrawal amount does not exceed the maximum allowed
     * @param assets The amount of assets to withdraw
     * @param owner The address of the owner of the assets
     * @custom:error FleetCommanderUnauthorizedWithdrawal Thrown when the caller is not authorized to withdraw
     * @custom:error ERC4626ExceededMaxWithdraw Thrown when the withdrawal amount exceeds the maximum allowed
     */
    function _validateForceWithdraw(
        uint256 assets,
        address owner
    ) internal view {
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
    }
}
