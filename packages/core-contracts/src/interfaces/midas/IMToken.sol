// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title IMToken
 * @author RedDuck Software
 */
interface IMToken is IERC20 {
    /**
     * @notice mints mToken token `amount` to a given `to` address.
     * should be called only from permissioned actor
     * @param to addres to mint tokens to
     * @param amount amount to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice burns mToken token `amount` to a given `to` address.
     * should be called only from permissioned actor
     * @param from addres to burn tokens from
     * @param amount amount to burn
     */
    function burn(address from, uint256 amount) external;

    /**
     * @notice updates contract`s metadata.
     * should be called only from permissioned actor
     * @param key metadata map. key
     * @param data metadata map. value
     */
    function setMetadata(bytes32 key, bytes memory data) external;

    /**
     * @notice puts mToken token on pause.
     * should be called only from permissioned actor
     */
    function pause() external;

    /**
     * @notice puts mToken token on pause.
     * should be called only from permissioned actor
     */
    function unpause() external;

    /**
     * @notice returns the decimals of the mToken
     * @return the decimals of the mToken
     */
    function decimals() external view returns (uint8);
}
