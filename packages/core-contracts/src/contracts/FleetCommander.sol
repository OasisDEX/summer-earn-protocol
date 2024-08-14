// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, ERC20, SafeERC20, ERC4626, IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {FleetCommanderParams, FleetConfig, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IArk} from "../interfaces/IArk.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {CooldownEnforcer} from "../utils/CooldownEnforcer/CooldownEnforcer.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Tipper} from "./Tipper.sol";
import {ITipper} from "../interfaces/ITipper.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "../errors/FleetCommanderErrors.sol";

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

    FleetConfig public config;
    address[] public arks;
    mapping(address => bool) public isArkActive;

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
        config = FleetConfig({
            bufferArk: IArk(params.bufferArk),
            minimumFundsBufferBalance: params.initialMinimumFundsBufferBalance,
            depositCap: params.depositCap,
            minimumRateDifference: params.minimumRateDifference
        });
        isArkActive[address(config.bufferArk)] = true;

        _setupArks(params.initialArks);
    }

    /**
     * @dev Modifier to collect the tip before any other action is taken
     */
    modifier collectTip() {
        _accrueTip();
        _;
    }

    /* PUBLIC - USER */
    function withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    ) public returns (uint256 shares) {
        uint256 prevQueueBalance = config.bufferArk.totalAssets();
        shares = previewWithdraw(assets);

        _validateBufferWithdraw(assets, shares, owner);
        _disembark(address(config.bufferArk), assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            config.bufferArk.totalAssets()
        );
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override(ERC4626, IERC4626) collectTip returns (uint256 assets) {
        uint256 bufferBalance = config.bufferArk.totalAssets();
        uint256 bufferBalanceInShares = convertToShares(bufferBalance);

        if (shares == type(uint256).max) {
            uint256 totalUserShares = balanceOf(owner);
            shares = totalUserShares;
        }

        if (shares <= bufferBalanceInShares) {
            assets = redeemFromBuffer(shares, receiver, owner);
        } else {
            assets = redeemFromArks(shares, receiver, owner);
        }
    }

    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    ) public collectTip returns (uint256 assets) {
        _validateRedeem(shares, owner);

        uint256 prevQueueBalance = config.bufferArk.totalAssets();

        assets = previewRedeem(shares);
        _disembark(address(config.bufferArk), assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            config.bufferArk.totalAssets()
        );
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(ERC4626, IERC4626) collectTip returns (uint256 shares) {
        uint256 bufferBalance = config.bufferArk.totalAssets();

        if (assets == type(uint256).max) {
            uint256 totalUserShares = balanceOf(owner);
            assets = previewRedeem(totalUserShares);
        }

        if (assets <= bufferBalance) {
            shares = withdrawFromBuffer(assets, receiver, owner);
        } else {
            shares = withdrawFromArks(assets, receiver, owner);
        }
    }

    function withdrawFromArks(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(IFleetCommander)
        collectTip
        returns (uint256 totalSharesToRedeem)
    {
        totalSharesToRedeem = previewWithdraw(assets);
        _validateForceWithdraw(assets, totalSharesToRedeem, owner);
        address[] memory sortedArks = _getSortedArks();
        _forceDisembarkFromSortedArks(sortedArks, assets);
        _withdraw(_msgSender(), receiver, owner, assets, totalSharesToRedeem);
        _setLastActionTimestamp(0);
        emit FleetCommanderWithdrawnFromArks(owner, receiver, assets);
    }

    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(IFleetCommander)
        collectTip
        returns (uint256 totalAssetsToWithdraw)
    {
        _validateForceRedeem(shares, owner);
        totalAssetsToWithdraw = previewRedeem(shares);
        address[] memory sortedArks = _getSortedArks();
        _forceDisembarkFromSortedArks(sortedArks, totalAssetsToWithdraw);
        _withdraw(_msgSender(), receiver, owner, totalAssetsToWithdraw, shares);
        _setLastActionTimestamp(0);
        emit FleetCommanderRedeemedFromArks(owner, receiver, shares);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override(ERC4626, IERC4626) collectTip returns (uint256 shares) {
        _validateDeposit(assets, _msgSender());

        uint256 prevQueueBalance = config.bufferArk.totalAssets();

        shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        _board(address(config.bufferArk), assets);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            config.bufferArk.totalAssets()
        );
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override(ERC4626, IERC4626) collectTip returns (uint256 assets) {
        _validateMint(shares, _msgSender());

        uint256 prevQueueBalance = config.bufferArk.totalAssets();

        assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);
        _board(address(config.bufferArk), assets);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            config.bufferArk.totalAssets()
        );
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
        IArk[] memory allArks = new IArk[](arks.length + 1);
        for (uint256 i = 0; i < arks.length; i++) {
            allArks[i] = IArk(arks[i]);
        }
        allArks[arks.length] = config.bufferArk;
        for (uint256 i = 0; i < allArks.length; i++) {
            // TODO: are we sure we can make all `totalAssets` calls that will not revert (as per IERC4626)
            total += IArk(allArks[i]).totalAssets();
        }
    }

    function getArks() public view returns (address[] memory) {
        return arks;
    }

    function maxDeposit(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 _totalAssets = totalAssets();
        uint256 maxAssets = _totalAssets > config.depositCap
            ? 0
            : config.depositCap - _totalAssets;

        return Math.min(maxAssets, IERC20(asset()).balanceOf(owner));
    }

    function maxMint(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 _totalAssets = totalAssets();
        uint256 maxAssets = _totalAssets > config.depositCap
            ? 0
            : config.depositCap - _totalAssets;
        return
            previewDeposit(
                Math.min(maxAssets, IERC20(asset()).balanceOf(owner))
            );
    }

    function maxBufferWithdraw(address owner) public view returns (uint256) {
        return
            Math.min(
                config.bufferArk.totalAssets(),
                previewRedeem(balanceOf(owner))
            );
    }

    function maxWithdraw(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        return previewRedeem(balanceOf(owner));
    }

    function maxRedeem(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        return balanceOf(owner);
    }

    function maxBufferRedeem(address owner) public view returns (uint256) {
        return
            Math.min(
                previewWithdraw(config.bufferArk.totalAssets()),
                balanceOf(owner)
            );
    }

    /* EXTERNAL - KEEPER */
    function rebalance(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown collectTip {
        // Validate that no operations are moving to or from the bufferArk
        _validateReallocateAllAssets(rebalanceData);
        _validateRebalance(rebalanceData);
        _reallocateAllAssets(rebalanceData);
    }

    function adjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown collectTip {
        _validateReallocateAllAssets(rebalanceData);
        _validateAdjustBuffer(rebalanceData);

        uint256 totalMoved = _reallocateAllAssets(rebalanceData);

        emit FleetCommanderBufferAdjusted(_msgSender(), totalMoved);
    }

    /* EXTERNAL - GOVERNANCE */
    function setFleetDepositCap(uint256 newCap) external onlyGovernor {
        config.depositCap = newCap;
        emit DepositCapUpdated(newCap);
    }

    function setTipJar() external onlyGovernor {
        _setTipJar();
    }

    /**
     * @notice Sets a new tip rate for the protocol
     * @dev Only callable by the governor
     * @dev The tip rate is set as a Percentage. Percentages use 18 decimals of precision
     *      For example, for a 5% rate, you'd pass 5 * 1e18 (5 000 000 000 000 000 000)
     * @param newTipRate The new tip rate as a Percentage
     */
    function setTipRate(Percentage newTipRate) external onlyGovernor {
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

    function setArkDepositCap(
        address ark,
        uint256 newDepositCap
    ) external onlyGovernor {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }

        IArk(ark).setDepositCap(newDepositCap);
    }

    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external onlyGovernor {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }

        IArk(ark).setMaxRebalanceOutflow(newMaxRebalanceOutflow);
    }

    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external onlyGovernor {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }

        IArk(ark).setMaxRebalanceInflow(newMaxRebalanceInflow);
    }

    function setMinimumBufferBalance(
        uint256 newMinimumBalance
    ) external onlyGovernor {
        config.minimumFundsBufferBalance = newMinimumBalance;
        emit FleetCommanderMinimumFundsBufferBalanceUpdated(newMinimumBalance);
    }

    function setMinimumRateDifference(
        Percentage newRateDifference
    ) external onlyGovernor {
        config.minimumRateDifference = newRateDifference;
        emit FleetCommanderMinimumRateDifferenceUpdated(newRateDifference);
    }

    function updateRebalanceCooldown(
        uint256 newCooldown
    ) external onlyGovernor {
        _updateCooldown(newCooldown);
    }

    function forceRebalance(
        RebalanceData[] calldata rebalanceData
    ) external onlyGovernor collectTip {
        // Validate that no operations are moving to or from the bufferArk
        _validateReallocateAllAssets(rebalanceData);
        _validateRebalance(rebalanceData);
        _reallocateAllAssets(rebalanceData);
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
    function _reallocateAllAssets(
        RebalanceData[] calldata rebalanceData
    ) internal returns (uint256 totalMoved) {
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
        IArk(ark).disembark(amount);
    }

    function _move(address fromArk, address toArk, uint256 amount) internal {
        IArk(fromArk).move(amount, toArk);
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
        if (isArkActive[ark]) {
            revert FleetCommanderArkAlreadyExists(ark);
        }

        isArkActive[ark] = true;
        arks.push(ark);
        emit ArkAdded(ark);
    }

    function _removeArk(address ark) internal {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }

        // Remove from arks if present
        for (uint256 i = 0; i < arks.length; i++) {
            if (arks[i] == ark) {
                _validateArkRemoval(ark);
                arks[i] = arks[arks.length - 1];
                arks.pop();
                break;
            }
        }

        isArkActive[ark] = false;
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
     * @return amount uint256 The actual amount of assets reallocated
     * @custom:error FleetCommanderTargetArkRateTooLow Thrown when the destination Ark's rate is lower than the source Ark's rate
     * @custom:error FleetCommanderCantRebalanceToArk Thrown when the destination Ark is already at or above its maximum allocation
     */
    function _reallocateAssets(
        RebalanceData memory data
    ) internal returns (uint256 amount) {
        IArk toArk = IArk(data.toArk);
        IArk fromArk = IArk(data.fromArk);

        if (data.amount == type(uint256).max) {
            amount = fromArk.totalAssets();
        } else {
            amount = data.amount;
        }

        uint256 toArkDepositCap = toArk.depositCap();
        uint256 toArkAllocation = toArk.totalAssets();

        if (toArkAllocation + amount > toArkDepositCap) {
            revert FleetCommanderCantRebalanceToArk(address(toArk));
        }

        _move(address(fromArk), address(toArk), amount);
    }

    /**
     * @notice Retrieves and sorts the arks based on their rates
     * @dev This function creates a sorted list of all active arks plus the buffer ark
     *      arks are sorted by their rates in ascending order. Buffer ark is always the last one
     * @return A sorted array of ark addresses, with the buffer ark at the end
     */
    function _getSortedArks() internal view returns (address[] memory) {
        address[] memory sortedArks = new address[](arks.length + 1);
        uint256[] memory rates = new uint256[](arks.length);

        for (uint256 i = 0; i < arks.length; i++) {
            rates[i] = IArk(arks[i]).rate();
            sortedArks[i] = arks[i];
        }

        _sortArksByRate(sortedArks, rates);
        sortedArks[arks.length] = address(config.bufferArk);

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
    function _forceDisembarkFromSortedArks(
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
     * @custom:error FleetCommanderArkDepositCapGreaterThanZero Thrown when the Ark's max allocation is not zero
     * @custom:error FleetCommanderArkAssetsNotZero Thrown when the Ark still holds assets
     */
    function _validateArkRemoval(address ark) internal view {
        IArk _ark = IArk(ark);
        if (_ark.depositCap() > 0) {
            revert FleetCommanderArkDepositCapGreaterThanZero(ark);
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
    function _validateAdjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) internal view {
        bool isMovingToBuffer = rebalanceData[0].toArk ==
            address(config.bufferArk);
        uint256 initialBufferBalance = config.bufferArk.totalAssets();
        uint256 totalToMove;
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            if (rebalanceData[i].amount == type(uint256).max) {
                revert FleetCommanderCantUseMaxUintForBufferAdjustement();
            }
            totalToMove += rebalanceData[i].amount;
            if (isMovingToBuffer) {
                if (rebalanceData[i].toArk != address(config.bufferArk)) {
                    revert FleetCommanderInvalidBufferAdjustment();
                }
            } else {
                if (rebalanceData[i].fromArk != address(config.bufferArk)) {
                    revert FleetCommanderInvalidBufferAdjustment();
                }
            }
        }

        if (!isMovingToBuffer) {
            if (initialBufferBalance <= config.minimumFundsBufferBalance) {
                revert FleetCommanderNoExcessFunds();
            }
            uint256 excessFunds = initialBufferBalance -
                config.minimumFundsBufferBalance;
            if (totalToMove > excessFunds) {
                revert FleetCommanderInsufficientBuffer();
            }
        }
    }

    /**
     * @notice Validates the rebalance operations to ensure they meet all required constraints
     * @dev This function performs a series of checks on each rebalance operation:
     *      1. Ensures general reallocation constraints are met
     *      2. Verifies the buffer ark is not directly involved in rebalancing
     *      3. Checks that funds are only moved to higher rate arks, with an exception for over-allocated arks
     * @param rebalanceData An array of RebalanceData structs, each representing a rebalance operation
     */
    function _validateRebalance(
        RebalanceData[] calldata rebalanceData
    ) internal view {
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            _validateBufferArkNotInvolved(rebalanceData[i]);

            uint256 toArkRate = IArk(rebalanceData[i].toArk).rate();
            uint256 fromArkRate = IArk(rebalanceData[i].fromArk).rate();

            if (toArkRate < fromArkRate) {
                _validateRebalanceToLowerRate(
                    IArk(rebalanceData[i].fromArk),
                    rebalanceData[i].amount,
                    fromArkRate,
                    toArkRate,
                    rebalanceData[i].toArk
                );
            } else {
                Percentage rateDifference = PercentageUtils.fromFraction(
                    (toArkRate - fromArkRate),
                    fromArkRate
                );
                if (rateDifference < config.minimumRateDifference) {
                    revert FleetCommanderTargetArkRateTooLow(
                        address(rebalanceData[i].toArk),
                        toArkRate,
                        fromArkRate
                    );
                }
            }
        }
    }

    /**
     * @notice Validates that the buffer ark is not directly involved in a rebalance operation
     * @dev This function checks if either the source or destination ark in a rebalance operation is the buffer ark
     * @param data The RebalanceData struct containing the source and destination ark addresses
     * @custom:error FleetCommanderCantUseRebalanceOnBufferArk Thrown if the buffer ark is involved in the rebalance
     */
    function _validateBufferArkNotInvolved(
        RebalanceData memory data
    ) internal view {
        if (
            data.toArk == address(config.bufferArk) ||
            data.fromArk == address(config.bufferArk)
        ) {
            revert FleetCommanderCantUseRebalanceOnBufferArk();
        }
    }

    /**
     * @notice Validates a rebalance operation that moves funds to a lower rate ark
     * @dev This function checks if the rebalance to a lower rate ark is allowed due to over-allocation
     *      It's only permissible to move funds to a lower rate ark if:
     *      1. The source ark is over-allocated (total assets > max allocation)
     *      2. The amount being moved is less than or equal to the excess allocation
     * @param fromArk The source ark contract
     * @param amount The amount of assets being moved in the rebalance operation
     * @param fromArkRate The rate of the source ark
     * @param toArkRate The rate of the destination ark
     * @param toArkAddress The address of the destination ark
     */
    function _validateRebalanceToLowerRate(
        IArk fromArk,
        uint256 amount,
        uint256 fromArkRate,
        uint256 toArkRate,
        address toArkAddress
    ) internal view {
        uint256 fromArkDepositCap = fromArk.depositCap();
        uint256 fromArkTotalAssets = fromArk.totalAssets();
        if (
            fromArkTotalAssets <= fromArkDepositCap ||
            fromArkTotalAssets - fromArkDepositCap < amount
        ) {
            revert FleetCommanderTargetArkRateTooLow(
                toArkAddress,
                toArkRate,
                fromArkRate
            );
        }
    }

    /**
     * @notice Validates the asset reallocation data for correctness and consistency
     * @dev This function checks various conditions of the rebalance operations:
     *      - Number of operations is within limits
     *      - Each operation has valid amounts and addresses
     *      - Arks involved in the operations are active and have proper allocations
     * @param rebalanceData An array of RebalanceData structs containing the rebalance operations
     */
    function _validateReallocateAllAssets(
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
            address fromArk = rebalanceData[i].fromArk;
            address toArk = rebalanceData[i].toArk;
            uint256 amount = rebalanceData[i].amount;
            _validateReallocateAssets(fromArk, toArk, amount);
        }
    }

    /**
     * @notice Validates the reallocation of assets between two ARKs.
     * @param fromArk The address of the source ARK.
     * @param toArk The address of the destination ARK.
     * @param amount The amount of assets to be reallocated.
     * @custom:error FleetCommanderRebalanceAmountZero if the amount is zero.
     * @custom:error FleetCommanderArkNotFound if the source or destination ARK is not found.
     * @custom:error FleetCommanderArkNotActive if the source or destination ARK is not active.
     * @custom:error FleetCommanderExceedsMaxOutflow if the amount exceeds the maximum move from limit of the source ARK.
     * @custom:error FleetCommanderExceedsMaxInflow if the amount exceeds the maximum move to limit of the destination ARK.
     * @custom:error FleetCommanderArkDepositCapZero if the deposit cap of the destination ARK is zero.
     */
    function _validateReallocateAssets(
        address fromArk,
        address toArk,
        uint256 amount
    ) internal view {
        if (amount == 0) {
            revert FleetCommanderRebalanceAmountZero(toArk);
        }
        if (toArk == address(0)) {
            revert FleetCommanderArkNotFound(toArk);
        }
        if (address(fromArk) == address(0)) {
            revert FleetCommanderArkNotFound(fromArk);
        }
        if (!isArkActive[address(toArk)]) {
            revert FleetCommanderArkNotActive(toArk);
        }
        if (!isArkActive[address(fromArk)]) {
            revert FleetCommanderArkNotActive(fromArk);
        }
        uint256 maxRebalanceOutflow = IArk(fromArk).maxRebalanceOutflow();
        if (amount > maxRebalanceOutflow) {
            revert FleetCommanderExceedsMaxOutflow(
                fromArk,
                amount,
                maxRebalanceOutflow
            );
        }
        uint256 maxRebalanceInflow = IArk(toArk).maxRebalanceInflow();
        if (amount > maxRebalanceInflow) {
            revert FleetCommanderExceedsMaxInflow(
                toArk,
                amount,
                maxRebalanceInflow
            );
        }
        if (IArk(toArk).depositCap() == 0) {
            revert FleetCommanderArkDepositCapZero(toArk);
        }
    }

    /**
     * @notice Validates the withdraw request
     * @dev This function checks two conditions:
     *      1. The caller is authorized to withdraw on behalf of the owner
     *      2. The withdrawal amount does not exceed the maximum allowed
     * @param assets The amount of assets to withdraw
     * @param shares The number of shares to redeem
     * @param owner The address of the owner of the assets
     * @custom:error FleetCommanderUnauthorizedWithdrawal Thrown when the caller is not authorized to withdraw
     * @custom:error IERC4626ExceededMaxWithdraw Thrown when the withdrawal amount exceeds the maximum allowed
     */
    function _validateBufferWithdraw(
        uint256 assets,
        uint256 shares,
        address owner
    ) internal view {
        if (
            _msgSender() != owner &&
            IERC20(address(this)).allowance(owner, _msgSender()) < shares
        ) {
            revert FleetCommanderUnauthorizedWithdrawal(_msgSender(), owner);
        }
        uint256 maxAssets = maxBufferWithdraw(owner);
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
     * @custom:error IERC4626ExceededMaxRedeem Thrown when the redemption amount exceeds the maximum allowed
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
     * @custom:error IERC4626ExceededMaxDeposit Thrown when the deposit amount exceeds the maximum allowed
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
     * @custom:error IERC4626ExceededMaxMint Thrown when the mint amount exceeds the maximum allowed
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
     * @param shares The amount of shares to redeem
     * @param owner The address of the owner of the assets
     * @custom:error FleetCommanderUnauthorizedWithdrawal Thrown when the caller is not authorized to withdraw
     * @custom:error IERC4626ExceededMaxWithdraw Thrown when the withdrawal amount exceeds the maximum allowed
     */
    function _validateForceWithdraw(
        uint256 assets,
        uint256 shares,
        address owner
    ) internal view {
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
    }

    /**
     * @notice Validates the force redeem request
     * @dev This function checks two conditions:
     *      1. The caller is authorized to redeem on behalf of the owner
     *      2. The redemption amount does not exceed the maximum allowed
     * @param shares The amount of shares to redeem
     * @param owner The address of the owner of the assets
     * @custom:error FleetCommanderUnauthorizedRedemption Thrown when the caller is not authorized to redeem
     * @custom:error IERC4626ExceededMaxRedeem Thrown when the redemption amount exceeds the maximum allowed
     */
    function _validateForceRedeem(uint256 shares, address owner) internal view {
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
}
