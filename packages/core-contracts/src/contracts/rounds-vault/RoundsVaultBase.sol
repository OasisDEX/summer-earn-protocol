// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {ProtocolAccessManagedV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagedV2.sol";

import {ERC4626MultiTokenWrapper} from "../../extensions/ERC4626MultiTokenWrapper.sol";
import {IERC4626MultiToken, ERC4626MultiToken} from "../../extensions/ERC4626MultiToken.sol";
import {Whitelist} from "../../utils/Whitelist/Whitelist.sol";
import {IWhitelist} from "../../utils/Whitelist/IWhitelist.sol";

import {IRoundsVaultBase} from "../../interfaces/rounds-vault/IRoundsVaultBase.sol";
import {IRoundsVaultBaseErrors} from "../../interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {IRoundsVaultBaseEvents} from "../../interfaces/rounds-vault/IRoundsVaultBaseEvents.sol";
import {IRoundsVaultBaseEnums} from "../../interfaces/rounds-vault/IRoundsVaultBaseEnums.sol";

/**
    @title RoundsVaultBase

    @notice Provides a way of investing in a target tokenized vault that has investment periods in 
    which the vault is locked.  During these locked periods, the vault does not accept deposits, so
    investors need to be on the lookout for the unlocked period to deposit their funds.

    @dev See { IRoundsVaultBase} for more details.

    @dev Here the `_operate` function is defined as a pure virtual function. This is because the
    specific logic when moving to the next round is left to the derived contracts. Typically they
    will use the `_redeemFromTarget` or `_depositOnTarget` functions to move the funds in or out
    of this vault.
            
    @author Roberto Cano <robercano>
 */
abstract contract RoundsVaultBase is
    ProtocolAccessManagedV2,
    ERC4626MultiTokenWrapper,
    Whitelist,
    IRoundsVaultBase,
    IRoundsVaultBaseErrors,
    IRoundsVaultBaseEvents,
    IRoundsVaultBaseEnums
{
    using PriceUtils for Price;

    /**
     * STORAGE
     */

    uint256 private _roundNumber; /// The current round number, starting from 0 for the first round
    mapping(uint256 => Price) private _exchangeRateByRound; /// The shares exchange rate at the end of each round
    /// @notice The address of the asset that users will receive when redeeming their receipts.
    /// For an Input Vault, this is the shares of the target vault.
    /// For an Output Vault, this is the underlying asset of the target vault.
    address private _exchangeAsset;

    /// @notice Tracks the current progression phase of each round.
    /// @dev Used to ensure users can only redeem assets for rounds that are fully `Settled`.
    mapping(uint256 => RoundState) public roundState;

    /// @notice The minimum aggregate position size for a user to enter or exit
    uint256 private _minPositionSize;

    /// @notice The type of the vault (Input or Output) which determines the underlying asset and the exchange asset
    /// Input: Underlying = proxiedVault.asset(), ExchangeAsset = proxiedVault (the shares)
    /// Output: Underlying = proxiedVault (the shares), ExchangeAsset = proxiedVault.asset()
    BaseVaultType public vaultType;

    /**
     * CONSTRUCTOR
     */

    /**
        @param proxiedERC4626Vault The address of the ERC4626 vault that this vault will be accepting deposits for
                                   and will be moving funds in and out of it on each round
        @param _vaultType The type of the vault (Input or Output) which determines the underlying asset and the exchange asset
                         Input: Underlying = proxiedVault.asset(), ExchangeAsset = proxiedVault (the shares)
                         Output: Underlying = proxiedVault (the shares), ExchangeAsset = proxiedVault.asset()
        @param accessManager The address of the Protocol Access Manager contract that provides information
                             about the different roles in the protocol, including the Keeper role that is the only
                             one allowed to call the `nextRound` function
        @param receiptsURI The URI of the ERC-1155 receipts that will be emitted when depositing the underlying

        @dev It is assumed that the shares token is the same as the vault token as per the 4626 OZ implementation
     */
    constructor(
        address proxiedERC4626Vault,
        BaseVaultType _vaultType,
        address accessManager,
        string memory receiptsURI
    )
        ERC4626MultiTokenWrapper(
            proxiedERC4626Vault,
            _vaultType == BaseVaultType.Input
                ? IERC4626(proxiedERC4626Vault).asset()
                : proxiedERC4626Vault,
            receiptsURI
        )
        ProtocolAccessManagedV2(accessManager)
    {
        if (_vaultType == BaseVaultType.Input) {
            _exchangeAsset = proxiedERC4626Vault;
        } else {
            _exchangeAsset = IERC4626(proxiedERC4626Vault).asset();
        }

        vaultType = _vaultType;
        roundState[0] = RoundState.Opened;
    }

    /**
     * PUBLIC FUNCTIONS
     */

    /**
        @inheritdoc IRoundsVaultBase
     */
    function nextRound() external onlyKeeper {
        uint256 closingRound = _roundNumber;
        if (roundState[closingRound] != RoundState.Opened) {
            revert InvalidRoundState(
                closingRound,
                roundState[closingRound],
                RoundState.Opened
            );
        }

        roundState[closingRound] = RoundState.InSettlement;

        _roundNumber++;
        roundState[_roundNumber] = RoundState.Opened;

        emit RoundAdvanced(closingRound);
    }

    /**
     * @inheritdoc IRoundsVaultBase
     */
    function setRoundSettled(uint256 roundId) external onlyKeeper {
        _setRoundSettled(roundId);
    }

    /**
        @inheritdoc IRoundsVaultBase
     */
    function setRoundSettledBatch(
        uint256[] memory roundIds
    ) external onlyKeeper {
        for (uint256 i = 0; i < roundIds.length; i++) {
            _setRoundSettled(roundIds[i]);
        }
    }

    ///@inheritdoc Whitelist
    function setWhitelisted(
        address account,
        bool allowed
    ) public override onlyGovernor {
        super.setWhitelisted(account, allowed);
    }

    ///@inheritdoc Whitelist
    function setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) public override onlyGovernor {
        super.setWhitelistedBatch(accounts, allowed);
    }

    /**
     * @dev Implementation of the Whitelist proxy adapter's virtual hook.
     */
    function _getAccessManager() internal view override returns (address) {
        return address(_accessManager);
    }

    /**
        @inheritdoc IERC4626MultiToken
     */
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        virtual
        override(IERC4626MultiToken, ERC4626MultiToken)
        onlyWhitelisted(receiver)
        onlyWhitelisted(_msgSender())
        returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    /**
        @inheritdoc IERC4626MultiToken
     */
    function redeem(
        uint256 id,
        uint256 amount,
        address receiver,
        address owner
    )
        public
        virtual
        override(IERC4626MultiToken, ERC4626MultiToken)
        onlyWhitelisted(owner)
        onlyWhitelisted(receiver)
        onlyWhitelisted(_msgSender())
        returns (uint256)
    {
        if (id != _roundNumber) {
            revert CanOnlyRedeemCurrentRound(id, _roundNumber);
        }

        return super.redeem(id, amount, receiver, owner);
    }

    /**
        @inheritdoc IERC4626MultiToken

        @dev Left for completion and compatibility with the VaultDeferredOperation contract, but it is not possible
        to redeem receipts for different rounds here, only for the current round.
     */
    function redeemBatch(
        uint256[] memory ids,
        uint256[] memory amounts,
        address receiver,
        address owner
    )
        public
        virtual
        override(IERC4626MultiToken, ERC4626MultiToken)
        onlyWhitelisted(owner)
        onlyWhitelisted(receiver)
        onlyWhitelisted(_msgSender())
        returns (uint256 assets)
    {
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] != _roundNumber) {
                revert CanOnlyRedeemCurrentRound(ids[i], _roundNumber);
            }
        }

        return super.redeemBatch(ids, amounts, receiver, owner);
    }

    /**
        @inheritdoc IRoundsVaultBase
     */
    function redeemExchangeAsset(
        uint256 id,
        uint256 amount,
        address receiver,
        address owner
    )
        public
        onlyWhitelisted(owner)
        onlyWhitelisted(receiver)
        onlyWhitelisted(_msgSender())
        returns (uint256)
    {
        if (id >= _roundNumber) {
            revert CannotRedeeemExchangeAssetCurrentRound(id, _roundNumber);
        }
        if (roundState[id] != RoundState.Settled) {
            revert RoundNotSettled(id);
        }

        return _redeemExchangeAsset(_msgSender(), receiver, owner, id, amount);
    }

    /**
        @inheritdoc IRoundsVaultBase

        @dev TODO: The user must be prevented from redeeming receipts partially as this could cause a cumulative rounding error
        in the amount of shares redeemed by the user. If for example the share price is 0.8 shares/asset and the user
        tries to redeem exactly 1 wei asset, the user would receive 0 shares. Doing this repeatedly would burn away all
        the receipt unit without ever getting any shares from the target vault. Forcing the user to redeem the full
        amount ensures that the behaviour is consistent with depositing the shares directly in the target vault
     */
    function redeemExchangeAssetBatch(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address receiver,
        address owner
    )
        public
        onlyWhitelisted(owner)
        onlyWhitelisted(receiver)
        onlyWhitelisted(_msgSender())
        returns (uint256 shares)
    {
        if (ids.length != amounts.length) {
            revert BadRedeemBatchParameters(ids.length, amounts.length);
        }

        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] >= _roundNumber) {
                revert CannotRedeeemExchangeAssetCurrentRound(
                    ids[i],
                    _roundNumber
                );
            }
            if (roundState[ids[i]] != RoundState.Settled) {
                revert RoundNotSettled(ids[i]);
            }
        }

        return
            _redeemExchangeAssetBatch(
                _msgSender(),
                receiver,
                owner,
                ids,
                amounts
            );
    }

    // VIEW FUNCTIONS

    /**
        @inheritdoc IRoundsVaultBase
     */
    function getCurrentRound() public view override returns (uint256) {
        return _roundNumber;
    }

    /**
        @inheritdoc IRoundsVaultBase
     */
    function exchangeAsset() public view override returns (address) {
        return _exchangeAsset;
    }

    /** @inheritdoc IRoundsVaultBase*/
    function minPositionSize() public view override returns (uint256) {
        return _minPositionSize;
    }

    /** @inheritdoc IRoundsVaultBase*/
    function setMinPositionSize(uint256 minSize) public override onlyGovernor {
        uint256 oldMin = _minPositionSize;
        _minPositionSize = minSize;
        emit MinPositionSizeUpdated(oldMin, minSize);
    }

    /**
        @inheritdoc IRoundsVaultBase
     */
    function getExchangeRate(uint256 round) public view returns (Price memory) {
        return _exchangeRateByRound[round];
    }

    // INTERNALS

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        super._update(from, to, ids, values);

        uint256 minPosSize = _minPositionSize;
        if (minPosSize == 0) return;

        bool isInputVault = vaultType == BaseVaultType.Input;

        if (to != address(0) && to != address(this)) {
            _revertIfNotWhitelisted(to);

            uint256 aggregateAssets = _getSimplifiedAggregateAssets(
                to,
                isInputVault
            );
            if (aggregateAssets > 0 && aggregateAssets < minPosSize) {
                revert RoundsVaultPositionTooSmall(
                    to,
                    aggregateAssets,
                    minPosSize
                );
            }
        }

        if (from != address(0) && from != address(this)) {
            uint256 aggregateAssets = _getSimplifiedAggregateAssets(
                from,
                isInputVault
            );
            if (aggregateAssets > 0 && aggregateAssets < minPosSize) {
                revert RoundsVaultPositionTooSmall(
                    from,
                    aggregateAssets,
                    minPosSize
                );
            }
        }
    }

    /**
     * @dev Simple aggregate calculation based on your "easy" logic:
     *      - Output Vault receipts (withdrawal queue) are treated as 0 (already gone).
     *      - Input Vault receipts (deposit queue) are treated as assets.
     */
    function _getSimplifiedAggregateAssets(
        address user,
        bool isInputVault
    ) internal view returns (uint256) {
        uint256 targetAssets = IERC4626(vault()).convertToAssets(
            IERC4626(vault()).balanceOf(user)
        );
        if (isInputVault) {
            // For Input Vault, pending receipts are 1:1 with USDC
            return targetAssets + balanceOfAll(user);
        } else {
            // For Output Vault, pending receipts are ignored (gone)
            return targetAssets;
        }
    }

    /**
        @inheritdoc ERC4626MultiToken
     */
    function _getMintId() internal view virtual override returns (uint256) {
        return _roundNumber;
    }

    /**
        @notice Function to execute the deposit/redeem logic for a frozen amount
 
        @param amount The exact amount to be settled
        @param roundId The id of the round to be settled
        @return outputAmount The exact amount received after the trade
 
        @dev The child contract must implement this function to execute the deposit/redeem logic
        for the frozen amount. Typically it will call `_redeemFromTarget` or `_depositOnTarget`.
     */
    function _operate(
        uint256 amount,
        uint256 roundId
    ) internal virtual returns (uint256 outputAmount);

    /**
        @notice Retrieves the exchange rate between the underlying asset and the exchange asset for
        the current round. Whether the rate is underlying/exchange or exchange/underlying depends on
        the specific implentation of the derived contract
     */
    function _getFallbackExchangeRate()
        internal
        view
        virtual
        returns (Price memory);

    /**
     * @notice Helper function to mark a round as settled
     */
    function _setRoundSettled(uint256 roundId) internal {
        if (roundState[roundId] != RoundState.InSettlement) {
            revert InvalidRoundState(
                roundId,
                roundState[roundId],
                RoundState.InSettlement
            );
        }

        // 1. Fetch exact liability using ERC-1155 total supply for this specific round
        uint256 frozenAmount = totalSupply(roundId);

        Price memory finalExchangeRate;

        if (frozenAmount > 0) {
            // 2. Execute the trade and get the EXACT amount returned by the off-chain reality
            uint256 outputAmount = _operate(frozenAmount, roundId);
            // 3. Construct the precise exchange rate based on the actual execution
            finalExchangeRate = toPrice(outputAmount, frozenAmount);
        } else {
            // Fallback to 1:1 or preview rate if round was empty
            finalExchangeRate = _getFallbackExchangeRate();
        }

        _exchangeRateByRound[roundId] = finalExchangeRate;
        roundState[roundId] = RoundState.Settled;

        emit RoundSettled(roundId, finalExchangeRate);
    }

    // PRIVATES

    /**
        @notice Checks if the receipt corresponds to any previous round, and if so, it calculates how many shares
                the user should receive based on the receipt's round share price and the amount of deposited tokens

        @param id The id of the receipt to be redeemed
        @param amount The amount of the receipt to be redeemed
        @param receiver The address that will receive the underlying tokens
        @param owner The address that owns the receipt, in case the caller is not the owner
    */

    // @audit This function follows the CEI pattern to avoid out-of-order execution. The only
    // external call is `safeTransfer` that is done at the end of the function where the state
    // of the contract is consistent and a reentrancy is protected by the `_burn` function that
    // will check the balance of the user

    function _redeemExchangeAsset(
        address caller,
        address receiver,
        address owner,
        uint256 id,
        uint256 amount
    ) private returns (uint256 exchangeAmount) {
        if (caller != owner && !isApprovedForAll(owner, caller)) {
            revert CallerCannotRedeem(caller, owner, id, amount);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transfered, which is a valid state.
        _burn(owner, id, amount);

        exchangeAmount = _exchangeRateByRound[id].quote(amount);

        SafeERC20.safeTransfer(
            IERC20(_exchangeAsset),
            receiver,
            exchangeAmount
        );

        emit WithdrawExchangeAsset(
            _msgSender(),
            receiver,
            owner,
            exchangeAmount,
            id,
            amount
        );
    }

    /**
        @notice Checks if the receipt corresponds to any previous round, and if so, it calculates how many shares
                the user should receive based on the receipt's round share price and the amount of deposited tokens

        @param caller The address that is calling the function
        @param receiver The address that will receive the exchange asset tokens
        @param owner The address that owns the receipt, in case the caller is not the owner
        @param ids The ids of the receipts to be redeemed
        @param amounts The amounts of the receipts to be redeemed
     */

    // @audit This function follows the CEI pattern to avoid out-of-order execution. The only
    // external call is `safeTransfer` that is done at the end of the function where the state
    // of the contract is consistent and a reentrancy is protected by the `_burnBatch` function that
    // will check the balance of the user

    function _redeemExchangeAssetBatch(
        address caller,
        address receiver,
        address owner,
        uint256[] memory ids,
        uint256[] memory amounts
    ) private returns (uint256 exchangeAmount) {
        if (caller != owner && !isApprovedForAll(owner, caller)) {
            revert CallerCannotRedeemBatch(caller, owner, ids, amounts);
        }

        // If _asset is ERC777, `transfer` can trigger trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transfered, which is a valid state.
        _burnBatch(owner, ids, amounts);

        for (uint256 i = 0; i < ids.length; i++) {
            exchangeAmount += _exchangeRateByRound[ids[i]].quote(amounts[i]);
        }

        SafeERC20.safeTransfer(
            IERC20(_exchangeAsset),
            receiver,
            exchangeAmount
        );

        emit WithdrawExchangeAssetBatch(
            caller,
            receiver,
            owner,
            exchangeAmount,
            ids,
            amounts
        );
    }
}
