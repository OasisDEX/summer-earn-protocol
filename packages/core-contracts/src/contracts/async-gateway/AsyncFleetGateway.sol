// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
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

    // ---------- everything below is implemented in later tasks ----------

    /// @inheritdoc IERC7540Deposit
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external returns (uint256 shares) {
        revert("NotImplemented");
    }

    /// @inheritdoc IERC7540Deposit
    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) external returns (uint256 assets) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets) {
        revert("NotImplemented");
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external returns (uint256 requestId) {
        revert("NotImplemented");
    }

    /// @inheritdoc IERC7540Redeem
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 pendingShares) {
        revert("NotImplemented");
    }

    /// @inheritdoc IERC7540Redeem
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 claimableShares) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) external returns (uint256 shares) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) external returns (uint256 assets) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function convertToShares(uint256 assets) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function convertToAssets(uint256 shares) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxDeposit(address controller) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxMint(address controller) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxWithdraw(address controller) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function maxRedeem(address controller) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewDeposit(uint256 assets) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewMint(uint256 shares) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewWithdraw(uint256 assets) external view returns (uint256) {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function previewRedeem(uint256 shares) external view returns (uint256) {
        revert("NotImplemented");
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
    function settleDepositEpoch(uint256 epoch) external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function retryDepositEpoch(uint256 epoch) external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function closeRedeemEpoch() external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function settleRedeemEpoch(uint256 epoch) external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function retryRedeemEpoch(uint256 epoch) external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function rollbackDepositEpoch(uint256 epoch) external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function rollbackRedeemEpoch(uint256 epoch) external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function cancelDepositRequest(
        uint256 assets,
        address receiver,
        address owner
    ) external {
        revert("NotImplemented");
    }

    /// @inheritdoc IAsyncFleetGateway
    function cancelRedeemRequest(
        uint256 shares,
        address receiver,
        address owner
    ) external {
        revert("NotImplemented");
    }
    // safeTransferFrom, safeBatchTransferFrom (whitelist overrides — Task 11) are left to the
    // inherited ERC1155 implementation until that task adds the whitelist gate.
}
