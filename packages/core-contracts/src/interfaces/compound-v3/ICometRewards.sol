// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ICometRewards {
    struct RewardConfig {
        address token;
        uint64 rescaleFactor;
        bool shouldUpscale;
    }

    /// @notice Reward token address per Comet instance
    function rewardConfig(
        address comet
    ) external view returns (RewardConfig memory);

    /**
     * @notice Claim rewards of token type from a comet instance to owner address
     * @param comet The protocol instance
     * @param src The owner to claim for
     * @param shouldAccrue Whether or not to call accrue first
     */
    function claim(address comet, address src, bool shouldAccrue) external;

    /**
     * @notice Claim rewards of token type from a comet instance to a target address
     * @param comet The protocol instance
     * @param src The owner to claim for
     * @param to The address to receive the rewards
     * @param shouldAccrue Whether or not to call accrue first
     */
    function claimTo(
        address comet,
        address src,
        address to,
        bool shouldAccrue
    ) external;
}
