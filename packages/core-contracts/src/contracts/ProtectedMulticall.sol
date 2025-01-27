// SPDX-License-Identifier: BUSL-1.1
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Multicall.sol)

pragma solidity ^0.8.20;

import {Address, Context} from "@openzeppelin/contracts/utils/Multicall.sol";
import {StorageSlot} from "@summerfi/dependencies/openzeppelin-next/StorageSlot.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * Consider any assumption about calldata validation performed by the sender may be violated if it's not especially
 * careful about sending transactions invoking {multicall}. For example, a relay address that filters function
 * selectors won't filter calls nested within a {multicall} operation.
 *
 * NOTE: Since 5.0.1 and 4.9.4, this contract identifies non-canonical contexts (i.e. `msg.sender` is not {_msgSender}).
 * If a non-canonical context is identified, the following self `delegatecall` appends the last bytes of `msg.data`
 * to the subcall. This makes it safe to use with {ERC2771Context}. Contexts that don't affect the resolution of
 * {_msgSender} are not propagated to subcalls.
 */

abstract contract ProtectedMulticall is Context {
    using StorageSlot for *;

    error MulticallAlreadyInProgress();
    error NotMulticall();

    bytes32 constant CALLER_KEY = keccak256("admirals-quarters-caller");

    modifier onlyMulticall() {
        if (_getCaller() != _msgSender()) {
            revert NotMulticall();
        }
        _;
    }
    /**
     * @dev Receives and executes a batch of function calls on this contract.
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

    function _setCaller(address caller) internal {
        CALLER_KEY.asAddress().tstore(caller);
    }

    function _getCaller() internal view returns (address) {
        return CALLER_KEY.asAddress().tload();
    }
}
