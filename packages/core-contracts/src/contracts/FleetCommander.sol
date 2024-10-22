// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ArkData, FleetCommanderParams, FleetConfig, RebalanceData} from "../types/FleetCommanderTypes.sol";

import {CooldownEnforcer} from "../utils/CooldownEnforcer/CooldownEnforcer.sol";

import {FleetCommanderCache} from "./FleetCommanderCache.sol";
import {FleetCommanderConfigProvider} from "./FleetCommanderConfigProvider.sol";

import {Tipper} from "./Tipper.sol";
import {ERC20, ERC4626, IERC20, IERC4626, SafeERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Constants} from "./libraries/Constants.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {IFleetRewardsManager} from "../interfaces/IFleetRewardsManager.sol";

/**
 * @title FleetCommander
 * @notice Manages a fleet of Arks, coordinating deposits, withdrawals, and rebalancing operations
 * @dev Implements IFleetCommander interface and inherits from various utility contracts
 */
contract FleetCommander is
    IFleetCommander,
    FleetCommanderConfigProvider,
    ERC4626,
    Tipper,
    FleetCommanderCache,
    CooldownEnforcer
{
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default maximum number of rebalance operations allowed in a single transaction
    uint256 public constant DEFAULT_MAX_REBALANCE_OPERATIONS = 10;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the FleetCommander contract
     * @param params FleetCommanderParams struct containing initialization parameters
     */
    constructor(
        FleetCommanderParams memory params
    )
        ERC4626(IERC20(params.asset))
        ERC20(params.name, params.symbol)
        FleetCommanderConfigProvider(params)
        Tipper(params.configurationManager, params.initialTipRate)
        CooldownEnforcer(params.initialRebalanceCooldown, false)
    {}

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to collect the tip before any other action is taken
     */
    modifier collectTip() {
        _accrueTip();
        _;
    }

    /**
     * @dev Modifier to cache ark data for deposit operations.
     * @notice This modifier retrieves ark data before the function execution,
     *         allows the modified function to run, and then flushes the cache.
     * @dev The cache is required due to multiple calls to `totalAssets` in the same transaction.
     *         those calls migh be gas expensive for some arks.
     */
    modifier useDepositCache() {
        _getArksData(getArks(), config.bufferArk);
        _;
        _flushCache();
    }

    /**
     * @dev Modifier to cache withdrawable ark data for withdraw operations.
     * @notice This modifier retrieves withdrawable ark data before the function execution,
     *         allows the modified function to run, and then flushes the cache.
     * @dev The cache is required due to multiple calls to `totalAssets` in the same transaction.
     *         those calls migh be gas expensive for some arks.
     */
    modifier useWithdrawCache() {
        _getWithdrawableArksData(
            getArks(),
            config.bufferArk,
            isArkWithdrawable
        );
        _;
        _flushCache();
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommander
    function withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    ) public whenNotPaused returns (uint256 shares) {
        shares = previewWithdraw(assets);
        _validateBufferWithdraw(assets, shares, owner);

        uint256 prevQueueBalance = config.bufferArk.totalAssets();

        _disembark(address(config.bufferArk), assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            prevQueueBalance,
            config.bufferArk.totalAssets()
        );
    }

    /// @inheritdoc IFleetCommander
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(ERC4626, IFleetCommander)
        collectTip
        useWithdrawCache
        whenNotPaused
        returns (uint256 assets)
    {
        uint256 bufferBalance = config.bufferArk.totalAssets();
        uint256 bufferBalanceInShares = convertToShares(bufferBalance);

        if (shares == Constants.MAX_UINT256) {
            shares = balanceOf(owner);
        }

        if (shares <= bufferBalanceInShares) {
            assets = redeemFromBuffer(shares, receiver, owner);
        } else {
            assets = redeemFromArks(shares, receiver, owner);
        }
    }

    /// @inheritdoc IFleetCommander
    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        collectTip
        useWithdrawCache
        whenNotPaused
        returns (uint256 assets)
    {
        _validateBufferRedeem(shares, owner);

        uint256 previousFundsBufferBalance = config.bufferArk.totalAssets();

        assets = previewRedeem(shares);
        _disembark(address(config.bufferArk), assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            previousFundsBufferBalance,
            config.bufferArk.totalAssets()
        );
    }

    /// @inheritdoc IFleetCommander
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(ERC4626, IFleetCommander)
        collectTip
        useWithdrawCache
        whenNotPaused
        returns (uint256 shares)
    {
        uint256 bufferBalance = config.bufferArk.totalAssets();

        if (assets == Constants.MAX_UINT256) {
            uint256 totalUserShares = balanceOf(owner);
            assets = previewRedeem(totalUserShares);
        }

        if (assets <= bufferBalance) {
            shares = withdrawFromBuffer(assets, receiver, owner);
        } else {
            shares = withdrawFromArks(assets, receiver, owner);
        }
    }

    /// @inheritdoc IFleetCommander
    function withdrawFromArks(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(IFleetCommander)
        collectTip
        useWithdrawCache
        whenNotPaused
        returns (uint256 totalSharesToRedeem)
    {
        totalSharesToRedeem = previewWithdraw(assets);

        _validateWithdrawFromArks(assets, totalSharesToRedeem, owner);

        _forceDisembarkFromSortedArks(assets);
        _withdraw(_msgSender(), receiver, owner, assets, totalSharesToRedeem);
        _setLastActionTimestamp(0);

        emit FleetCommanderWithdrawnFromArks(owner, receiver, assets);
    }

    /// @inheritdoc IFleetCommander
    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(IFleetCommander)
        collectTip
        useWithdrawCache
        whenNotPaused
        returns (uint256 totalAssetsToWithdraw)
    {
        _validateForceRedeem(shares, owner);

        totalAssetsToWithdraw = previewRedeem(shares);
        _forceDisembarkFromSortedArks(totalAssetsToWithdraw);
        _withdraw(_msgSender(), receiver, owner, totalAssetsToWithdraw, shares);
        _setLastActionTimestamp(0);
        emit FleetCommanderRedeemedFromArks(owner, receiver, shares);
    }

    /// @inheritdoc IERC4626
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override(ERC4626, IERC4626)
        collectTip
        useDepositCache
        whenNotPaused
        returns (uint256 shares)
    {
        _validateDeposit(assets, _msgSender());

        uint256 previousFundsBufferBalance = config.bufferArk.totalAssets();

        shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        _board(address(config.bufferArk), assets);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            previousFundsBufferBalance,
            config.bufferArk.totalAssets()
        );
    }

    /// @inheritdoc IFleetCommander
    function deposit(
        uint256 assets,
        address receiver,
        bytes memory referralCode
    ) external whenNotPaused returns (uint256) {
        emit FleetCommanderReferral(receiver, referralCode);
        return deposit(assets, receiver);
    }

    /// @inheritdoc IFleetCommander
    function depositAndStake(
        uint256 assets,
        address receiver
    ) public whenNotPaused returns (uint256 shares) {
        shares = deposit(assets, address(this));
        IERC20(address(this)).approve(
            address(config.stakingRewardsManager),
            shares
        );
        _stakeOnBehalf(receiver, shares);

        return shares;
    }

    /// @inheritdoc IFleetCommander
    function depositAndStake(
        uint256 assets,
        address receiver,
        bytes memory referralCode
    ) external whenNotPaused returns (uint256 shares) {
        emit FleetCommanderReferral(receiver, referralCode);
        return depositAndStake(assets, receiver);
    }

    /// @inheritdoc IFleetCommander
    function stake(uint256 shares) public {
        IERC20(address(this)).transferFrom(_msgSender(), address(this), shares);
        IERC20(address(this)).approve(
            address(config.stakingRewardsManager),
            shares
        );
        _stakeOnBehalf(_msgSender(), shares);
    }

    /// @inheritdoc IERC4626
    function mint(
        uint256 shares,
        address receiver
    )
        public
        override(ERC4626, IERC4626)
        collectTip
        useDepositCache
        whenNotPaused
        returns (uint256 assets)
    {
        _validateMint(shares, _msgSender());

        uint256 previousFundsBufferBalance = config.bufferArk.totalAssets();
        assets = previewMint(shares);

        _deposit(_msgSender(), receiver, assets, shares);
        _board(address(config.bufferArk), assets);

        emit FundsBufferBalanceUpdated(
            _msgSender(),
            previousFundsBufferBalance,
            config.bufferArk.totalAssets()
        );
    }

    /// @inheritdoc IFleetCommander
    function tip() public whenNotPaused returns (uint256) {
        return _accrueTip();
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommander
    function totalAssets()
        public
        view
        override(IFleetCommander, ERC4626)
        returns (uint256)
    {
        return _totalAssets(getArks(), config.bufferArk);
    }

    /// @inheritdoc IFleetCommander
    function withdrawableTotalAssets() public view returns (uint256) {
        return
            _withdrawableTotalAssets(
                getArks(),
                config.bufferArk,
                isArkWithdrawable
            );
    }

    /// @inheritdoc IERC4626
    function maxDeposit(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256 _maxDeposit) {
        uint256 _totalAssets = totalAssets();
        uint256 maxAssets = _totalAssets > config.depositCap
            ? 0
            : config.depositCap - _totalAssets;

        _maxDeposit = Math.min(maxAssets, IERC20(asset()).balanceOf(owner));
    }

    /// @inheritdoc IERC4626
    function maxMint(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256 _maxMint) {
        uint256 _totalAssets = totalAssets();
        uint256 maxAssets = _totalAssets > config.depositCap
            ? 0
            : config.depositCap - _totalAssets;
        _maxMint = previewDeposit(
            Math.min(maxAssets, IERC20(asset()).balanceOf(owner))
        );
    }

    /// @inheritdoc IFleetCommander
    function maxBufferWithdraw(
        address owner
    ) public view returns (uint256 _maxBufferWithdraw) {
        _maxBufferWithdraw = Math.min(
            config.bufferArk.totalAssets(),
            previewRedeem(balanceOf(owner))
        );
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256 _maxWithdraw) {
        _maxWithdraw = Math.min(
            withdrawableTotalAssets(),
            previewRedeem(balanceOf(owner))
        );
    }

    /// @inheritdoc IERC4626
    function maxRedeem(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256 _maxRedeem) {
        _maxRedeem = Math.min(
            convertToShares(withdrawableTotalAssets()),
            balanceOf(owner)
        );
    }

    /// @inheritdoc IFleetCommander
    function maxBufferRedeem(
        address owner
    ) public view returns (uint256 _maxBufferRedeem) {
        _maxBufferRedeem = Math.min(
            previewWithdraw(config.bufferArk.totalAssets()),
            balanceOf(owner)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommander
    function rebalance(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown collectTip whenNotPaused {
        // Validate that no operations are moving to or from the bufferArk
        _validateReallocateAllAssets(rebalanceData);
        _validateRebalance(rebalanceData);
        _reallocateAllAssets(rebalanceData);
    }

    /// @inheritdoc IFleetCommander
    function adjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper enforceCooldown collectTip whenNotPaused {
        _validateReallocateAllAssets(rebalanceData);
        _validateAdjustBuffer(rebalanceData);

        uint256 totalMoved = _reallocateAllAssets(rebalanceData);

        emit FleetCommanderBufferAdjusted(_msgSender(), totalMoved);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommander
    function setTipRate(
        Percentage newTipRate
    ) external onlyGovernor whenNotPaused {
        // The newTipRate uses the Percentage type from @summerfi/percentage-solidity
        // Percentages have 18 decimals of precision
        // For example, 1% would be represented as 1 * 10^18 (assuming PERCENTAGE_DECIMALS is 18)
        _setTipRate(newTipRate);
    }

    /// @inheritdoc IFleetCommander
    function setMinimumPauseTime(
        uint256 _newMinimumPauseTime
    ) public onlyGovernor whenNotPaused {
        _setMinimumPauseTime(_newMinimumPauseTime);
    }

    /// @inheritdoc IFleetCommander
    function updateRebalanceCooldown(
        uint256 newCooldown
    ) external onlyGovernor whenNotPaused {
        _updateCooldown(newCooldown);
    }

    /// @inheritdoc IFleetCommander
    function forceRebalance(
        RebalanceData[] calldata rebalanceData
    ) external onlyGovernor collectTip whenNotPaused {
        // Validate that no operations are moving to or from the bufferArk
        _validateReallocateAllAssets(rebalanceData);
        _validateRebalance(rebalanceData);
        _reallocateAllAssets(rebalanceData);
    }

    /// @inheritdoc IFleetCommander
    function pause() external onlyGuardianOrGovernor whenNotPaused {
        _pause();
    }

    /// @inheritdoc IFleetCommander
    function unpause() external onlyGuardianOrGovernor whenPaused {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20
    function transfer(
        address to,
        uint256 amount
    ) public override(IERC20, ERC20) returns (bool) {
        FleetConfig memory config = this.getConfig();
        if (_msgSender() == address(config.stakingRewardsManager)) {
            return super.transfer(to, amount);
        }

        revert FleetCommanderTransfersDisabled();
    }

    /// @inheritdoc IERC20
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(IERC20, ERC20) returns (bool) {
        FleetConfig memory config = this.getConfig();
        if (_msgSender() == address(config.stakingRewardsManager)) {
            return super.transferFrom(from, to, amount);
        }
        if (to == address(this)) {
            return super.transferFrom(from, to, amount);
        }
        revert FleetCommanderTransfersDisabled();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new shares as tips to the specified account
     * @dev This function overrides the abstract _mintTip function from the Tipper contract.
     *      It is called internally by the _accrueTip function to mint new shares as tips.
     *      In the context of FleetCommander, this creates new shares without requiring
     *      additional underlying assets, effectively diluting existing shareholders slightly
     *      to pay for the protocol's ongoing operations.
     * @param account The address to receive the minted tip shares
     * @param amount The amount of shares to mint as a tip
     */
    function _mintTip(
        address account,
        uint256 amount
    ) internal virtual override {
        _mint(account, amount);
    }

    /**
     * @notice Reallocates all assets based on the provided rebalance data
     * @param rebalanceData Array of RebalanceData structs containing information about the reallocation
     * @return totalMoved The total amount of assets moved during the reallocation
     */
    function _reallocateAllAssets(
        RebalanceData[] calldata rebalanceData
    ) internal returns (uint256 totalMoved) {
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            totalMoved += _reallocateAssets(rebalanceData[i]);
        }
        emit Rebalanced(_msgSender(), rebalanceData);
    }

    /* INTERNAL - ARK */

    /**
     * @notice Approves and boards a specified amount of assets to an Ark
     * @param ark The address of the Ark
     * @param amount The amount of assets to board
     */
    function _board(address ark, uint256 amount) internal {
        IERC20(asset()).approve(ark, amount);
        IArk(ark).board(amount, bytes(""));
    }

    /**
     * @notice Disembarks a specified amount of assets from an Ark
     * @param ark The address of the Ark
     * @param amount The amount of assets to disembark
     */
    function _disembark(address ark, uint256 amount) internal {
        IArk(ark).disembark(amount, bytes(""));
    }

    /**
     * @notice Moves a specified amount of assets from one Ark to another
     * @param fromArk The address of the Ark to move assets from
     * @param toArk The address of the Ark to move assets to
     * @param amount The amount of assets to move
     * @param boardData Additional data for the board operation
     * @param disembarkData Additional data for the disembark operation
     */
    function _move(
        address fromArk,
        address toArk,
        uint256 amount,
        bytes memory boardData,
        bytes memory disembarkData
    ) internal {
        IArk(fromArk).move(amount, toArk, boardData, disembarkData);
    }

    /* INTERNAL */

    /**
     * @notice Reallocates assets from one Ark to another
     * @dev This function handles the reallocation of assets between Arks, considering:
     *      1. The maximum allocation of the destination Ark
     *      2. The current allocation of the destination Ark
     * @param data The RebalanceData struct containing information about the reallocation
     * @return amount uint256 The actual amount of assets reallocated
     * @custom:error FleetCommanderCantRebalanceToArk Thrown when the destination Ark is already at or above its maximum
     * allocation
     */
    function _reallocateAssets(
        RebalanceData memory data
    ) internal returns (uint256 amount) {
        IArk toArk = IArk(data.toArk);
        IArk fromArk = IArk(data.fromArk);

        if (data.amount == Constants.MAX_UINT256) {
            amount = fromArk.totalAssets();
        } else {
            amount = data.amount;
        }

        uint256 toArkDepositCap = toArk.depositCap();
        uint256 toArkAllocation = toArk.totalAssets();

        if (toArkAllocation + amount > toArkDepositCap) {
            revert FleetCommanderCantRebalanceToArk(address(toArk));
        }

        _move(
            address(fromArk),
            address(toArk),
            amount,
            data.boardData,
            data.disembarkData
        );
    }

    /**
     * @notice Withdraws assets from multiple arks in a specific order
     * @dev This function attempts to withdraw the requested amount from arks,
     *      that allow such operations, in the order of total assets held
     * @param assets The total amount of assets to withdraw
     */
    function _forceDisembarkFromSortedArks(uint256 assets) internal {
        ArkData[] memory withdrawableArks = _getWithdrawableArksDataFromCache();
        for (uint256 i = 0; i < withdrawableArks.length; i++) {
            uint256 assetsInArk = withdrawableArks[i].totalAssets;
            if (assetsInArk >= assets) {
                _disembark(withdrawableArks[i].arkAddress, assets);
                break;
            } else if (assetsInArk > 0) {
                _disembark(withdrawableArks[i].arkAddress, assetsInArk);
                assets -= assetsInArk;
            }
        }
    }

    /* INTERNAL - VALIDATIONS */

    /**
     * @notice Validates the data for adjusting the buffer
     * @dev This function checks if all operations in the rebalance data are consistent
     *      (either all moving to buffer or all moving from buffer) and ensures that
     *      the buffer balance remains above the minimum required balance.
     *      When moving to the buffer, using MAX_UINT256 as the amount will move all funds from the source Ark.
     * @param rebalanceData An array of RebalanceData structs containing the rebalance operations
     * @custom:error FleetCommanderInvalidBufferAdjustment Thrown when operations are inconsistent (all operations need
     * to move funds in one direction)
     * @custom:error FleetCommanderNoExcessFunds Thrown when trying to move funds out of an already minimum buffer
     * @custom:error FleetCommanderInsufficientBuffer Thrown when trying to move more funds than available excess
     * @custom:error FleetCommanderCantUseMaxUintMovingFromBuffer Thrown when trying to use MAX_UINT256 amount when
     * moving from buffer
     */
    function _validateAdjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) internal view {
        bool isMovingToBuffer = rebalanceData[0].toArk ==
            address(config.bufferArk);
        uint256 initialBufferBalance = config.bufferArk.totalAssets();
        uint256 totalToMove;

        for (uint256 i = 0; i < rebalanceData.length; i++) {
            _validateBufferAdjustmentDirection(
                isMovingToBuffer,
                rebalanceData[i]
            );

            uint256 amount = rebalanceData[i].amount;
            if (amount == Constants.MAX_UINT256) {
                if (!isMovingToBuffer) {
                    revert FleetCommanderCantUseMaxUintMovingFromBuffer();
                }
                amount = IArk(rebalanceData[i].fromArk).totalAssets();
            }
            totalToMove += amount;
        }

        if (!isMovingToBuffer) {
            _validateBufferExcessFunds(initialBufferBalance, totalToMove);
        }
    }

    /**
     * @notice Validates the direction of buffer adjustment for a single rebalance operation
     * @dev This function ensures that the rebalance operation is consistent with the overall
     *      direction of the buffer adjustment (either moving funds to or from the buffer).
     * @param isMovingToBuffer A boolean indicating whether the overall operation is moving funds to the buffer
     * @param data The RebalanceData struct containing information about the specific rebalance operation
     * @custom:error FleetCommanderInvalidBufferAdjustment Thrown when the operation direction is inconsistent
     *               with the overall buffer adjustment direction
     */
    function _validateBufferAdjustmentDirection(
        bool isMovingToBuffer,
        RebalanceData memory data
    ) internal view {
        if (
            (isMovingToBuffer && data.toArk != address(config.bufferArk)) ||
            (!isMovingToBuffer && data.fromArk != address(config.bufferArk))
        ) {
            revert FleetCommanderInvalidBufferAdjustment();
        }
    }

    /**
     * @notice Validates that there are sufficient excess funds in the buffer for withdrawal
     * @dev This function checks two conditions:
     *      1. The initial buffer balance is greater than the minimum required balance
     *      2. The amount to move does not exceed the excess funds in the buffer
     * @param initialBufferBalance The current balance of the buffer before the adjustment
     * @param totalToMove The total amount of assets to be moved from the buffer
     * @custom:error FleetCommanderNoExcessFunds Thrown when the buffer balance is at or below the minimum required
     * balance
     * @custom:error FleetCommanderInsufficientBuffer Thrown when the amount to move exceeds the available excess funds
     * in the buffer
     */
    function _validateBufferExcessFunds(
        uint256 initialBufferBalance,
        uint256 totalToMove
    ) internal view {
        if (initialBufferBalance <= config.minimumBufferBalance) {
            revert FleetCommanderNoExcessFunds();
        }
        uint256 excessFunds = initialBufferBalance -
            config.minimumBufferBalance;
        if (totalToMove > excessFunds) {
            revert FleetCommanderInsufficientBuffer();
        }
    }

    /**
     * @notice Validates the rebalance operations to ensure they meet all required constraints
     * @dev This function performs a series of checks on each rebalance operation:
     *      1. Ensures general reallocation constraints are met
     *      2. Verifies the buffer ark is not directly involved in rebalancing
     * @param rebalanceData An array of RebalanceData structs, each representing a rebalance operation
     */
    function _validateRebalance(
        RebalanceData[] calldata rebalanceData
    ) internal view {
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            _validateBufferArkNotInvolved(rebalanceData[i]);
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
        if (rebalanceData.length > config.maxRebalanceOperations) {
            revert FleetCommanderRebalanceTooManyOperations(
                rebalanceData.length
            );
        }
        if (rebalanceData.length == 0) {
            revert FleetCommanderRebalanceNoOperations();
        }

        for (uint256 i = 0; i < rebalanceData.length; i++) {
            _validateReallocateAssets(
                rebalanceData[i].fromArk,
                rebalanceData[i].toArk,
                rebalanceData[i].amount
            );
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
     * @custom:error FleetCommanderExceedsMaxOutflow if the amount exceeds the maximum move from limit of the source
     * ARK.
     * @custom:error FleetCommanderExceedsMaxInflow if the amount exceeds the maximum move to limit of the destination
     * ARK.
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
        if (!isArkActive(address(toArk))) {
            revert FleetCommanderArkNotActive(toArk);
        }
        if (!isArkActive(address(fromArk))) {
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
    function _validateBufferRedeem(
        uint256 shares,
        address owner
    ) internal view {
        if (
            _msgSender() != owner &&
            IERC20(address(this)).allowance(owner, _msgSender()) < shares
        ) {
            revert FleetCommanderUnauthorizedRedemption(_msgSender(), owner);
        }

        uint256 maxShares = maxBufferRedeem(owner);
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
    function _validateWithdrawFromArks(
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

    function _stakeOnBehalf(address account, uint256 amount) internal {
        if (address(config.stakingRewardsManager) != address(0)) {
            IFleetRewardsManager(config.stakingRewardsManager).stakeOnBehalf(
                account,
                amount
            );
        }
    }
}
