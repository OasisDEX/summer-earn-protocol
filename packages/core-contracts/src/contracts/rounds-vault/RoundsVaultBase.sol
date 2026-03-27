// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

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

    @dev See { IRoundsVaultBase } for more details.

    @dev Here the `_operate` function is defined as a pure virtual function. This is because the
    specific logic when moving to the next round is left to the derived contracts. Typically they
    will use the `_redeemFromTarget` or `_depositOnTarget` functions to move the funds in or out
    of this vault.
            
    @author Roberto Cano <robercano>
 */
abstract contract RoundsVaultBase is
    ProtocolAccessManaged,
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

    /**
     * CONSTRUCTOR
     */

    /**
        @param proxiedERC4626Vault The address of the ERC4626 vault that this vault will be accepting deposits for
                                   and will be moving funds in and out of it on each round
        @param vaultType The type of the vault (Input or Output) which determines the underlying asset and the exchange asset
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
        BaseVaultType vaultType,
        address accessManager,
        string memory receiptsURI
    )
        ERC4626MultiTokenWrapper(
            proxiedERC4626Vault,
            vaultType == BaseVaultType.Input
                ? IERC4626(proxiedERC4626Vault).asset()
                : proxiedERC4626Vault,
            receiptsURI
        )
        ProtocolAccessManaged(accessManager)
    {
        if (vaultType == BaseVaultType.Input) {
            _exchangeAsset = proxiedERC4626Vault;
        } else {
            _exchangeAsset = IERC4626(proxiedERC4626Vault).asset();
        }
    }

    /**
     * PUBLIC FUNCTIONS
     */

    /**
        @inheritdoc IRoundsVaultBase

        @dev Only callable by the Keeper to move to the next round
     */
    function nextRound() external onlyKeeper {
        Price memory exchangeRate = _getCurrentExchangeRate();

        _exchangeRateByRound[_roundNumber] = exchangeRate;

        roundState[_roundNumber] = RoundState.InSettlement;

        _operate();

        _roundNumber++;

        roundState[_roundNumber] = RoundState.Opened;

        emit NextRound(_roundNumber, exchangeRate);
    }

    /**
     * @inheritdoc IRoundsVaultBase
     */
    function setRoundSettled(uint256 roundNumber) external onlyKeeper {
        _setRoundSettled(roundNumber);
    }

    /**
     * @inheritdoc IRoundsVaultBase
     */
    function setRoundSettledBatch(
        uint256[] calldata roundNumbers
    ) external onlyKeeper {
        for (uint256 i = 0; i < roundNumbers.length; i++) {
            _setRoundSettled(roundNumbers[i]);
        }
    }

    ///@inheritdoc Whitelist
    function setWhitelisted(
        address account,
        bool allowed
    ) external override onlyGovernor {
        _setWhitelisted(account, allowed);
    }

    ///@inheritdoc Whitelist
    function setWhitelistedBatch(
        address[] memory accounts,
        bool[] memory allowed
    ) external override onlyGovernor {
        _setWhitelistedBatch(accounts, allowed);
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

    /**
        @inheritdoc IRoundsVaultBase
     */
    function getExchangeRate(uint256 round) public view returns (Price memory) {
        return _exchangeRateByRound[round];
    }

    // INTERNALS

    /**
        @inheritdoc ERC4626MultiToken
     */
    function _getMintId() internal view virtual override returns (uint256) {
        return _roundNumber;
    }

    /**
        @notice Function to execute the deposit/redeem logic for the current round

        @dev The child contract must implement this function to execute the deposit/redeem logic
        for the current round. Typically it will call `_redeemFromTarget` or `_depositOnTarget`
        from the ERC4626DeferredOperation contract, but the logic is left open for
        other use cases
     */
    function _operate() internal virtual;

    /**
        @notice Retrieves the exchange rate between the underlying asset and the exchange asset for
        the current round. Whether the rate is underlying/exchange or exchange/underlying depends on
        the specific implentation of the derived contract
        
     */
    function _getCurrentExchangeRate()
        internal
        view
        virtual
        returns (Price memory);

    /**
     * @notice Helper function to mark a round as settled
     */
    function _setRoundSettled(uint256 roundNumber) internal {
        roundState[roundNumber] = RoundState.Settled;
        emit RoundSettled(roundNumber);
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
        if (caller != owner) {
            isApprovedForAll(owner, caller);
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
