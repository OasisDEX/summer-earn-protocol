// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IBridgeTokenFeeSupport
 * @notice Optional capability interface for adapters that support paying fees in a protocol token
 */
interface IBridgeTokenFeeSupport {
    /**
     * @notice Returns true if the adapter supports paying bridge/messaging fees in a protocol token
     */
    function supportsProtocolTokenFee() external view returns (bool);
}


