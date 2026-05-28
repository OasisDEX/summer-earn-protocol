// SPDX-License-Identifier: BUSL-1.1
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Multicall.sol)

pragma solidity ^0.8.20;

import {Address, Context} from "@openzeppelin/contracts/utils/Multicall.sol";
import {StorageSlot} from "@summerfi/dependencies/openzeppelin-next/StorageSlot.sol";
import {Whitelist} from "../utils/Whitelist/Whitelist.sol";

/**
 * @title ProtectedMulticallWhitelist
 *
 * @notice Fork of OpenZeppelin's `Multicall` that lets inheriting contracts gate functions on the
 *         "are we inside an active multicall by this caller?" predicate via `onlyMulticall`. The
 *         original caller is stashed in transient storage on `multicall` entry and cleared on exit.
 *
 * @dev Considerations carried over from OZ `Multicall`:
 *      - Any assumption about calldata validation performed by the sender may be violated if the
 *        sender is not careful about sending transactions invoking {multicall}; e.g. a relay that
 *        filters function selectors won't filter calls nested within `multicall`.
 *      - Since OZ 5.0.1 and 4.9.4, the implementation forwards the trailing `_contextSuffixLength`
 *        bytes of `msg.data` to subcalls when `msg.sender != _msgSender()`.
 *
 * @dev WARNING: this contract is NOT safe to use behind an ERC-2771 trusted forwarder. On `multicall`
 *      entry, `_setCaller(msg.sender)` stashes the forwarder address into transient storage, while
 *      `onlyMulticall` compares `_getCaller()` against `_msgSender()` (which unwraps to the end
 *      user). The two values will never match when invoked via a forwarder, so any `onlyMulticall`
 *      gated subcall will revert with `NotMulticall()`. Use direct calls only.
 *
 * @dev Whitelist behavior:
 *      - This contract inherits from `Whitelist` but does NOT gate `multicall` itself; the entry
 *        point is fully public.
 *      - Inheriting contracts are responsible for gating individual functions, both with their own
 *        whitelist context check and with `onlyMulticall`. `AdmiralsQuartersWhitelist` does both.
 */

abstract contract ProtectedMulticallWhitelist is Context, Whitelist {
    using StorageSlot for *;

    /// @notice Reverts when `multicall` is invoked while another `multicall` is already in progress
    ///         on this contract (i.e. the transient-storage caller slot is non-zero).
    error MulticallAlreadyInProgress();

    /// @notice Reverts when a function gated by `onlyMulticall` is invoked outside the scope of an
    ///         active `multicall` call by the same `_msgSender()`.
    error NotMulticall();

    /// @dev Transient-storage slot key holding the original caller while a `multicall` is in flight.
    bytes32 constant CALLER_KEY = keccak256("admirals-quarters-caller");

    /// @notice Ensures the wrapped function is reachable only from within an active `multicall`
    ///         initiated by the same `_msgSender()`. Reverts with `NotMulticall` otherwise.
    modifier onlyMulticall() {
        if (_getCaller() != _msgSender()) {
            revert NotMulticall();
        }
        _;
    }

    /**
     * @notice Executes a batch of function calls on this contract in a single transaction. Each
     *         entry in `data` is `delegatecall`ed against `address(this)`. The original caller is
     *         recorded in transient storage so `onlyMulticall`-gated functions can verify they are
     *         being invoked nested inside this call.
     * @dev Reverts with `MulticallAlreadyInProgress` if a `multicall` is already in flight on this
     *      contract (the transient-storage caller slot is non-zero) — direct nesting is rejected to
     *      keep the gate unambiguous. Forwards trailing `_contextSuffixLength` calldata bytes for
     *      ERC-2771 compatibility.
     * @param data Array of ABI-encoded calldata payloads to execute in order
     * @return results Array of raw return data per call, aligned with `data`
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function multicall(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results) {
        if (_getCaller() != address(0)) {
            revert MulticallAlreadyInProgress();
        }
        _setCaller(msg.sender);
        results = _multicall(data);
        _setCaller(address(0));
    }

    /// @dev Inner loop of `multicall`. `delegatecall`s each payload against `address(this)`,
    ///      appending the ERC-2771 context suffix when the call is going through a forwarder.
    /// @param data Array of ABI-encoded calldata payloads to execute in order
    /// @return results Array of raw return data per call, aligned with `data`
    function _multicall(
        bytes[] calldata data
    ) internal returns (bytes[] memory results) {
        bytes memory context = msg.sender == _msgSender()
            ? new bytes(0)
            : msg.data[msg.data.length - _contextSuffixLength():];

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(
                address(this),
                bytes.concat(data[i], context)
            );
        }
        return results;
    }

    /// @dev Stashes the active multicall caller in transient storage.
    function _setCaller(address caller) internal {
        CALLER_KEY.asAddress().tstore(caller);
    }

    /// @dev Reads the active multicall caller from transient storage. Returns `address(0)` when no
    ///      multicall is in flight.
    function _getCaller() internal view returns (address) {
        return CALLER_KEY.asAddress().tload();
    }
}
