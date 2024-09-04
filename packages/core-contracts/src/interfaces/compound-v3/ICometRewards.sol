// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface ICometRewards {
    /**
     * @notice Claim rewards of token type from a comet instance to owner address
     * @param comet The protocol instance
     * @param src The owner to claim for
     * @param shouldAccrue Whether or not to call accrue first
     */
    function claim(address comet, address src, bool shouldAccrue) external;
}
