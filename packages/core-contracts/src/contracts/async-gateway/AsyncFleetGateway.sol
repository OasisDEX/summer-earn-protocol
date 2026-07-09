// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {ProtocolAccessManagedV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagedV2.sol";

import {ERC1155FullSupply} from "../../extensions/ERC1155FullSupply.sol";
import {Whitelist} from "../../utils/Whitelist/Whitelist.sol";

import {IAsyncFleetGateway} from "../../interfaces/async-gateway/IAsyncFleetGateway.sol";
import {IAsyncFleetGatewayErrors} from "../../interfaces/async-gateway/IAsyncFleetGatewayErrors.sol";
import {IAsyncFleetGatewayEvents} from "../../interfaces/async-gateway/IAsyncFleetGatewayEvents.sol";
import {IERC7540Operator, IERC7540Deposit, IERC7540Redeem} from "../../interfaces/async-gateway/IERC7540.sol";
import {IERC7575Minimal} from "../../interfaces/async-gateway/IERC7575Minimal.sol";

/**
 * @title AsyncFleetGateway (POC)
 * @notice ERC-7540 asynchronous entry point for an ERC-4626 fleet. The fleet's own ERC-20 share
 *         is the ERC-7575 external share token; this gateway never mints its own shares. Requests
 *         are batched into per-flow epochs (epoch == ERC-7540 requestId) and tokenized as
 *         ERC-1155 receipts (id = epoch << 1 | flowBit). A keeper closes and settles epochs; the
 *         settlement trade against the fleet snapshots the epoch's exchange rate, and claims
 *         consume receipts FIFO across settled epochs at each epoch's rate.
 */
contract AsyncFleetGateway is
    ProtocolAccessManagedV2,
    ERC1155FullSupply,
    Whitelist,
    IAsyncFleetGateway,
    IAsyncFleetGatewayErrors,
    IAsyncFleetGatewayEvents
{
    using PriceUtils for Price;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    /// @notice The target ERC-4626 fleet; also the ERC-7575 external share token.
    IERC4626 private immutable FLEET;
    /// @notice The fleet's underlying asset (this vault's ERC-4626 asset).
    IERC20 private immutable ASSET;

    uint256 private _currentDepositEpoch;
    uint256 private _currentRedeemEpoch;
    mapping(uint256 => EpochState) private _depositEpochState;
    mapping(uint256 => EpochState) private _redeemEpochState;
    /// @dev Deposit epoch rate: base = fleet shares out, quote = assets in.
    mapping(uint256 => Price) private _depositRate;
    /// @dev Redeem epoch rate: base = assets out, quote = fleet shares in.
    mapping(uint256 => Price) private _redeemRate;
    /// @dev ERC-7540 operator approvals: controller => operator => approved.
    mapping(address => mapping(address => bool)) private _isOperator;
    /// @dev Receipt ids (both flows) currently held by an account; drives FIFO claims.
    mapping(address => EnumerableSet.UintSet) private _receiptIdsOf;

    constructor(
        address fleet_,
        address accessManager,
        string memory receiptsURI
    ) ERC1155(receiptsURI) ProtocolAccessManagedV2(accessManager) {
        FLEET = IERC4626(fleet_);
        ASSET = IERC20(IERC4626(fleet_).asset());
        _depositEpochState[0] = EpochState.Open;
        _redeemEpochState[0] = EpochState.Open;
    }

    // ---------- identity views ----------

    /// @inheritdoc IAsyncFleetGateway
    function fleet() public view returns (address) {
        return address(FLEET);
    }

    /// @inheritdoc IERC7575Minimal
    function share() public view returns (address) {
        return address(FLEET);
    }

    /// @inheritdoc IERC7575Minimal
    function asset() public view returns (address) {
        return address(ASSET);
    }

    /// @inheritdoc IAsyncFleetGateway
    function totalAssets() public view returns (uint256) {
        return ASSET.balanceOf(address(this));
    }

    /// @inheritdoc IAsyncFleetGateway
    function currentDepositEpoch() public view returns (uint256) {
        return _currentDepositEpoch;
    }

    /// @inheritdoc IAsyncFleetGateway
    function currentRedeemEpoch() public view returns (uint256) {
        return _currentRedeemEpoch;
    }

    /// @inheritdoc IAsyncFleetGateway
    function depositEpochState(uint256 epoch) public view returns (EpochState) {
        return _depositEpochState[epoch];
    }

    /// @inheritdoc IAsyncFleetGateway
    function redeemEpochState(uint256 epoch) public view returns (EpochState) {
        return _redeemEpochState[epoch];
    }

    /// @inheritdoc IAsyncFleetGateway
    function depositRate(uint256 epoch) public view returns (Price memory) {
        return _depositRate[epoch];
    }

    /// @inheritdoc IAsyncFleetGateway
    function redeemRate(uint256 epoch) public view returns (Price memory) {
        return _redeemRate[epoch];
    }

    /// @inheritdoc IAsyncFleetGateway
    function depositReceiptId(uint256 epoch) public pure returns (uint256) {
        return epoch << 1;
    }

    /// @inheritdoc IAsyncFleetGateway
    function redeemReceiptId(uint256 epoch) public pure returns (uint256) {
        return (epoch << 1) | 1;
    }

    // ---------- ERC-165 ----------

    /// @inheritdoc ERC1155
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, IERC165) returns (bool) {
        return
            interfaceId == 0xe3bc4e65 || // IERC7540Operator
            interfaceId == 0xce3bbe50 || // IERC7540Deposit (async deposit vault)
            interfaceId == 0x620ee8e4 || // IERC7540Redeem (async redeem vault)
            interfaceId == 0x2f0a18c5 || // ERC-7575 vault
            super.supportsInterface(interfaceId);
    }

    // ---------- wiring ----------

    /// @inheritdoc Whitelist
    function _getAccessManager() internal view override returns (address) {
        return address(_accessManager);
    }

    /// @dev Maintains the per-account receipt-id set used for FIFO claims.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        super._update(from, to, ids, values);
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (from != address(0) && balanceOf(from, id) == 0) {
                _receiptIdsOf[from].remove(id);
            }
            if (to != address(0) && balanceOf(to, id) > 0) {
                _receiptIdsOf[to].add(id);
            }
        }
    }

    /// @inheritdoc IERC7540Operator
    function setOperator(
        address operator,
        bool approved
    ) public returns (bool) {
        _isOperator[_msgSender()][operator] = approved;
        emit OperatorSet(_msgSender(), operator, approved);
        return true;
    }

    /// @inheritdoc IERC7540Operator
    function isOperator(
        address controller,
        address operator
    ) public view returns (bool) {
        return _isOperator[controller][operator];
    }

    /// @dev ERC-7540 authorization: msg.sender must be the controller or an approved operator.
    function _requireControllerOrOperator(address controller) internal view {
        if (
            controller != _msgSender() && !_isOperator[controller][_msgSender()]
        ) {
            revert InvalidOperator(controller, _msgSender());
        }
    }

    /// @dev Ascending (FIFO) list of the controller's receipt ids for one flow, settled epochs only.
    function _sortedSettledReceipts(
        address controller,
        bool redeemFlow
    ) internal view returns (uint256[] memory ids, uint256 count) {
        uint256 len = _receiptIdsOf[controller].length();
        ids = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 id = _receiptIdsOf[controller].at(i);
            if ((id & 1 == 1) != redeemFlow) continue;
            uint256 epoch = id >> 1;
            EpochState state = redeemFlow
                ? _redeemEpochState[epoch]
                : _depositEpochState[epoch];
            if (state != EpochState.Settled) continue;
            // insertion sort ascending — receipt sets are small (distinct epochs with holdings)
            uint256 j = count;
            while (j > 0 && ids[j - 1] > id) {
                ids[j] = ids[j - 1];
                j--;
            }
            ids[j] = id;
            count++;
        }
    }

    /// @inheritdoc IERC7540Deposit
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public returns (uint256 requestId) {
        if (assets == 0) revert ZeroAmount();
        if (owner != _msgSender() && !_isOperator[owner][_msgSender()]) {
            revert InvalidOperator(owner, _msgSender());
        }
        _revertIfNotWhitelisted(
            address(FLEET),
            owner,
            controller,
            _msgSender()
        );

        requestId = _currentDepositEpoch;

        // CEI: mint receipt after the asset transfer-in (ERC-777-style pre-transfer hooks would
        // reenter before any state change, which is a valid state).
        ASSET.safeTransferFrom(owner, address(this), assets);
        _mint(controller, depositReceiptId(requestId), assets, "");

        emit DepositRequest(controller, owner, requestId, _msgSender(), assets);
    }

    /// @inheritdoc IERC7540Deposit
    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256) {
        EpochState state = _depositEpochState[requestId];
        if (state == EpochState.Open || state == EpochState.InSettlement) {
            return balanceOf(controller, depositReceiptId(requestId));
        }
        return 0;
    }

    /// @inheritdoc IERC7540Deposit
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256) {
        if (_depositEpochState[requestId] == EpochState.Settled) {
            return balanceOf(controller, depositReceiptId(requestId));
        }
        return 0;
    }

    /// @inheritdoc IERC7540Deposit
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) public returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        _requireControllerOrOperator(controller);
        _revertIfNotWhitelisted(
            address(FLEET),
            controller,
            receiver,
            _msgSender()
        );

        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            false
        );
        uint256 remaining = assets;
        for (uint256 i = 0; i < count && remaining > 0; i++) {
            uint256 bal = balanceOf(controller, ids[i]);
            uint256 take = bal < remaining ? bal : remaining;
            _burn(controller, ids[i], take);
            shares += _depositRate[ids[i] >> 1].quote(take);
            remaining -= take;
        }
        if (remaining > 0)
            revert ExceededMaxClaim(controller, assets, assets - remaining);

        IERC20(address(FLEET)).safeTransfer(receiver, shares);
        emit Deposit(controller, receiver, assets, shares);
    }

    /// @inheritdoc IERC7540Deposit
    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) public returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        _requireControllerOrOperator(controller);
        _revertIfNotWhitelisted(
            address(FLEET),
            controller,
            receiver,
            _msgSender()
        );

        uint256 max = maxMint(controller);
        if (shares > max) revert ExceededMaxClaim(controller, shares, max);

        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            false
        );
        uint256 remainingShares = shares;
        for (uint256 i = 0; i < count && remainingShares > 0; i++) {
            uint256 bal = balanceOf(controller, ids[i]);
            Price memory rate = _depositRate[ids[i] >> 1];
            uint256 epochShares = rate.quote(bal);
            if (epochShares <= remainingShares) {
                _burn(controller, ids[i], bal);
                assets += bal;
                remainingShares -= epochShares;
            } else {
                // assets needed for the remaining shares, rounded up against the claimer
                uint256 assetsPart = Math.mulDiv(
                    remainingShares,
                    rate.quoteAmount,
                    rate.baseAmount,
                    Math.Rounding.Ceil
                );
                if (assetsPart > bal) assetsPart = bal;
                _burn(controller, ids[i], assetsPart);
                assets += assetsPart;
                remainingShares = 0;
            }
        }

        IERC20(address(FLEET)).safeTransfer(receiver, shares);
        emit Deposit(controller, receiver, assets, shares);
    }

    /// @inheritdoc IAsyncFleetGateway
    function deposit(
        uint256 assets,
        address receiver
    ) public returns (uint256 shares) {
        return deposit(assets, receiver, _msgSender());
    }

    /// @inheritdoc IAsyncFleetGateway
    function mint(
        uint256 shares,
        address receiver
    ) public returns (uint256 assets) {
        return mint(shares, receiver, _msgSender());
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) public returns (uint256 requestId) {
        if (shares == 0) revert ZeroAmount();
        if (owner != _msgSender() && !_isOperator[owner][_msgSender()]) {
            revert InvalidOperator(owner, _msgSender());
        }
        _revertIfNotWhitelisted(
            address(FLEET),
            owner,
            controller,
            _msgSender()
        );

        requestId = _currentRedeemEpoch;

        // Pulls fleet shares from `owner`; requires owner→gateway ERC-20 approval on the fleet.
        // POC deviation from ERC-7540's optional allowance-on-sender path: only owner or an
        // approved ERC-7540 operator may initiate (documented in the report §6.4).
        IERC20(address(FLEET)).safeTransferFrom(owner, address(this), shares);
        _mint(controller, redeemReceiptId(requestId), shares, "");

        emit RedeemRequest(controller, owner, requestId, _msgSender(), shares);
    }

    /// @inheritdoc IERC7540Redeem
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256) {
        EpochState state = _redeemEpochState[requestId];
        if (state == EpochState.Open || state == EpochState.InSettlement) {
            return balanceOf(controller, redeemReceiptId(requestId));
        }
        return 0;
    }

    /// @inheritdoc IERC7540Redeem
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) public view returns (uint256) {
        if (_redeemEpochState[requestId] == EpochState.Settled) {
            return balanceOf(controller, redeemReceiptId(requestId));
        }
        return 0;
    }

    /// @inheritdoc IAsyncFleetGateway
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        _requireControllerOrOperator(controller);
        _revertIfNotWhitelisted(
            address(FLEET),
            controller,
            receiver,
            _msgSender()
        );

        uint256 max = maxWithdraw(controller);
        if (assets > max) revert ExceededMaxClaim(controller, assets, max);

        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            true
        );
        uint256 remainingAssets = assets;
        for (uint256 i = 0; i < count && remainingAssets > 0; i++) {
            uint256 bal = balanceOf(controller, ids[i]);
            Price memory rate = _redeemRate[ids[i] >> 1];
            uint256 epochAssets = rate.quote(bal);
            if (epochAssets <= remainingAssets) {
                _burn(controller, ids[i], bal);
                shares += bal;
                remainingAssets -= epochAssets;
            } else {
                // shares needed for the remaining assets, rounded up against the claimer so the
                // vault never over-pays assets relative to shares burned.
                uint256 sharesPart = Math.mulDiv(
                    remainingAssets,
                    rate.quoteAmount,
                    rate.baseAmount,
                    Math.Rounding.Ceil
                );
                if (sharesPart > bal) sharesPart = bal;
                _burn(controller, ids[i], sharesPart);
                shares += sharesPart;
                remainingAssets = 0;
            }
        }

        ASSET.safeTransfer(receiver, assets);
        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
    }

    /// @inheritdoc IAsyncFleetGateway
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) public returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        _requireControllerOrOperator(controller);
        _revertIfNotWhitelisted(
            address(FLEET),
            controller,
            receiver,
            _msgSender()
        );

        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            true
        );
        uint256 remaining = shares;
        for (uint256 i = 0; i < count && remaining > 0; i++) {
            uint256 bal = balanceOf(controller, ids[i]);
            uint256 take = bal < remaining ? bal : remaining;
            _burn(controller, ids[i], take);
            assets += _redeemRate[ids[i] >> 1].quote(take);
            remaining -= take;
        }
        if (remaining > 0)
            revert ExceededMaxClaim(controller, shares, shares - remaining);

        ASSET.safeTransfer(receiver, assets);
        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
    }

    /// @inheritdoc IAsyncFleetGateway
    function convertToShares(uint256 assets) public view returns (uint256) {
        return FLEET.convertToShares(assets);
    }

    /// @inheritdoc IAsyncFleetGateway
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return FLEET.convertToAssets(shares);
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxDeposit(
        address controller
    ) public view returns (uint256 total) {
        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            false
        );
        for (uint256 i = 0; i < count; i++) {
            total += balanceOf(controller, ids[i]);
        }
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxMint(address controller) public view returns (uint256 total) {
        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            false
        );
        for (uint256 i = 0; i < count; i++) {
            total += _depositRate[ids[i] >> 1].quote(
                balanceOf(controller, ids[i])
            );
        }
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxWithdraw(
        address controller
    ) public view returns (uint256 total) {
        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            true
        );
        for (uint256 i = 0; i < count; i++) {
            total += _redeemRate[ids[i] >> 1].quote(
                balanceOf(controller, ids[i])
            );
        }
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxRedeem(address controller) public view returns (uint256 total) {
        (uint256[] memory ids, uint256 count) = _sortedSettledReceipts(
            controller,
            true
        );
        for (uint256 i = 0; i < count; i++) {
            total += balanceOf(controller, ids[i]);
        }
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewDeposit(uint256) public pure returns (uint256) {
        revert AsyncFlowPreviewUnsupported();
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewMint(uint256) public pure returns (uint256) {
        revert AsyncFlowPreviewUnsupported();
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewWithdraw(uint256) public pure returns (uint256) {
        revert AsyncFlowPreviewUnsupported();
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewRedeem(uint256) public pure returns (uint256) {
        revert AsyncFlowPreviewUnsupported();
    }

    /// @inheritdoc IAsyncFleetGateway
    function closeDepositEpoch() public onlyKeeper {
        uint256 closing = _currentDepositEpoch;
        if (_depositEpochState[closing] != EpochState.Open) {
            revert InvalidEpochState(
                closing,
                _depositEpochState[closing],
                EpochState.Open
            );
        }
        _depositEpochState[closing] = EpochState.InSettlement;
        _currentDepositEpoch = closing + 1;
        _depositEpochState[closing + 1] = EpochState.Open;
        emit DepositEpochClosed(closing);
    }

    /// @inheritdoc IAsyncFleetGateway
    function settleDepositEpoch(uint256 epoch) public onlyKeeper {
        if (_depositEpochState[epoch] != EpochState.InSettlement) {
            revert InvalidEpochState(
                epoch,
                _depositEpochState[epoch],
                EpochState.InSettlement
            );
        }
        // Flip state before the external trade so any reentry observes the terminal state.
        _depositEpochState[epoch] = EpochState.Settled;

        uint256 frozenAssets = totalSupply(depositReceiptId(epoch));
        uint256 sharesOut = 0;
        if (frozenAssets > 0) {
            SafeERC20.forceApprove(ASSET, address(FLEET), frozenAssets);
            sharesOut = FLEET.deposit(frozenAssets, address(this));
            _depositRate[epoch] = toPrice(sharesOut, frozenAssets);
        }
        emit DepositEpochSettled(
            epoch,
            frozenAssets,
            sharesOut,
            _depositRate[epoch]
        );
    }

    /// @inheritdoc IAsyncFleetGateway
    function retryDepositEpoch(uint256 epoch) public onlyKeeper {
        if (epoch >= _currentDepositEpoch) {
            revert CannotRetryCurrentEpoch(epoch, _currentDepositEpoch);
        }
        if (_depositEpochState[epoch] != EpochState.Open) {
            revert InvalidEpochState(
                epoch,
                _depositEpochState[epoch],
                EpochState.Open
            );
        }
        _depositEpochState[epoch] = EpochState.InSettlement;
        emit DepositEpochRetried(epoch);
    }

    /// @inheritdoc IAsyncFleetGateway
    function closeRedeemEpoch() public onlyKeeper {
        uint256 closing = _currentRedeemEpoch;
        if (_redeemEpochState[closing] != EpochState.Open) {
            revert InvalidEpochState(
                closing,
                _redeemEpochState[closing],
                EpochState.Open
            );
        }
        _redeemEpochState[closing] = EpochState.InSettlement;
        _currentRedeemEpoch = closing + 1;
        _redeemEpochState[closing + 1] = EpochState.Open;
        emit RedeemEpochClosed(closing);
    }

    /// @inheritdoc IAsyncFleetGateway
    function settleRedeemEpoch(uint256 epoch) public onlyKeeper {
        if (_redeemEpochState[epoch] != EpochState.InSettlement) {
            revert InvalidEpochState(
                epoch,
                _redeemEpochState[epoch],
                EpochState.InSettlement
            );
        }
        // Flip state before the external trade so any reentry observes the terminal state.
        _redeemEpochState[epoch] = EpochState.Settled;

        uint256 frozenShares = totalSupply(redeemReceiptId(epoch));
        uint256 assetsOut = 0;
        if (frozenShares > 0) {
            assetsOut = FLEET.redeem(
                frozenShares,
                address(this),
                address(this)
            );
            _redeemRate[epoch] = toPrice(assetsOut, frozenShares);
        }
        emit RedeemEpochSettled(
            epoch,
            frozenShares,
            assetsOut,
            _redeemRate[epoch]
        );
    }

    /// @inheritdoc IAsyncFleetGateway
    function retryRedeemEpoch(uint256 epoch) public onlyKeeper {
        if (epoch >= _currentRedeemEpoch) {
            revert CannotRetryCurrentEpoch(epoch, _currentRedeemEpoch);
        }
        if (_redeemEpochState[epoch] != EpochState.Open) {
            revert InvalidEpochState(
                epoch,
                _redeemEpochState[epoch],
                EpochState.Open
            );
        }
        _redeemEpochState[epoch] = EpochState.InSettlement;
        emit RedeemEpochRetried(epoch);
    }

    /// @inheritdoc IAsyncFleetGateway
    function rollbackDepositEpoch(uint256 epoch) public onlyGovernor {
        if (_depositEpochState[epoch] != EpochState.InSettlement) {
            revert InvalidEpochState(
                epoch,
                _depositEpochState[epoch],
                EpochState.InSettlement
            );
        }
        _depositEpochState[epoch] = EpochState.Open;
        emit DepositEpochRolledBack(epoch);
    }

    /// @inheritdoc IAsyncFleetGateway
    function rollbackRedeemEpoch(uint256 epoch) public onlyGovernor {
        if (_redeemEpochState[epoch] != EpochState.InSettlement) {
            revert InvalidEpochState(
                epoch,
                _redeemEpochState[epoch],
                EpochState.InSettlement
            );
        }
        _redeemEpochState[epoch] = EpochState.Open;
        emit RedeemEpochRolledBack(epoch);
    }

    /// @dev Resolves the implicit target epoch for `cancelDeposit/RedeemRequest`: the highest
    ///      epoch, among the receipt ids of one flow that `owner` currently holds, or the live
    ///      current epoch if `owner` holds none. Cancel takes no explicit requestId (matching
    ///      ERC-7540's cancel-less convention), so the target must be derived from `owner`'s own
    ///      receipts rather than trusted blindly from the global epoch counter: the counter for
    ///      the live epoch is invariantly `Open` by construction, so checking it directly can
    ///      never catch a request whose own epoch has since closed — it would instead fail later
    ///      with an unrelated insufficient-balance burn. Picking the *highest* held epoch means a
    ///      fresh request in the current epoch is always the one canceled, ignoring any older,
    ///      already-closed request left unclaimed by the same owner — unless a governor has
    ///      rolled that older epoch back to `Open` (see cancelDepositRequest /
    ///      cancelRedeemRequest), in which case it becomes the highest *held-and-Open* epoch and
    ///      is the one canceled.
    function _mostRecentHeldEpoch(
        address owner,
        bool redeemFlow
    ) internal view returns (uint256 epoch) {
        epoch = redeemFlow ? _currentRedeemEpoch : _currentDepositEpoch;
        bool found;
        uint256 len = _receiptIdsOf[owner].length();
        for (uint256 i = 0; i < len; i++) {
            uint256 id = _receiptIdsOf[owner].at(i);
            if ((id & 1 == 1) != redeemFlow) continue;
            uint256 e = id >> 1;
            if (!found || e > epoch) {
                epoch = e;
                found = true;
            }
        }
    }

    /// @inheritdoc IAsyncFleetGateway
    /// @dev Cancels the caller's request in the newest epoch they still hold a receipt for,
    ///      which must be in the `Open` state. This is normally the current open epoch, but
    ///      also includes a past epoch a governor rolled back to `Open` via
    ///      `rollbackDepositEpoch` — rolling an epoch back is a deliberate recovery path that
    ///      lets holders exit, so such an epoch is cancelable. Epochs in `InSettlement` or
    ///      `Settled` are not cancelable.
    function cancelDepositRequest(
        uint256 assets,
        address receiver,
        address owner
    ) public {
        if (assets == 0) revert ZeroAmount();
        if (
            _msgSender() != owner &&
            !isApprovedForAll(owner, _msgSender()) &&
            !_isOperator[owner][_msgSender()]
        ) {
            revert CallerCannotCancel(_msgSender(), owner);
        }
        _revertIfNotWhitelisted(address(FLEET), owner, receiver, _msgSender());

        uint256 epoch = _mostRecentHeldEpoch(owner, false);
        if (_depositEpochState[epoch] != EpochState.Open) {
            revert InvalidEpochState(
                epoch,
                _depositEpochState[epoch],
                EpochState.Open
            );
        }

        _burn(owner, depositReceiptId(epoch), assets); // reverts on insufficient balance
        ASSET.safeTransfer(receiver, assets);
        emit DepositRequestCanceled(owner, receiver, epoch, assets);
    }

    /// @inheritdoc IAsyncFleetGateway
    /// @dev Cancels the caller's request in the newest epoch they still hold a receipt for,
    ///      which must be in the `Open` state. This is normally the current open epoch, but
    ///      also includes a past epoch a governor rolled back to `Open` via
    ///      `rollbackRedeemEpoch` — rolling an epoch back is a deliberate recovery path that
    ///      lets holders exit, so such an epoch is cancelable. Epochs in `InSettlement` or
    ///      `Settled` are not cancelable.
    function cancelRedeemRequest(
        uint256 shares,
        address receiver,
        address owner
    ) public {
        if (shares == 0) revert ZeroAmount();
        if (
            _msgSender() != owner &&
            !isApprovedForAll(owner, _msgSender()) &&
            !_isOperator[owner][_msgSender()]
        ) {
            revert CallerCannotCancel(_msgSender(), owner);
        }
        _revertIfNotWhitelisted(address(FLEET), owner, receiver, _msgSender());

        uint256 epoch = _mostRecentHeldEpoch(owner, true);
        if (_redeemEpochState[epoch] != EpochState.Open) {
            revert InvalidEpochState(
                epoch,
                _redeemEpochState[epoch],
                EpochState.Open
            );
        }

        _burn(owner, redeemReceiptId(epoch), shares);
        IERC20(address(FLEET)).safeTransfer(receiver, shares);
        emit RedeemRequestCanceled(owner, receiver, epoch, shares);
    }

    /// @inheritdoc IERC1155
    /// @dev Gates receipt transfers so only whitelisted parties on the fleet context can move them.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override(ERC1155, IERC1155) {
        _revertIfNotWhitelisted(address(FLEET), from, to, _msgSender());
        super.safeTransferFrom(from, to, id, value, data);
    }

    /// @inheritdoc IERC1155
    /// @dev Gates batch receipt transfers so only whitelisted parties on the fleet context can move them.
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override(ERC1155, IERC1155) {
        _revertIfNotWhitelisted(address(FLEET), from, to, _msgSender());
        super.safeBatchTransferFrom(from, to, ids, values, data);
    }
}
