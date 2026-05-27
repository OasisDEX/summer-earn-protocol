// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommanderWhitelist} from "../interfaces/IFleetCommanderWhitelist.sol";
import {ArkData, FleetCommanderWhitelistParams, RebalanceData} from "../types/FleetCommanderTypes.sol";

import {FleetCommanderCache} from "./FleetCommanderCache.sol";
import {FleetCommanderConfigProviderWhitelist} from "./FleetCommanderConfigProviderWhitelist.sol";

import {FlexibleTipper} from "./FlexibleTipper.sol";
import {ERC20, ERC4626, IERC20, IERC4626, SafeERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Constants} from "@summerfi/constants/Constants.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title FleetCommanderWhitelist
 * @notice Manages a fleet of Arks with restricted entry/exit via a Whitelist and Operator role.
 * @dev Implements IFleetCommanderWhitelist interface and inherits from various utility contracts.
 *      Entry (deposit/mint) and exit (withdraw/redeem) operations are gated by the operator gateway.
 *      The gateway status is controlled by the `isOperatorGatewayOpen` flag in the config.
 *      When the gateway is closed, only accounts with the OPERATOR_ROLE can perform these actions.
 *      When the gateway is open, all whitelisted accounts can perform these actions.
 */
contract FleetCommanderWhitelist is
    IFleetCommanderWhitelist,
    FleetCommanderConfigProviderWhitelist,
    ERC4626,
    FlexibleTipper,
    FleetCommanderCache
{
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the FleetCommander contract.
     * @param params `FleetCommanderWhitelistParams` struct containing the asset, name/symbol,
     *               buffer-ark address, fee parameters, gateway state, and access-manager wiring.
     */
    constructor(
        FleetCommanderWhitelistParams memory params
    )
        ERC4626(IERC20(params.asset))
        ERC20(params.name, params.symbol)
        FleetCommanderConfigProviderWhitelist(params)
        FlexibleTipper(params.initialTipRate)
    {}

    /*//////////////////////////////////////////////////////////////
                            PRIVATE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _collectTipPre() private {
        _setIsCollectingTip(true);
        _accrueTip(tipJar(), totalSupply());
    }

    function _collectTipPost() private {
        _setIsCollectingTip(false);
    }

    function _useCachePre() private {
        _getArksData(config.bufferArk);
    }

    function _useWithdrawCachePre() private {
        _getWithdrawableArksData(config.bufferArk);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to collect the tip before any other action is taken
     */
    modifier collectTip() {
        _collectTipPre();
        _;
        _collectTipPost();
    }
    /**
     * @notice Caches deposit-side ark data into transient storage for the duration of the call.
     * @dev Pre-fetches ark totals up front so the subsequent `totalAssets` / cap checks read from
     *      transient storage instead of re-calling each ark — those external calls can be gas-
     *      expensive on some arks. The cache is torn down by the outermost `flushCacheOnExit`.
     */
    modifier useCache() {
        _useCachePre();
        _;
    }

    /**
     * @notice Caches withdraw-side ark data into transient storage for the duration of the call.
     * @dev Same rationale as `useCache` but limited to arks that allow synchronous withdrawal, so
     *      `_forceDisembarkFromSortedArks` can iterate them without re-calling each ark.
     */
    modifier useWithdrawCache() {
        _useWithdrawCachePre();
        _;
    }

    /**
     * @notice Flushes the transient-storage cache after the wrapped call completes.
     * @dev Must be attached to the outermost external/public function that initialized the cache
     *      (`useCache` / `useWithdrawCache`) so the cache is always torn down on the way out.
     */
    modifier flushCacheOnExit() {
        _;
        _flushCache();
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommanderWhitelist
    function withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    )
        external
        flushCacheOnExit
        whenNotPaused
        useCache
        collectTip
        returns (uint256 shares)
    {
        _enforceExitGateway(_msgSender(), receiver, owner);
        shares = _withdrawFromBuffer(assets, receiver, owner);
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(ERC4626, IFleetCommanderWhitelist)
        flushCacheOnExit
        useCache
        collectTip
        whenNotPaused
        returns (uint256 assets)
    {
        _enforceExitGateway(_msgSender(), receiver, owner);
        uint256 bufferBalance = config.bufferArk.totalAssets();
        uint256 bufferBalanceInShares = convertToShares(bufferBalance);

        if (shares == Constants.MAX_UINT256) {
            shares = balanceOf(owner);
        }

        if (shares <= bufferBalanceInShares) {
            assets = _redeemFromBuffer(shares, receiver, owner);
        } else {
            assets = _redeemFromArks(shares, receiver, owner);
        }
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        flushCacheOnExit
        useCache
        collectTip
        whenNotPaused
        returns (uint256 assets)
    {
        _enforceExitGateway(_msgSender(), receiver, owner);
        assets = _redeemFromBuffer(shares, receiver, owner);
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(ERC4626, IFleetCommanderWhitelist)
        flushCacheOnExit
        useCache
        collectTip
        whenNotPaused
        returns (uint256 shares)
    {
        _enforceExitGateway(_msgSender(), receiver, owner);
        uint256 bufferBalance = config.bufferArk.totalAssets();

        if (assets == Constants.MAX_UINT256) {
            uint256 totalUserShares = balanceOf(owner);
            assets = previewRedeem(totalUserShares);
        }

        if (assets <= bufferBalance) {
            shares = _withdrawFromBuffer(assets, receiver, owner);
        } else {
            shares = _withdrawFromArks(assets, receiver, owner);
        }
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function withdrawFromArks(
        uint256 assets,
        address receiver,
        address owner
    )
        external
        override(IFleetCommanderWhitelist)
        flushCacheOnExit
        collectTip
        whenNotPaused
        returns (uint256 totalSharesToRedeem)
    {
        _enforceExitGateway(_msgSender(), receiver, owner);
        totalSharesToRedeem = _withdrawFromArks(assets, receiver, owner);
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    )
        external
        override(IFleetCommanderWhitelist)
        flushCacheOnExit
        collectTip
        whenNotPaused
        returns (uint256 totalAssetsToWithdraw)
    {
        _enforceExitGateway(_msgSender(), receiver, owner);
        totalAssetsToWithdraw = _redeemFromArks(shares, receiver, owner);
    }

    /// @inheritdoc IERC4626
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override(ERC4626, IERC4626)
        flushCacheOnExit
        useCache
        collectTip
        whenNotPaused
        returns (uint256 shares)
    {
        _enforceEntryGateway(_msgSender(), receiver);
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

    /// @inheritdoc IERC4626
    function mint(
        uint256 shares,
        address receiver
    )
        public
        override(ERC4626, IERC4626)
        flushCacheOnExit
        useCache
        collectTip
        whenNotPaused
        returns (uint256 assets)
    {
        _enforceEntryGateway(_msgSender(), receiver);
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

    /// @inheritdoc IFleetCommanderWhitelist
    function tip() public onlyKeeper whenNotPaused returns (uint256) {
        return _accrueTip(tipJar(), super.totalSupply());
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC20
     * @dev Overridden to fold the pending tip shares into the reported total supply, so external
     *      integrators always see an honest share count. The check on `_isCollectingTip` makes the
     *      function reentrancy-safe when the contract is mid-tip: while collecting, the parent
     *      `super.totalSupply()` is returned (pre-tip) to avoid recursion through `previewTip`;
     *      outside of tip collection, the function adds the previewed tip. After the tip is
     *      collected, `super.totalSupply()` itself already includes the freshly minted tip shares.
     * @return The total supply of the FleetCommander, including tip shares
     */
    function totalSupply()
        public
        view
        override(ERC20, IERC20)
        returns (uint256)
    {
        if (_isCollectingTip()) {
            return super.totalSupply();
        }
        uint256 _totalSupply = super.totalSupply();
        return _totalSupply + previewTip(tipJar(), _totalSupply);
    }

    /// @inheritdoc ERC4626
    function totalAssets()
        public
        view
        override(IFleetCommanderWhitelist, ERC4626)
        returns (uint256)
    {
        return _totalAssets(config.bufferArk);
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function withdrawableTotalAssets() public view returns (uint256) {
        return _withdrawableTotalAssets(config.bufferArk);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256 _maxDeposit) {
        if (_isMaxFunctionBlocked(owner)) return 0;

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
        if (_isMaxFunctionBlocked(owner)) return 0;

        uint256 _totalAssets = totalAssets();
        uint256 maxAssets = _totalAssets > config.depositCap
            ? 0
            : config.depositCap - _totalAssets;
        _maxMint = previewDeposit(
            Math.min(maxAssets, IERC20(asset()).balanceOf(owner))
        );
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function maxBufferWithdraw(
        address owner
    ) public view returns (uint256 _maxBufferWithdraw) {
        if (_isMaxFunctionBlocked(owner)) return 0;

        _maxBufferWithdraw = Math.min(
            config.bufferArk.totalAssets(),
            previewRedeem(balanceOf(owner))
        );
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256 _maxWithdraw) {
        if (_isMaxFunctionBlocked(owner)) return 0;

        _maxWithdraw = Math.min(
            withdrawableTotalAssets(),
            previewRedeem(balanceOf(owner))
        );
    }

    /// @inheritdoc IERC4626
    function maxRedeem(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256 _maxRedeem) {
        if (_isMaxFunctionBlocked(owner)) return 0;

        _maxRedeem = Math.min(
            convertToShares(withdrawableTotalAssets()),
            balanceOf(owner)
        );
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function maxBufferRedeem(
        address owner
    ) public view returns (uint256 _maxBufferRedeem) {
        if (_isMaxFunctionBlocked(owner)) return 0;

        _maxBufferRedeem = Math.min(
            previewWithdraw(config.bufferArk.totalAssets()),
            balanceOf(owner)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommanderWhitelist
    function rebalance(
        RebalanceData[] calldata rebalanceData
    ) external onlyKeeper collectTip whenNotPaused {
        _validateReallocateAllAssets(rebalanceData);
        _validateAdjustBuffer(rebalanceData);
        _reallocateAllAssets(rebalanceData);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommanderWhitelist
    function setTipRate(
        Percentage newTipRate
    ) external onlyGovernor whenNotPaused {
        // The newTipRate uses the Percentage type from @summerfi/percentage-solidity
        // Percentages have 18 decimals of precision
        // For example, 1% would be represented as 1 * 10^18 (assuming PERCENTAGE_DECIMALS is 18)
        // we use the super.totalSupply() to avoid the tip shares from being included in the tip calculation
        _setTipRate(newTipRate, tipJar(), super.totalSupply());
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function setMinimumPauseTime(
        uint256 _newMinimumPauseTime
    ) public onlyGovernor whenNotPaused {
        _setMinimumPauseTime(_newMinimumPauseTime);
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function pause() external onlyGovernor {
        _pause();
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function unpause() external onlyGovernor {
        _unpause();
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function setFeeType(
        FeeType newFeeType
    ) external onlyGovernor whenNotPaused {
        _setFeeType(newFeeType, tipJar(), totalAssets(), super.totalSupply());
    }

    /// @inheritdoc IFleetCommanderWhitelist
    function setPerformanceFeeRate(
        Percentage newRate
    ) external onlyGovernor whenNotPaused {
        _setPerformanceFeeRate(newRate, tipJar(), super.totalSupply());
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20
    function transfer(
        address to,
        uint256 amount
    ) public override(IERC20, ERC20) whenNotPaused returns (bool) {
        if (hasOperatorRole(_msgSender())) {
            return super.transfer(to, amount);
        }

        if (!transfersEnabled) {
            revert FleetCommanderTransfersDisabled();
        }
        _revertIfNotWhitelisted(address(this), _msgSender(), to);

        return super.transfer(to, amount);
    }

    /// @inheritdoc IERC20
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(IERC20, ERC20) whenNotPaused returns (bool) {
        if (hasOperatorRole(_msgSender())) {
            return super.transferFrom(from, to, amount);
        }

        if (!transfersEnabled) {
            revert FleetCommanderTransfersDisabled();
        }
        _revertIfNotWhitelisted(address(this), _msgSender(), from, to);

        return super.transferFrom(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to withdraw a specific amount of assets from the buffer ark
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the withdrawn assets
     * @param owner The address owning the shares to be burned
     * @return shares The amount of shares burned
     */
    function _withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    ) internal returns (uint256 shares) {
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

    /**
     * @notice Internal function to redeem a specific amount of shares from the buffer ark
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the underlying assets
     * @param owner The address owning the shares to be burned
     * @return assets The amount of assets withdrawn
     */
    function _redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    ) internal returns (uint256 assets) {
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

    /**
     * @notice Internal function to withdraw assets directly from deployed Arks
     * @dev Fetches withdrawable arks data to ensure cache state before discharging assets
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the underlying assets
     * @param owner The address owning the shares to be burned
     * @return totalSharesToRedeem The amount of shares burned
     *
     * @dev The function uses the cache to get the withdrawable arks data and it expects
     *      the topmost caller to flush the cache
     */
    function _withdrawFromArks(
        uint256 assets,
        address receiver,
        address owner
    ) internal returns (uint256 totalSharesToRedeem) {
        _useWithdrawCachePre();

        totalSharesToRedeem = previewWithdraw(assets);

        _validateWithdrawFromArks(assets, totalSharesToRedeem, owner);

        _forceDisembarkFromSortedArks(assets);
        _withdraw(_msgSender(), receiver, owner, assets, totalSharesToRedeem);

        emit FleetCommanderWithdrawnFromArks(owner, receiver, assets);
    }

    /**
     * @notice Internal function to redeem shares to withdraw assets directly from deployed Arks
     * @dev Fetches withdrawable arks data to ensure cache state before discharging assets
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the underlying assets
     * @param owner The address owning the shares to be burned
     * @return totalAssetsToWithdraw The amount of assets withdrawn
     *
     * @dev The function uses the cache to get the withdrawable arks data and it expects
     *      the topmost caller to flush the cache
     */
    function _redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    ) internal returns (uint256 totalAssetsToWithdraw) {
        _useWithdrawCachePre();

        _validateRedeemFromArks(shares, owner);

        totalAssetsToWithdraw = previewRedeem(shares);
        _forceDisembarkFromSortedArks(totalAssetsToWithdraw);
        _withdraw(_msgSender(), receiver, owner, totalAssetsToWithdraw, shares);
        emit FleetCommanderRedeemedFromArks(owner, receiver, shares);
    }

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
     * @notice Returns the total assets for FlexibleTipper fee calculation
     * @dev Implements the abstract hook from FlexibleTipper.
     *      Delegates to totalAssets() which uses the FleetCommanderCache.
     * @return The total assets held across all arks
     */
    function _getTotalAssetsForFee() internal view override returns (uint256) {
        return totalAssets();
    }

    /**
     * @notice Enforces gateway restrictions for entry operations (deposit/mint)
     * @dev Checks if the caller has the OPERATOR_ROLE; if not, verifies that the gateway
     *      is open and that both `caller` and `receiver` are whitelisted for this fleet.
     * @param caller The address of the caller
     * @param receiver The address of the receiver
     */
    function _enforceEntryGateway(
        address caller,
        address receiver
    ) internal view {
        if (hasOperatorRole(caller)) {
            return;
        }

        if (!config.isOperatorGatewayOpen) {
            revert FleetCommanderDirectDepositsClosed();
        }

        _revertIfNotWhitelisted(address(this), caller, receiver);
    }

    /**
     * @notice Enforces gateway restrictions for exit operations (withdraw/redeem)
     * @dev Checks if the caller has the OPERATOR_ROLE; if not, verifies that the gateway
     *      is open and that `caller`, `receiver`, and `owner` are whitelisted for this fleet.
     * @param caller The address of the caller
     * @param receiver The address of the receiver
     * @param owner The address of the owner of the shares
     */
    function _enforceExitGateway(
        address caller,
        address receiver,
        address owner
    ) internal view {
        if (hasOperatorRole(caller)) {
            return;
        }

        if (!config.isOperatorGatewayOpen) {
            revert FleetCommanderDirectWithdrawalsClosed();
        }
        _revertIfNotWhitelisted(address(this), caller, receiver, owner);
    }

    /**
     * @notice Reallocates all assets based on the provided rebalance data
     * @param rebalanceData Array of RebalanceData structs containing information about the reallocation
     */
    function _reallocateAllAssets(
        RebalanceData[] calldata rebalanceData
    ) internal {
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            _reallocateAssets(rebalanceData[i]);
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
        IERC20(asset()).forceApprove(ark, amount);
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
     * @custom:error FleetCommanderEffectiveDepositCapExceeded Thrown when the destination Ark is already at or above
     * its maximum
     * allocation
     */
    function _reallocateAssets(RebalanceData memory data) internal {
        IArk toArk = IArk(data.toArk);
        IArk fromArk = IArk(data.fromArk);
        uint256 amount;
        if (data.amount == Constants.MAX_UINT256) {
            amount = fromArk.totalAssets();
        } else {
            amount = data.amount;
        }
        // The validation has to take into account the actual amount that will be moved
        _validateReallocateAssets(data.fromArk, data.toArk, amount);

        uint256 toArkDepositCap = getEffectiveArkDepositCap(toArk);
        uint256 toArkAllocation = toArk.totalAssets();

        if (toArkAllocation + amount > toArkDepositCap) {
            revert FleetCommanderEffectiveDepositCapExceeded(
                address(toArk),
                amount,
                toArkDepositCap
            );
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
     * @notice Calculates the effective deposit cap for an Ark
     * @dev This function returns the lower of two caps: a percentage-based cap derived from TVL,
     *      and the absolute deposit cap set for the Ark
     * @param ark The address of the Ark
     * @return The effective deposit cap in token units
     */

    function getEffectiveArkDepositCap(IArk ark) public view returns (uint256) {
        uint256 tvl = this.totalAssets();
        uint256 pctBasedCap = tvl.applyPercentage(
            ark.maxDepositPercentageOfTVL()
        );
        return Math.min(pctBasedCap, ark.depositCap());
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
     * @custom:error FleetCommanderNoExcessFunds Thrown when trying to move funds out of an already minimum buffer
     * @custom:error FleetCommanderInsufficientBuffer Thrown when trying to move more funds than available excess
     * @custom:error FleetCommanderCantUseMaxUintMovingFromBuffer Thrown when trying to use MAX_UINT256 amount when
     * moving from buffer
     */
    function _validateAdjustBuffer(
        RebalanceData[] calldata rebalanceData
    ) internal view {
        uint256 initialBufferBalance = config.bufferArk.totalAssets();
        int256 netBufferChange;
        address _bufferArkAddress = address(config.bufferArk);
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            if (
                rebalanceData[i].toArk == _bufferArkAddress ||
                rebalanceData[i].fromArk == _bufferArkAddress
            ) {
                bool isMovingToBuffer = rebalanceData[i].toArk ==
                    _bufferArkAddress;
                uint256 amount = rebalanceData[i].amount;
                if (amount == Constants.MAX_UINT256) {
                    if (!isMovingToBuffer) {
                        revert FleetCommanderCantUseMaxUintMovingFromBuffer();
                    }
                    amount = IArk(rebalanceData[i].fromArk).totalAssets();
                }
                if (isMovingToBuffer) {
                    netBufferChange += int256(amount);
                } else {
                    netBufferChange -= int256(amount);
                }
            }
        }
        if (netBufferChange < 0) {
            _validateBufferExcessFunds(
                initialBufferBalance,
                uint256(-netBufferChange)
            );
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
        uint256 minimumBufferBalance = config.minimumBufferBalance;
        if (initialBufferBalance <= minimumBufferBalance) {
            revert FleetCommanderNoExcessFunds();
        }
        uint256 excessFunds = initialBufferBalance - minimumBufferBalance;
        if (totalToMove > excessFunds) {
            revert FleetCommanderInsufficientBuffer();
        }
    }

    /**
     * @notice Validates the asset reallocation data for correctness and consistency
     * @dev This function checks various conditions of the rebalance operations:
     *      - Number of operations is within limits
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
    ) internal {
        if (amount == 0) {
            revert FleetCommanderRebalanceAmountZero(toArk);
        }
        if (toArk == address(0)) {
            revert FleetCommanderArkNotFound(toArk);
        }
        if (fromArk == address(0)) {
            revert FleetCommanderArkNotFound(fromArk);
        }
        if (!isArkActiveOrBufferArk(toArk)) {
            revert FleetCommanderArkNotActive(toArk);
        }
        if (!isArkActiveOrBufferArk(fromArk)) {
            revert FleetCommanderArkNotActive(fromArk);
        }
        if (IArk(toArk).depositCap() == 0) {
            revert FleetCommanderArkDepositCapZero(toArk);
        }
        (
            uint256 inflowBalance,
            uint256 outflowBalance,
            uint256 maxRebalanceInflow,
            uint256 maxRebalanceOutflow
        ) = _cacheArkFlow(fromArk, toArk, amount);
        if (outflowBalance > maxRebalanceOutflow) {
            revert FleetCommanderExceedsMaxOutflow(
                fromArk,
                outflowBalance,
                maxRebalanceOutflow
            );
        }
        if (inflowBalance > maxRebalanceInflow) {
            revert FleetCommanderExceedsMaxInflow(
                toArk,
                inflowBalance,
                maxRebalanceInflow
            );
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
     * @custom:error FleetCommanderZeroAmount Thrown when the withdrawal amount is zero
     */
    function _validateBufferWithdraw(
        uint256 assets,
        uint256 shares,
        address owner
    ) internal view {
        if (shares == 0) {
            revert FleetCommanderZeroAmount();
        }
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
     * @custom:error FleetCommanderZeroAmount Thrown when the redemption amount is zero
     */
    function _validateBufferRedeem(
        uint256 shares,
        address owner
    ) internal view {
        if (shares == 0) {
            revert FleetCommanderZeroAmount();
        }
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
     * @custom:error FleetCommanderZeroAmount Thrown when the deposit amount is zero
     * @custom:error IERC4626ExceededMaxDeposit Thrown when the deposit amount exceeds the maximum allowed
     */
    function _validateDeposit(uint256 assets, address owner) internal view {
        if (assets == 0) {
            revert FleetCommanderZeroAmount();
        }
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
     * @custom:error FleetCommanderZeroAmount Thrown when the mint amount is zero
     * @custom:error IERC4626ExceededMaxMint Thrown when the mint amount exceeds the maximum allowed
     */
    function _validateMint(uint256 shares, address owner) internal view {
        if (shares == 0) {
            revert FleetCommanderZeroAmount();
        }
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
     * @custom:error FleetCommanderZeroAmount Thrown when the withdrawal amount is zero
     */
    function _validateWithdrawFromArks(
        uint256 assets,
        uint256 shares,
        address owner
    ) internal view {
        if (shares == 0) {
            revert FleetCommanderZeroAmount();
        }
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
     * @custom:error FleetCommanderZeroAmount Thrown when the redemption amount is zero
     */
    function _validateRedeemFromArks(
        uint256 shares,
        address owner
    ) internal view {
        if (shares == 0) {
            revert FleetCommanderZeroAmount();
        }
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

    function _getActiveArksAddresses()
        internal
        view
        override(FleetCommanderCache)
        returns (address[] memory)
    {
        return getActiveArks();
    }

    /**
     * @notice Checks if the max functions are blocked
     * @dev This function checks if the contract is paused, if the caller has operator role, or if the operator gateway
     * is closed and the caller is not whitelisted
     * @param account The address to check
     * @return True if the max functions are blocked, false otherwise
     */
    function _isMaxFunctionBlocked(
        address account
    ) internal view returns (bool) {
        if (paused()) return true;

        if (hasOperatorRole(_msgSender())) {
            return false;
        }

        return
            !config.isOperatorGatewayOpen ||
            !_isWhitelisted(address(this), account);
    }
}
