// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IDSToken
 * @notice Minimal interface for a Securitize DS Protocol security token (`DSToken`).
 * @dev The token is a standard ERC20 whose transfers are gated by an off-chain-configured
 *      compliance service: both sender and receiver must be registered investor wallets and the
 *      transfer must satisfy lock-up / pause / jurisdiction rules. `preTransferCheck` lets an
 *      integrator (e.g. this Ark) verify a transfer will pass before attempting it.
 *
 *      Mint (`issueTokens`) and burn are issuer/transfer-agent only and are intentionally NOT
 *      exposed here — subscription and redemption are settled off-chain by Securitize.
 */
interface IDSToken is IERC20Metadata {
    /**
     * @notice Dry-runs the compliance checks for a prospective transfer.
     * @param _from The prospective sender
     * @param _to The prospective receiver
     * @param _value The transfer amount (in token units)
     * @return code 0 if the transfer would be permitted, otherwise a non-zero failure code
     * @return reason Human-readable reason matching the failure code
     */
    function preTransferCheck(
        address _from,
        address _to,
        uint256 _value
    ) external view returns (uint256 code, string memory reason);

    /**
     * @notice Returns the address of a DS Protocol service by its numeric service id.
     * @dev Service ids follow the DS Protocol `IDSServiceConsumer` convention — notably
     *      `4 = registry service` and `8 = compliance service`. Lets an integrator resolve the
     *      registry from the token itself rather than passing it (and risking a mismatch).
     * @param _serviceId The DS Protocol service id
     * @return The service contract address (zero if unset)
     */
    function getDSService(uint256 _serviceId) external view returns (address);
}
